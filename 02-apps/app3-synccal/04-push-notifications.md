# 04 - Push Notifications

> Day 2-4 of Week 7: Implement cross-platform push notifications

## Overview

We'll implement:
- Expo push notification setup
- Token registration
- Daily agenda notifications
- Event reminders
- Notification preferences

---

## Step 1: Configure Expo Push

Update `app.json`:

```json
{
  "expo": {
    "plugins": [
      [
        "expo-notifications",
        {
          "icon": "./assets/notification-icon.png",
          "color": "#3B82F6",
          "sounds": ["./assets/notification-sound.wav"]
        }
      ]
    ],
    "android": {
      "googleServicesFile": "./google-services.json"
    },
    "ios": {
      "googleServicesFile": "./GoogleService-Info.plist"
    }
  }
}
```

## Step 2: Install Dependencies

```bash
npx expo install expo-notifications expo-device expo-constants
```

## Step 3: Create Notification Service

Create `lib/notifications.ts`:

```typescript
import { Platform } from 'react-native';
import * as Notifications from 'expo-notifications';
import * as Device from 'expo-device';
import Constants from 'expo-constants';
import { supabase } from './supabase';

// Configure notification behavior
Notifications.setNotificationHandler({
  handleNotification: async () => ({
    shouldShowAlert: true,
    shouldPlaySound: true,
    shouldSetBadge: true,
  }),
});

export async function registerForPushNotifications(): Promise<string | null> {
  if (!Device.isDevice) {
    console.log('Push notifications require a physical device');
    return null;
  }

  // Check permissions
  const { status: existingStatus } = await Notifications.getPermissionsAsync();
  let finalStatus = existingStatus;

  if (existingStatus !== 'granted') {
    const { status } = await Notifications.requestPermissionsAsync();
    finalStatus = status;
  }

  if (finalStatus !== 'granted') {
    console.log('Push notification permission denied');
    return null;
  }

  // Get Expo push token
  const projectId = Constants.expoConfig?.extra?.eas?.projectId;
  const token = await Notifications.getExpoPushTokenAsync({ projectId });

  // Configure Android channel
  if (Platform.OS === 'android') {
    await Notifications.setNotificationChannelAsync('default', {
      name: 'Default',
      importance: Notifications.AndroidImportance.MAX,
      vibrationPattern: [0, 250, 250, 250],
    });

    await Notifications.setNotificationChannelAsync('reminders', {
      name: 'Event Reminders',
      importance: Notifications.AndroidImportance.HIGH,
      sound: 'notification-sound.wav',
    });
  }

  return token.data;
}

export async function savePushToken(token: string): Promise<void> {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return;

  await supabase.from('push_tokens').upsert({
    user_id: user.id,
    token,
    platform: Platform.OS,
  }, {
    onConflict: 'user_id,token',
  });
}

export async function removePushToken(): Promise<void> {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return;

  const token = await Notifications.getExpoPushTokenAsync();

  await supabase
    .from('push_tokens')
    .delete()
    .eq('user_id', user.id)
    .eq('token', token.data);
}

export function addNotificationListener(
  handler: (notification: Notifications.Notification) => void
) {
  return Notifications.addNotificationReceivedListener(handler);
}

export function addNotificationResponseListener(
  handler: (response: Notifications.NotificationResponse) => void
) {
  return Notifications.addNotificationResponseReceivedListener(handler);
}
```

## Step 4: Initialize Notifications in App

Update `app/_layout.tsx`:

```tsx
import { useEffect, useRef } from 'react';
import { Platform } from 'react-native';
import * as Notifications from 'expo-notifications';
import { router } from 'expo-router';
import {
  registerForPushNotifications,
  savePushToken,
  addNotificationResponseListener,
} from '@/lib/notifications';
import { useAuth } from '@/contexts/AuthContext';

export default function RootLayout() {
  const { user } = useAuth();
  const notificationListener = useRef<any>();
  const responseListener = useRef<any>();

  useEffect(() => {
    if (!user) return;

    // Register for push notifications
    registerForPushNotifications().then((token) => {
      if (token) {
        savePushToken(token);
      }
    });

    // Handle notification taps
    responseListener.current = addNotificationResponseListener((response) => {
      const data = response.notification.request.content.data;

      if (data.eventId) {
        router.push(`/event/${data.eventId}`);
      } else if (data.screen) {
        router.push(data.screen);
      }
    });

    return () => {
      if (responseListener.current) {
        Notifications.removeNotificationSubscription(responseListener.current);
      }
    };
  }, [user]);

  // ... rest of layout
}
```

## Step 5: Send Notifications Edge Function

Create `supabase/functions/send-notification/index.ts`:

```typescript
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { userId, title, body, data } = await req.json();

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    );

    // Get user's push tokens
    const { data: tokens } = await supabase
      .from('push_tokens')
      .select('token')
      .eq('user_id', userId);

    if (!tokens?.length) {
      return new Response(
        JSON.stringify({ success: false, message: 'No push tokens found' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Send via Expo Push API
    const messages = tokens.map((t) => ({
      to: t.token,
      title,
      body,
      data,
      sound: 'default',
      priority: 'high',
    }));

    const response = await fetch('https://exp.host/--/api/v2/push/send', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Accept: 'application/json',
      },
      body: JSON.stringify(messages),
    });

    const result = await response.json();

    // Handle invalid tokens
    if (result.data) {
      for (let i = 0; i < result.data.length; i++) {
        const ticket = result.data[i];
        if (ticket.status === 'error' && ticket.details?.error === 'DeviceNotRegistered') {
          // Remove invalid token
          await supabase
            .from('push_tokens')
            .delete()
            .eq('token', tokens[i].token);
        }
      }
    }

    return new Response(
      JSON.stringify({ success: true, result }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  } catch (error) {
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

## Step 6: Daily Agenda Function

Create `supabase/functions/send-daily-agenda/index.ts`:

```typescript
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

serve(async (req) => {
  // Verify cron auth
  const authHeader = req.headers.get('Authorization');
  if (authHeader !== `Bearer ${Deno.env.get('CRON_SECRET')}`) {
    return new Response('Unauthorized', { status: 401 });
  }

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  );

  try {
    // Get users with daily agenda enabled
    const { data: users } = await supabase
      .from('notification_preferences')
      .select('user_id')
      .eq('daily_agenda_enabled', true);

    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const tomorrow = new Date(today);
    tomorrow.setDate(tomorrow.getDate() + 1);

    for (const { user_id } of users || []) {
      // Get today's events
      const { data: events } = await supabase
        .from('events')
        .select('title, start_time, is_all_day')
        .eq('user_id', user_id)
        .gte('start_time', today.toISOString())
        .lt('start_time', tomorrow.toISOString())
        .order('start_time');

      if (!events?.length) continue;

      // Format notification
      const eventCount = events.length;
      const firstEvent = events[0];
      const firstEventTime = firstEvent.is_all_day
        ? 'All day'
        : new Date(firstEvent.start_time).toLocaleTimeString('en-US', {
            hour: 'numeric',
            minute: '2-digit',
          });

      const title = `Today's Schedule`;
      const body =
        eventCount === 1
          ? `${firstEvent.title} at ${firstEventTime}`
          : `${eventCount} events today. First: ${firstEvent.title} at ${firstEventTime}`;

      // Send notification
      await fetch(`${Deno.env.get('SUPABASE_URL')}/functions/v1/send-notification`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          userId: user_id,
          title,
          body,
          data: { screen: '/(app)/(tabs)' },
        }),
      });
    }

    return new Response(
      JSON.stringify({ success: true, usersNotified: users?.length || 0 }),
      { headers: { 'Content-Type': 'application/json' } }
    );
  } catch (error) {
    console.error('Daily agenda error:', error);
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    );
  }
});
```

## Step 7: Event Reminders

Create `supabase/functions/send-event-reminders/index.ts`:

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
    // Get users with reminders enabled and their reminder time
    const { data: prefs } = await supabase
      .from('notification_preferences')
      .select('user_id, reminder_minutes')
      .eq('event_reminders_enabled', true);

    const now = new Date();
    let notificationsSent = 0;

    for (const { user_id, reminder_minutes } of prefs || []) {
      // Find events starting in reminder_minutes from now
      const reminderTime = new Date(now.getTime() + reminder_minutes * 60 * 1000);
      const windowStart = new Date(reminderTime.getTime() - 30 * 1000); // 30 sec buffer
      const windowEnd = new Date(reminderTime.getTime() + 30 * 1000);

      const { data: events } = await supabase
        .from('events')
        .select('id, title, start_time, location')
        .eq('user_id', user_id)
        .eq('is_all_day', false)
        .gte('start_time', windowStart.toISOString())
        .lt('start_time', windowEnd.toISOString());

      for (const event of events || []) {
        const startTime = new Date(event.start_time).toLocaleTimeString('en-US', {
          hour: 'numeric',
          minute: '2-digit',
        });

        await fetch(`${Deno.env.get('SUPABASE_URL')}/functions/v1/send-notification`, {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            userId: user_id,
            title: `Starting in ${reminder_minutes} min`,
            body: `${event.title} at ${startTime}${event.location ? ` - ${event.location}` : ''}`,
            data: { eventId: event.id },
          }),
        });

        notificationsSent++;
      }
    }

    return new Response(
      JSON.stringify({ success: true, notificationsSent }),
      { headers: { 'Content-Type': 'application/json' } }
    );
  } catch (error) {
    console.error('Event reminders error:', error);
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    );
  }
});
```

## Step 8: Schedule Reminder Cron

```sql
-- Run every minute to check for upcoming events
select cron.schedule(
  'event-reminders',
  '* * * * *', -- Every minute
  $$
  select
    net.http_post(
      url := 'https://YOUR_PROJECT.supabase.co/functions/v1/send-event-reminders',
      headers := jsonb_build_object(
        'Authorization', 'Bearer ' || current_setting('app.settings.cron_secret'),
        'Content-Type', 'application/json'
      ),
      body := '{}'::jsonb
    ) as request_id;
  $$
);
```

## Step 9: Notification Preferences UI

Create `components/NotificationSettings.tsx`:

```tsx
import { useState, useEffect } from 'react';
import { View, Text, Switch, StyleSheet } from 'react-native';
import { Picker } from '@react-native-picker/picker';
import { supabase } from '@/lib/supabase';
import { useAuth } from '@/contexts/AuthContext';

export function NotificationSettings() {
  const { user } = useAuth();
  const [prefs, setPrefs] = useState({
    daily_agenda_enabled: true,
    event_reminders_enabled: true,
    reminder_minutes: 15,
  });
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    loadPrefs();
  }, []);

  const loadPrefs = async () => {
    if (!user) return;

    const { data } = await supabase
      .from('notification_preferences')
      .select('*')
      .eq('user_id', user.id)
      .single();

    if (data) {
      setPrefs(data);
    }
    setLoading(false);
  };

  const updatePref = async (key: string, value: any) => {
    if (!user) return;

    setPrefs((prev) => ({ ...prev, [key]: value }));

    await supabase
      .from('notification_preferences')
      .upsert({
        user_id: user.id,
        [key]: value,
      });
  };

  if (loading) return null;

  return (
    <View style={styles.container}>
      <Text style={styles.title}>Notifications</Text>

      <View style={styles.row}>
        <View style={styles.rowContent}>
          <Text style={styles.label}>Daily Agenda</Text>
          <Text style={styles.description}>
            Get your schedule every morning at 7 AM
          </Text>
        </View>
        <Switch
          value={prefs.daily_agenda_enabled}
          onValueChange={(v) => updatePref('daily_agenda_enabled', v)}
        />
      </View>

      <View style={styles.row}>
        <View style={styles.rowContent}>
          <Text style={styles.label}>Event Reminders</Text>
          <Text style={styles.description}>
            Get notified before events start
          </Text>
        </View>
        <Switch
          value={prefs.event_reminders_enabled}
          onValueChange={(v) => updatePref('event_reminders_enabled', v)}
        />
      </View>

      {prefs.event_reminders_enabled && (
        <View style={styles.row}>
          <Text style={styles.label}>Reminder Time</Text>
          <Picker
            selectedValue={prefs.reminder_minutes}
            onValueChange={(v) => updatePref('reminder_minutes', v)}
            style={styles.picker}
          >
            <Picker.Item label="5 minutes before" value={5} />
            <Picker.Item label="10 minutes before" value={10} />
            <Picker.Item label="15 minutes before" value={15} />
            <Picker.Item label="30 minutes before" value={30} />
            <Picker.Item label="1 hour before" value={60} />
          </Picker>
        </View>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: { padding: 16 },
  title: { fontSize: 18, fontWeight: '600', marginBottom: 16 },
  row: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: 12,
    borderBottomWidth: 1,
    borderBottomColor: '#F3F4F6',
  },
  rowContent: { flex: 1, marginRight: 16 },
  label: { fontSize: 16, color: '#1F2937' },
  description: { fontSize: 14, color: '#6B7280', marginTop: 2 },
  picker: { width: 200 },
});
```

---

## Checkpoint

Before moving on, verify:

- [ ] Push tokens are registered on device
- [ ] Tokens are saved to database
- [ ] Daily agenda notifications work
- [ ] Event reminders send at correct time
- [ ] Notification tap opens correct screen
- [ ] Preferences save and load correctly

---

## Testing

### Send Test Notification

```bash
curl -X POST https://YOUR_PROJECT.supabase.co/functions/v1/send-notification \
  -H "Authorization: Bearer YOUR_SERVICE_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "user-uuid",
    "title": "Test Notification",
    "body": "This is a test",
    "data": { "screen": "/(app)/(tabs)" }
  }'
```

### Debug Token Issues

```typescript
// Log token on registration
const token = await registerForPushNotifications();
console.log('Push token:', token);
```

---

## Next Steps

Continue to [05-webhooks.md](./05-webhooks.md) for real-time calendar updates via webhooks.
