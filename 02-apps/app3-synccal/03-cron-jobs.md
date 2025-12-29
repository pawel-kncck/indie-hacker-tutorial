# 03 - Cron Jobs

> Day 1 of Week 7: Set up automated background tasks

## Overview

We'll implement:
- Supabase pg_cron for scheduled jobs
- Automatic calendar sync
- Cleanup tasks
- Rate-limited batch processing

---

## Step 1: Enable pg_cron

In Supabase Dashboard, go to **Database → Extensions**:

1. Search for `pg_cron`
2. Enable the extension

Or via SQL:

```sql
create extension if not exists pg_cron;
```

## Step 2: Create Sync All Users Function

Create a function to sync all connected users:

```sql
-- Function to get users needing sync
create or replace function get_users_for_sync()
returns table(user_id uuid) as $$
begin
  return query
  select distinct ot.user_id
  from oauth_tokens ot
  join calendars c on c.user_id = ot.user_id
  where ot.provider = 'google'
    and c.sync_enabled = true
    and (
      c.last_synced_at is null
      or c.last_synced_at < now() - interval '15 minutes'
    );
end;
$$ language plpgsql security definer;
```

## Step 3: Create Batch Sync Edge Function

Create `supabase/functions/batch-sync/index.ts`:

```typescript
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

serve(async (req) => {
  // Verify cron secret
  const authHeader = req.headers.get('Authorization');
  if (authHeader !== `Bearer ${Deno.env.get('CRON_SECRET')}`) {
    return new Response('Unauthorized', { status: 401 });
  }

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  );

  try {
    // Get users needing sync
    const { data: users, error } = await supabase
      .rpc('get_users_for_sync');

    if (error) throw error;

    console.log(`Syncing ${users?.length || 0} users`);

    // Process users with rate limiting
    const batchSize = 10;
    const delayMs = 1000;

    for (let i = 0; i < (users?.length || 0); i += batchSize) {
      const batch = users!.slice(i, i + batchSize);

      await Promise.all(
        batch.map(async ({ user_id }) => {
          try {
            await fetch(
              `${Deno.env.get('SUPABASE_URL')}/functions/v1/sync-calendars`,
              {
                method: 'POST',
                headers: {
                  Authorization: `Bearer ${Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')}`,
                  'Content-Type': 'application/json',
                },
                body: JSON.stringify({ userId: user_id }),
              }
            );
          } catch (err) {
            console.error(`Failed to sync user ${user_id}:`, err);
          }
        })
      );

      // Rate limit between batches
      if (i + batchSize < (users?.length || 0)) {
        await new Promise((r) => setTimeout(r, delayMs));
      }
    }

    return new Response(
      JSON.stringify({ success: true, synced: users?.length || 0 }),
      { headers: { 'Content-Type': 'application/json' } }
    );
  } catch (error) {
    console.error('Batch sync error:', error);
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    );
  }
});
```

## Step 4: Schedule Cron Jobs

```sql
-- Enable pg_net for HTTP calls
create extension if not exists pg_net;

-- Schedule calendar sync every 15 minutes
select cron.schedule(
  'sync-calendars',
  '*/15 * * * *', -- Every 15 minutes
  $$
  select
    net.http_post(
      url := 'https://YOUR_PROJECT.supabase.co/functions/v1/batch-sync',
      headers := jsonb_build_object(
        'Authorization', 'Bearer ' || current_setting('app.settings.cron_secret'),
        'Content-Type', 'application/json'
      ),
      body := '{}'::jsonb
    ) as request_id;
  $$
);

-- Schedule cleanup of old data daily at 3 AM
select cron.schedule(
  'cleanup-old-data',
  '0 3 * * *', -- Daily at 3 AM UTC
  $$
  -- Delete events older than 90 days
  delete from events where start_time < now() - interval '90 days';

  -- Delete expired oauth states
  delete from oauth_states where expires_at < now();

  -- Delete old api_requests
  delete from api_requests where created_at < now() - interval '7 days';
  $$
);

-- Schedule daily agenda notifications at 7 AM
select cron.schedule(
  'morning-notifications',
  '0 7 * * *', -- Daily at 7 AM UTC
  $$
  select
    net.http_post(
      url := 'https://YOUR_PROJECT.supabase.co/functions/v1/send-daily-agenda',
      headers := jsonb_build_object(
        'Authorization', 'Bearer ' || current_setting('app.settings.cron_secret'),
        'Content-Type', 'application/json'
      ),
      body := '{}'::jsonb
    ) as request_id;
  $$
);
```

## Step 5: Set Cron Secret

```bash
# Generate a secure secret
openssl rand -base64 32

# Set it in Supabase secrets
supabase secrets set CRON_SECRET=your_generated_secret

# Also set in database settings
-- In SQL editor:
alter database postgres set app.settings.cron_secret = 'your_generated_secret';
```

## Step 6: View Scheduled Jobs

```sql
-- List all scheduled jobs
select * from cron.job;

-- View job run history
select * from cron.job_run_details
order by start_time desc
limit 20;

-- Check for failed jobs
select * from cron.job_run_details
where status = 'failed'
order by start_time desc;
```

## Step 7: Manage Cron Jobs

```sql
-- Disable a job temporarily
update cron.job set active = false where jobname = 'sync-calendars';

-- Re-enable
update cron.job set active = true where jobname = 'sync-calendars';

-- Delete a job
select cron.unschedule('job-name');

-- Update schedule
select cron.schedule(
  'sync-calendars',
  '*/5 * * * *', -- Change to every 5 minutes
  $$ ... $$
);
```

## Step 8: Sync Status Tracking

Create a table to track sync status:

```sql
create table sync_jobs (
  id uuid default gen_random_uuid() primary key,
  job_type text not null,
  status text default 'pending',
  users_processed integer default 0,
  errors jsonb,
  started_at timestamptz,
  completed_at timestamptz,
  created_at timestamptz default now()
);

-- Index for querying recent jobs
create index idx_sync_jobs_created on sync_jobs(created_at desc);
```

Update batch-sync function to log jobs:

```typescript
// At the start
const { data: job } = await supabase
  .from('sync_jobs')
  .insert({
    job_type: 'calendar_sync',
    status: 'running',
    started_at: new Date().toISOString(),
  })
  .select()
  .single();

// At the end
await supabase
  .from('sync_jobs')
  .update({
    status: 'completed',
    users_processed: users?.length || 0,
    completed_at: new Date().toISOString(),
  })
  .eq('id', job.id);
```

## Step 9: Pro User Priority Sync

Give Pro users more frequent sync:

```sql
create or replace function get_users_for_sync()
returns table(user_id uuid, is_pro boolean) as $$
begin
  return query
  select
    ot.user_id,
    (s.status = 'active') as is_pro
  from oauth_tokens ot
  join calendars c on c.user_id = ot.user_id
  left join subscriptions s on s.user_id = ot.user_id
  where ot.provider = 'google'
    and c.sync_enabled = true
    and (
      -- Pro users: sync if older than 5 minutes
      (s.status = 'active' and (c.last_synced_at is null or c.last_synced_at < now() - interval '5 minutes'))
      or
      -- Free users: sync if older than 15 minutes
      (s.status is null or s.status != 'active')
        and (c.last_synced_at is null or c.last_synced_at < now() - interval '15 minutes')
    );
end;
$$ language plpgsql security definer;
```

---

## Checkpoint

Before moving on, verify:

- [ ] pg_cron extension is enabled
- [ ] Batch sync function deploys
- [ ] Cron jobs are scheduled
- [ ] Jobs run on schedule
- [ ] Sync status is tracked
- [ ] Old data is cleaned up

---

## Monitoring

### View Recent Job Runs

```sql
select
  j.jobname,
  jrd.status,
  jrd.start_time,
  jrd.end_time,
  jrd.return_message
from cron.job_run_details jrd
join cron.job j on j.jobid = jrd.jobid
order by jrd.start_time desc
limit 10;
```

### Alert on Failures

Create a function to notify on failures:

```sql
create or replace function notify_cron_failure()
returns trigger as $$
begin
  if new.status = 'failed' then
    -- Log error or send notification
    insert into error_logs (type, message, details)
    values ('cron_failure', new.return_message, row_to_json(new));
  end if;
  return new;
end;
$$ language plpgsql;

create trigger cron_failure_trigger
after insert on cron.job_run_details
for each row execute function notify_cron_failure();
```

---

## Common Issues

### "pg_cron extension not available"

- Only available on paid Supabase plans
- Alternative: Use external cron service (GitHub Actions, Vercel Cron)

### Jobs not running

- Check job is active: `select active from cron.job`
- Verify pg_net is enabled
- Check for errors in `cron.job_run_details`

### Rate limiting issues

- Reduce batch size
- Increase delay between batches
- Implement exponential backoff

---

## Next Steps

Continue to [04-push-notifications.md](./04-push-notifications.md) to implement push notifications.
