# 05 - Webhooks

> Day 5 of Week 7: Implement real-time updates from Google Calendar

## Overview

We'll implement:
- Google Calendar webhook setup
- Webhook receiver endpoint
- Real-time event sync
- Webhook renewal automation

---

## Step 1: Understand Google Calendar Webhooks

Google Calendar uses "push notifications" (webhooks) to notify your app of changes:

```
┌──────────────┐      ┌─────────────┐      ┌─────────────┐
│   Google     │      │  Your Edge  │      │  Database   │
│   Calendar   │─────▶│  Function   │─────▶│  + Client   │
└──────────────┘      └─────────────┘      └─────────────┘
       │                     │
       │  POST /webhook      │
       │  X-Goog-Channel-ID  │
       │  X-Goog-Resource-ID │
       └─────────────────────┘
```

## Step 2: Create Webhook Channels Table

```sql
create table webhook_channels (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users(id) on delete cascade not null,
  calendar_id uuid references calendars(id) on delete cascade not null,
  channel_id text unique not null,
  resource_id text not null,
  expiration timestamptz not null,
  created_at timestamptz default now()
);

create index idx_webhook_channels_user on webhook_channels(user_id);
create index idx_webhook_channels_expiration on webhook_channels(expiration);
```

## Step 3: Create Watch Function

Create `supabase/functions/watch-calendar/index.ts`:

```typescript
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { getValidAccessToken } from '../_shared/google-auth.ts';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { userId, calendarId, googleCalendarId } = await req.json();

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    );

    // Get access token
    const accessToken = await getValidAccessToken(userId);

    // Generate unique channel ID
    const channelId = crypto.randomUUID();

    // Webhook URL
    const webhookUrl = `${Deno.env.get('SUPABASE_URL')}/functions/v1/google-webhook`;

    // Set expiration (max 7 days for Google)
    const expiration = new Date(Date.now() + 6 * 24 * 60 * 60 * 1000); // 6 days

    // Create watch request
    const response = await fetch(
      `https://www.googleapis.com/calendar/v3/calendars/${encodeURIComponent(googleCalendarId)}/events/watch`,
      {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${accessToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          id: channelId,
          type: 'web_hook',
          address: webhookUrl,
          expiration: expiration.getTime(),
        }),
      }
    );

    if (!response.ok) {
      const error = await response.text();
      throw new Error(`Watch request failed: ${error}`);
    }

    const watchData = await response.json();

    // Store channel info
    await supabase.from('webhook_channels').upsert({
      user_id: userId,
      calendar_id: calendarId,
      channel_id: channelId,
      resource_id: watchData.resourceId,
      expiration: new Date(parseInt(watchData.expiration)).toISOString(),
    }, {
      onConflict: 'channel_id',
    });

    return new Response(
      JSON.stringify({ success: true, channelId, expiration: watchData.expiration }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  } catch (error) {
    console.error('Watch error:', error);
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  }
});
```

## Step 4: Create Webhook Receiver

Create `supabase/functions/google-webhook/index.ts`:

```typescript
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

serve(async (req) => {
  // Google sends a sync message first to verify the endpoint
  const channelId = req.headers.get('X-Goog-Channel-ID');
  const resourceId = req.headers.get('X-Goog-Resource-ID');
  const resourceState = req.headers.get('X-Goog-Resource-State');

  console.log('Webhook received:', { channelId, resourceState });

  // Respond immediately to Google
  if (resourceState === 'sync') {
    // Initial sync verification
    return new Response('OK', { status: 200 });
  }

  if (!channelId || !resourceId) {
    return new Response('Missing headers', { status: 400 });
  }

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  );

  try {
    // Find the channel to get user and calendar info
    const { data: channel, error } = await supabase
      .from('webhook_channels')
      .select(`
        user_id,
        calendar_id,
        calendars(google_calendar_id)
      `)
      .eq('channel_id', channelId)
      .eq('resource_id', resourceId)
      .single();

    if (error || !channel) {
      console.error('Channel not found:', channelId);
      return new Response('Channel not found', { status: 404 });
    }

    // Queue a sync for this calendar
    // We use a simple approach: just trigger a full sync
    // For high-volume apps, you'd want incremental sync
    await fetch(`${Deno.env.get('SUPABASE_URL')}/functions/v1/sync-calendars`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ userId: channel.user_id }),
    });

    return new Response('OK', { status: 200 });
  } catch (error) {
    console.error('Webhook processing error:', error);
    // Still return 200 to prevent Google from retrying
    return new Response('OK', { status: 200 });
  }
});
```

## Step 5: Stop Watching Function

Create `supabase/functions/stop-watch/index.ts`:

```typescript
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { getValidAccessToken } from '../_shared/google-auth.ts';

serve(async (req) => {
  const { userId, channelId, resourceId } = await req.json();

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  );

  try {
    // Get access token
    const accessToken = await getValidAccessToken(userId);

    // Stop the watch
    await fetch('https://www.googleapis.com/calendar/v3/channels/stop', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        id: channelId,
        resourceId: resourceId,
      }),
    });

    // Delete from database
    await supabase
      .from('webhook_channels')
      .delete()
      .eq('channel_id', channelId);

    return new Response(
      JSON.stringify({ success: true }),
      { headers: { 'Content-Type': 'application/json' } }
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    );
  }
});
```

## Step 6: Automatic Channel Renewal

Create `supabase/functions/renew-webhooks/index.ts`:

```typescript
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

serve(async (req) => {
  const authHeader = req.headers.get('Authorization');
  if (authHeader !== `Bearer ${Deno.env.get('CRON_SECRET')}`) {
    return new Response('Unauthorized', { status: 401 });
  }

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  );

  try {
    // Find channels expiring in next 24 hours
    const expiringAt = new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString();

    const { data: channels } = await supabase
      .from('webhook_channels')
      .select(`
        id,
        user_id,
        calendar_id,
        channel_id,
        resource_id,
        calendars(google_calendar_id)
      `)
      .lt('expiration', expiringAt);

    let renewed = 0;

    for (const channel of channels || []) {
      try {
        // Stop old watch
        await fetch(`${Deno.env.get('SUPABASE_URL')}/functions/v1/stop-watch`, {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            userId: channel.user_id,
            channelId: channel.channel_id,
            resourceId: channel.resource_id,
          }),
        });

        // Create new watch
        await fetch(`${Deno.env.get('SUPABASE_URL')}/functions/v1/watch-calendar`, {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            userId: channel.user_id,
            calendarId: channel.calendar_id,
            googleCalendarId: channel.calendars.google_calendar_id,
          }),
        });

        renewed++;
      } catch (error) {
        console.error(`Failed to renew channel ${channel.id}:`, error);
      }
    }

    return new Response(
      JSON.stringify({ success: true, renewed }),
      { headers: { 'Content-Type': 'application/json' } }
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    );
  }
});
```

## Step 7: Schedule Renewal Cron

```sql
-- Run daily to renew expiring webhooks
select cron.schedule(
  'renew-webhooks',
  '0 0 * * *', -- Daily at midnight UTC
  $$
  select
    net.http_post(
      url := 'https://YOUR_PROJECT.supabase.co/functions/v1/renew-webhooks',
      headers := jsonb_build_object(
        'Authorization', 'Bearer ' || current_setting('app.settings.cron_secret'),
        'Content-Type', 'application/json'
      ),
      body := '{}'::jsonb
    ) as request_id;
  $$
);
```

## Step 8: Initialize Watches on Calendar Connect

Update the Google callback to set up watches:

```typescript
// In google-callback function, after saving tokens:

// Set up webhook for each calendar
const { data: calendars } = await supabase
  .from('calendars')
  .select('id, google_calendar_id')
  .eq('user_id', stateData.user_id)
  .eq('sync_enabled', true);

for (const calendar of calendars || []) {
  await fetch(`${Deno.env.get('SUPABASE_URL')}/functions/v1/watch-calendar`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      userId: stateData.user_id,
      calendarId: calendar.id,
      googleCalendarId: calendar.google_calendar_id,
    }),
  });
}
```

## Step 9: Client Real-time Updates

Use Supabase real-time to push updates to the client:

```typescript
// In useEvents hook
useEffect(() => {
  if (!user) return;

  // Subscribe to event changes
  const channel = supabase
    .channel('events_changes')
    .on(
      'postgres_changes',
      {
        event: '*',
        schema: 'public',
        table: 'events',
        filter: `user_id=eq.${user.id}`,
      },
      (payload) => {
        console.log('Event changed:', payload);

        if (payload.eventType === 'INSERT') {
          setEvents((prev) => [...prev, payload.new as Event].sort(
            (a, b) => new Date(a.start_time).getTime() - new Date(b.start_time).getTime()
          ));
        } else if (payload.eventType === 'UPDATE') {
          setEvents((prev) =>
            prev.map((e) => (e.id === payload.new.id ? (payload.new as Event) : e))
          );
        } else if (payload.eventType === 'DELETE') {
          setEvents((prev) => prev.filter((e) => e.id !== payload.old.id));
        }
      }
    )
    .subscribe();

  return () => {
    supabase.removeChannel(channel);
  };
}, [user]);
```

---

## Webhook Flow Summary

```
1. User connects Google Calendar
         ↓
2. App creates watch for each calendar (watch-calendar)
         ↓
3. Google sends verification POST (google-webhook receives "sync")
         ↓
4. User creates/edits/deletes event in Google Calendar
         ↓
5. Google sends POST to google-webhook
         ↓
6. Webhook triggers sync-calendars for that user
         ↓
7. Database updates → Supabase Realtime → Client updates
         ↓
8. Daily cron renews expiring watches (renew-webhooks)
```

---

## Checkpoint

Before completing SyncCal, verify:

- [ ] Watches are created when calendar connects
- [ ] Webhook endpoint receives Google notifications
- [ ] Changes in Google Calendar appear in app
- [ ] Watches auto-renew before expiration
- [ ] Real-time updates work on client

---

## Common Issues

### "Push notifications not working"

- Verify webhook URL is HTTPS
- Check Google Cloud project has Calendar API enabled
- Ensure domain is verified in Search Console

### "Channel expired"

- Renewal cron not running
- Check cron job status in `cron.job_run_details`

### "Sync not triggering"

- Check webhook function logs
- Verify channel_id matches in database
- Test with manual webhook trigger

---

## Congratulations!

You've completed all three apps! You now have:

1. **DailyWin** - Habit tracking with subscriptions
2. **QuickNote** - Voice notes with AI
3. **SyncCal** - Calendar assistant with real-time sync

### What You've Learned

- Expo + Supabase full-stack development
- OAuth 2.0 implementation
- Edge Functions and serverless architecture
- Push notifications
- Background jobs with pg_cron
- Webhook integration
- Stripe and RevenueCat payments
- Real-time updates

### Next Steps

1. Launch all three apps
2. Gather user feedback
3. Iterate and improve
4. Build your next idea!

Return to the [main curriculum](../../README.md) for launch checklists and marketing tips.
