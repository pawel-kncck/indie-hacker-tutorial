-- ============================================
-- SUPABASE STARTER SCHEMA
-- Common patterns for indie hacker apps
-- ============================================

-- ============================================
-- EXTENSIONS
-- ============================================

-- UUID generation
create extension if not exists "uuid-ossp";

-- Full-text search
create extension if not exists "pg_trgm";

-- Scheduled jobs (requires Supabase Pro or self-hosted)
-- create extension if not exists "pg_cron";


-- ============================================
-- PROFILES (extends auth.users)
-- ============================================

create table profiles (
  id uuid references auth.users on delete cascade primary key,
  email text,
  full_name text,
  avatar_url text,
  -- Stripe customer ID (if using Stripe)
  stripe_customer_id text unique,
  -- App-specific fields
  onboarding_completed boolean default false,
  -- Timestamps
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- Enable RLS
alter table profiles enable row level security;

-- Users can view/edit their own profile
create policy "Users can view own profile"
  on profiles for select
  using (auth.uid() = id);

create policy "Users can update own profile"
  on profiles for update
  using (auth.uid() = id);

-- Automatically create profile on signup
create or replace function handle_new_user()
returns trigger as $$
begin
  insert into profiles (id, email, full_name, avatar_url)
  values (
    new.id,
    new.email,
    new.raw_user_meta_data->>'full_name',
    new.raw_user_meta_data->>'avatar_url'
  );
  return new;
end;
$$ language plpgsql security definer;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_user();


-- ============================================
-- SUBSCRIPTIONS (for RevenueCat/Stripe)
-- ============================================

create table subscriptions (
  id uuid default uuid_generate_v4() primary key,
  user_id uuid references auth.users on delete cascade unique not null,
  -- Subscription details
  status text not null check (status in ('trialing', 'active', 'canceled', 'incomplete', 'incomplete_expired', 'past_due', 'unpaid', 'paused')),
  plan text not null, -- 'free', 'pro', 'premium'
  -- Provider-specific IDs
  stripe_subscription_id text unique,
  stripe_price_id text,
  revenuecat_subscriber_id text,
  -- Billing period
  current_period_start timestamptz,
  current_period_end timestamptz,
  cancel_at_period_end boolean default false,
  -- Timestamps
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

alter table subscriptions enable row level security;

create policy "Users can view own subscription"
  on subscriptions for select
  using (auth.uid() = user_id);

-- Index for checking subscription status
create index idx_subscriptions_status on subscriptions(user_id, status);


-- ============================================
-- USAGE TRACKING
-- ============================================

-- Track feature usage for free tier limits
create table usage (
  id uuid default uuid_generate_v4() primary key,
  user_id uuid references auth.users on delete cascade not null,
  feature text not null, -- 'habits', 'notes', 'api_calls'
  period date not null, -- First day of month
  count integer default 0,
  created_at timestamptz default now(),

  unique(user_id, feature, period)
);

alter table usage enable row level security;

create policy "Users can view own usage"
  on usage for select
  using (auth.uid() = user_id);

-- Function to increment usage
create or replace function increment_usage(
  p_user_id uuid,
  p_feature text,
  p_amount integer default 1
)
returns void as $$
begin
  insert into usage (user_id, feature, period, count)
  values (p_user_id, p_feature, date_trunc('month', now())::date, p_amount)
  on conflict (user_id, feature, period)
  do update set count = usage.count + p_amount;
end;
$$ language plpgsql security definer;


-- ============================================
-- PUSH NOTIFICATIONS
-- ============================================

create table push_tokens (
  id uuid default uuid_generate_v4() primary key,
  user_id uuid references auth.users on delete cascade not null,
  token text not null,
  platform text not null check (platform in ('ios', 'android', 'web')),
  created_at timestamptz default now(),

  unique(user_id, token)
);

alter table push_tokens enable row level security;

create policy "Users can manage own push tokens"
  on push_tokens for all
  using (auth.uid() = user_id);


-- ============================================
-- NOTIFICATION PREFERENCES
-- ============================================

create table notification_preferences (
  user_id uuid references auth.users on delete cascade primary key,
  email_marketing boolean default true,
  email_updates boolean default true,
  push_enabled boolean default true,
  push_reminders boolean default true,
  quiet_hours_start time,
  quiet_hours_end time,
  timezone text default 'UTC',
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

alter table notification_preferences enable row level security;

create policy "Users can manage own notification prefs"
  on notification_preferences for all
  using (auth.uid() = user_id);


-- ============================================
-- FEEDBACK / SUPPORT
-- ============================================

create table feedback (
  id uuid default uuid_generate_v4() primary key,
  user_id uuid references auth.users on delete set null,
  type text not null check (type in ('bug', 'feature', 'feedback', 'question')),
  message text not null,
  status text default 'open' check (status in ('open', 'in_progress', 'resolved', 'closed')),
  app_version text,
  device_info jsonb,
  created_at timestamptz default now(),
  resolved_at timestamptz
);

alter table feedback enable row level security;

-- Users can submit and view their own feedback
create policy "Users can submit feedback"
  on feedback for insert
  with check (auth.uid() = user_id or user_id is null);

create policy "Users can view own feedback"
  on feedback for select
  using (auth.uid() = user_id);


-- ============================================
-- AUDIT LOG
-- ============================================

create table audit_log (
  id uuid default uuid_generate_v4() primary key,
  user_id uuid references auth.users on delete set null,
  action text not null,
  table_name text,
  record_id uuid,
  old_data jsonb,
  new_data jsonb,
  ip_address inet,
  user_agent text,
  created_at timestamptz default now()
);

-- Index for querying by user
create index idx_audit_log_user on audit_log(user_id, created_at desc);


-- ============================================
-- HELPER FUNCTIONS
-- ============================================

-- Auto-update updated_at timestamp
create or replace function update_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

-- Apply to all tables with updated_at
create trigger profiles_updated_at
  before update on profiles
  for each row execute function update_updated_at();

create trigger subscriptions_updated_at
  before update on subscriptions
  for each row execute function update_updated_at();

create trigger notification_preferences_updated_at
  before update on notification_preferences
  for each row execute function update_updated_at();


-- ============================================
-- CHECK SUBSCRIPTION STATUS
-- ============================================

-- Function to check if user has active subscription
create or replace function is_subscribed(p_user_id uuid)
returns boolean as $$
declare
  v_status text;
begin
  select status into v_status
  from subscriptions
  where user_id = p_user_id;

  return v_status in ('active', 'trialing');
end;
$$ language plpgsql security definer;

-- Function to get user's plan
create or replace function get_user_plan(p_user_id uuid)
returns text as $$
declare
  v_plan text;
begin
  select plan into v_plan
  from subscriptions
  where user_id = p_user_id
    and status in ('active', 'trialing');

  return coalesce(v_plan, 'free');
end;
$$ language plpgsql security definer;


-- ============================================
-- SAMPLE APP TABLE (Habits example)
-- ============================================

-- Uncomment and customize for your app:

/*
create table habits (
  id uuid default uuid_generate_v4() primary key,
  user_id uuid references auth.users on delete cascade not null,
  name text not null,
  color text default '#3B82F6',
  icon text default 'checkmark-circle',
  archived_at timestamptz,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table completions (
  id uuid default uuid_generate_v4() primary key,
  habit_id uuid references habits on delete cascade not null,
  completed_date date not null,
  created_at timestamptz default now(),

  unique(habit_id, completed_date)
);

-- Indexes
create index idx_habits_user on habits(user_id);
create index idx_completions_habit on completions(habit_id);
create index idx_completions_date on completions(completed_date);

-- RLS
alter table habits enable row level security;
alter table completions enable row level security;

create policy "Users manage own habits"
  on habits for all
  using (auth.uid() = user_id);

create policy "Users manage completions for own habits"
  on completions for all
  using (
    habit_id in (
      select id from habits where user_id = auth.uid()
    )
  );
*/


-- ============================================
-- STORAGE BUCKETS
-- ============================================

-- Create a bucket for user uploads
insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict do nothing;

-- Policy: Users can upload their own avatar
create policy "Users can upload own avatar"
on storage.objects for insert
with check (
  bucket_id = 'avatars' and
  auth.uid()::text = (storage.foldername(name))[1]
);

-- Policy: Anyone can view avatars (public bucket)
create policy "Public avatar access"
on storage.objects for select
using (bucket_id = 'avatars');

-- Policy: Users can update/delete their own avatar
create policy "Users can update own avatar"
on storage.objects for update
using (
  bucket_id = 'avatars' and
  auth.uid()::text = (storage.foldername(name))[1]
);

create policy "Users can delete own avatar"
on storage.objects for delete
using (
  bucket_id = 'avatars' and
  auth.uid()::text = (storage.foldername(name))[1]
);


-- ============================================
-- NOTES
-- ============================================

/*
USAGE:

1. Copy this file to your Supabase SQL Editor
2. Uncomment sections you need
3. Customize table names and columns
4. Run the SQL

CONVENTIONS:

- All tables have RLS enabled
- Use uuid for primary keys
- Use timestamptz for timestamps
- Index foreign keys and frequently queried columns
- Use check constraints for enums
- Use unique constraints where appropriate

NEXT STEPS:

1. Add your app-specific tables
2. Create Edge Functions for business logic
3. Set up cron jobs for background tasks
4. Configure webhooks for external services
*/
