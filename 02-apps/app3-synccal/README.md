# App 3: SyncCal - AI Calendar Assistant

Your most advanced app. Introduces OAuth, third-party APIs, background jobs, and push notifications.

## Overview

| Attribute | Value |
|-----------|-------|
| **Timeline** | Weeks 6-8 |
| **Complexity** | Advanced |
| **Revenue Model** | Freemium (1 calendar free, unlimited = $5.99/mo) |
| **Platforms** | Web, iOS, Android |

## The Product

SyncCal connects to your Google Calendar and provides AI-powered scheduling assistance.

**Core Features:**
- Connect Google Calendar via OAuth
- View and create events
- AI scheduling suggestions
- Daily agenda push notifications
- Smart conflict detection

**Why This App:**
- OAuth is essential for many apps
- Calendar API is well-documented
- Clear upgrade path (more calendars)
- Daily engagement through notifications

---

## Tech Stack Additions

| Component | Technology | Why |
|-----------|------------|-----|
| OAuth | Google OAuth 2.0 | Industry standard |
| Calendar | Google Calendar API | Most popular calendar |
| Cron Jobs | Supabase pg_cron | Scheduled tasks |
| Push Notifications | Expo Push | Cross-platform notifications |
| Background Sync | Edge Functions + Cron | Keep data fresh |

---

## Database Schema

```sql
-- Connected calendars
create table calendars (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users(id) on delete cascade not null,
  google_calendar_id text not null,
  name text not null,
  color text,
  is_primary boolean default false,
  sync_enabled boolean default true,
  last_synced_at timestamptz,
  created_at timestamptz default now(),

  unique(user_id, google_calendar_id)
);

-- Cached events
create table events (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users(id) on delete cascade not null,
  calendar_id uuid references calendars(id) on delete cascade not null,
  google_event_id text not null,
  title text not null,
  description text,
  start_time timestamptz not null,
  end_time timestamptz not null,
  location text,
  is_all_day boolean default false,
  status text default 'confirmed',
  created_at timestamptz default now(),
  updated_at timestamptz default now(),

  unique(calendar_id, google_event_id)
);

-- OAuth tokens (encrypted using pgsodium)
-- IMPORTANT: Enable pgsodium extension first for token encryption
-- This protects tokens at rest in the database

-- Enable pgsodium extension
create extension if not exists pgsodium;

-- Create encryption key for OAuth tokens
select pgsodium.create_key(
  name := 'oauth_tokens_key',
  key_type := 'aead-det'
);

create table oauth_tokens (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users(id) on delete cascade unique,
  provider text not null default 'google',
  -- Tokens are encrypted using pgsodium transparent column encryption
  access_token bytea not null,
  refresh_token bytea not null,
  expires_at timestamptz not null,
  scope text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- Create security label for transparent column encryption
security label for pgsodium on column oauth_tokens.access_token is
  'ENCRYPT WITH KEY ID (select id from pgsodium.valid_key where name = ''oauth_tokens_key'') SECURITY INVOKER';

security label for pgsodium on column oauth_tokens.refresh_token is
  'ENCRYPT WITH KEY ID (select id from pgsodium.valid_key where name = ''oauth_tokens_key'') SECURITY INVOKER';

-- Create view for decrypted access (only accessible to authenticated users via RLS)
create view oauth_tokens_decrypted as
  select
    id,
    user_id,
    provider,
    convert_from(
      pgsodium.crypto_aead_det_decrypt(
        access_token,
        '',
        (select id from pgsodium.valid_key where name = 'oauth_tokens_key')
      ),
      'utf8'
    ) as access_token,
    convert_from(
      pgsodium.crypto_aead_det_decrypt(
        refresh_token,
        '',
        (select id from pgsodium.valid_key where name = 'oauth_tokens_key')
      ),
      'utf8'
    ) as refresh_token,
    expires_at,
    scope,
    created_at,
    updated_at
  from oauth_tokens;

-- Push notification tokens
create table push_tokens (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users(id) on delete cascade not null,
  token text not null,
  platform text not null, -- 'ios', 'android', 'web'
  created_at timestamptz default now(),

  unique(user_id, token)
);

-- Notification preferences
create table notification_preferences (
  user_id uuid references auth.users(id) on delete cascade primary key,
  daily_agenda_enabled boolean default true,
  daily_agenda_time time default '07:00',
  event_reminders_enabled boolean default true,
  reminder_minutes integer default 15,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- Indexes
create index idx_calendars_user on calendars(user_id);
create index idx_events_calendar on events(calendar_id);
create index idx_events_time on events(start_time, end_time);
create index idx_events_user_time on events(user_id, start_time);

-- RLS
alter table calendars enable row level security;
alter table events enable row level security;
alter table oauth_tokens enable row level security;
alter table push_tokens enable row level security;
alter table notification_preferences enable row level security;

create policy "Users manage own calendars"
  on calendars for all using (auth.uid() = user_id);

create policy "Users manage own events"
  on events for all using (auth.uid() = user_id);

create policy "Users manage own tokens"
  on oauth_tokens for all using (auth.uid() = user_id);

create policy "Users manage own push tokens"
  on push_tokens for all using (auth.uid() = user_id);

create policy "Users manage own notification prefs"
  on notification_preferences for all using (auth.uid() = user_id);
```

---

## Screen Map

```
(auth)
├── login.tsx
├── signup.tsx
└── forgot-password.tsx

(app)
├── (tabs)
│   ├── index.tsx          # Today's agenda
│   ├── calendar.tsx       # Month/week view
│   └── settings.tsx       # Calendars, notifications, account
├── event/
│   ├── new.tsx            # Create event
│   └── [id].tsx           # Event details
├── connect-google.tsx     # OAuth flow
└── paywall.tsx
```

---

## Week-by-Week Guide

### Week 6: OAuth + Calendar Connection

| Day | Focus | Deliverable |
|-----|-------|-------------|
| 1 | Project setup | Clone patterns from App 1 & 2 |
| 2 | Google OAuth setup | Configure OAuth consent screen |
| 3 | OAuth flow | Implement connect/disconnect |
| 4 | Calendar list | Fetch and display user's calendars |
| 5 | Event sync | Pull events from Google Calendar |

**Milestone:** Can connect Google account and see events

→ [01-oauth-google.md](./01-oauth-google.md)
→ [02-calendar-api.md](./02-calendar-api.md)

### Week 7: Automation + Notifications

| Day | Focus | Deliverable |
|-----|-------|-------------|
| 1 | Cron jobs | Set up pg_cron for background sync |
| 2 | Push setup | Configure Expo Push Notifications |
| 3 | Daily agenda | Morning notification with today's events |
| 4 | Event reminders | Notifications before events |
| 5 | Webhook setup | Real-time updates from Google |

**Milestone:** Automated sync and notifications working

→ [03-cron-jobs.md](./03-cron-jobs.md)
→ [04-push-notifications.md](./04-push-notifications.md)
→ [05-webhooks.md](./05-webhooks.md)

### Week 8: Polish + Launch

| Day | Focus | Deliverable |
|-----|-------|-------------|
| 1 | AI features | Smart scheduling suggestions |
| 2 | UI polish | Animations, loading states |
| 3 | Subscription | Limit calendars for free tier |
| 4 | Submit | Production builds |
| 5 | Launch | Third app live! |

**Milestone:** All three apps published!

---

## OAuth Flow

```
┌─────────┐     ┌─────────────┐     ┌────────────┐
│  User   │────▶│    App      │────▶│   Google   │
└─────────┘     └─────────────┘     └────────────┘
     │                │                    │
     │  1. Click      │                    │
     │  "Connect"     │                    │
     │                │                    │
     │                │  2. Redirect to    │
     │                │  Google OAuth      │
     │                │───────────────────▶│
     │                │                    │
     │  3. User       │                    │
     │  approves      │                    │
     │                │                    │
     │                │  4. Callback with  │
     │                │  auth code         │
     │                │◀───────────────────│
     │                │                    │
     │                │  5. Exchange code  │
     │                │  for tokens        │
     │                │───────────────────▶│
     │                │                    │
     │                │  6. Access +       │
     │                │  Refresh tokens    │
     │                │◀───────────────────│
     │                │                    │
     │  7. Connected! │                    │
     │◀───────────────│                    │
```

---

## Revenue Model

### Subscription Tiers

| Tier | Price | Limits |
|------|-------|--------|
| Free | $0 | 1 calendar |
| Pro | $5.99/mo or $39.99/yr | Unlimited calendars, priority sync |

### Feature Comparison

| Feature | Free | Pro |
|---------|------|-----|
| Calendars | 1 | Unlimited |
| Sync frequency | Every 15 min | Every 5 min |
| AI suggestions | 3/day | Unlimited |
| Event creation | ✓ | ✓ |
| Push notifications | ✓ | ✓ |
| Priority support | - | ✓ |

---

## File Structure

```
synccal/
├── app/
│   ├── _layout.tsx
│   ├── (auth)/
│   ├── (app)/
│   │   ├── _layout.tsx
│   │   ├── (tabs)/
│   │   │   ├── index.tsx
│   │   │   ├── calendar.tsx
│   │   │   └── settings.tsx
│   │   ├── event/
│   │   │   ├── new.tsx
│   │   │   └── [id].tsx
│   │   ├── connect-google.tsx
│   │   └── paywall.tsx
├── components/
│   ├── AgendaList.tsx
│   ├── CalendarView.tsx
│   ├── EventCard.tsx
│   └── CalendarPicker.tsx
├── contexts/
│   ├── AuthContext.tsx
│   ├── CalendarContext.tsx
│   └── SubscriptionContext.tsx
├── hooks/
│   ├── useCalendars.ts
│   ├── useEvents.ts
│   └── useNotifications.ts
├── lib/
│   ├── supabase.ts
│   ├── google.ts
│   └── notifications.ts
├── supabase/
│   └── functions/
│       ├── google-callback/
│       ├── sync-calendars/
│       ├── google-webhook/
│       └── send-notifications/
└── types/
```

---

## API Rate Limits

| API | Limit | Strategy |
|-----|-------|----------|
| Google Calendar | 1M queries/day | Cache aggressively |
| Expo Push | 600/min | Batch notifications |
| OpenAI | Varies by tier | Queue requests |

---

## Key Learnings

After completing SyncCal, you'll understand:

1. **OAuth 2.0** - Full implementation with refresh tokens
2. **Third-party APIs** - Working with external services
3. **Background Jobs** - Cron-based scheduling
4. **Push Notifications** - Cross-platform implementation
5. **Webhooks** - Real-time event handling
6. **Data Sync** - Keeping local and remote in sync

---

## Guides

1. [Google OAuth](./01-oauth-google.md)
2. [Calendar API](./02-calendar-api.md)
3. [Cron Jobs](./03-cron-jobs.md)
4. [Push Notifications](./04-push-notifications.md)
5. [Webhooks](./05-webhooks.md)

Start with [01-oauth-google.md](./01-oauth-google.md).
