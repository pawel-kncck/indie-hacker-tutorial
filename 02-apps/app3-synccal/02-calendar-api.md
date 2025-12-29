# 02 - Calendar API

> Day 4-5 of Week 6: Fetch and manage calendar data

## Overview

We'll implement:
- Fetching user's calendars
- Syncing events
- Creating/updating events
- Handling calendar permissions

---

## Step 1: Calendar Sync Function

Create `supabase/functions/sync-calendars/index.ts`:

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
    const { userId } = await req.json();

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    );

    // Get valid access token
    const accessToken = await getValidAccessToken(userId);

    // Fetch calendar list from Google
    const calendarListResponse = await fetch(
      'https://www.googleapis.com/calendar/v3/users/me/calendarList',
      {
        headers: { Authorization: `Bearer ${accessToken}` },
      }
    );

    if (!calendarListResponse.ok) {
      throw new Error('Failed to fetch calendars');
    }

    const calendarList = await calendarListResponse.json();

    // Sync calendars to database
    for (const calendar of calendarList.items) {
      await supabase.from('calendars').upsert({
        user_id: userId,
        google_calendar_id: calendar.id,
        name: calendar.summary,
        color: calendar.backgroundColor,
        is_primary: calendar.primary || false,
      }, {
        onConflict: 'user_id,google_calendar_id',
      });
    }

    // Fetch events for each calendar
    const { data: calendars } = await supabase
      .from('calendars')
      .select('id, google_calendar_id')
      .eq('user_id', userId)
      .eq('sync_enabled', true);

    for (const calendar of calendars || []) {
      await syncCalendarEvents(
        supabase,
        userId,
        calendar.id,
        calendar.google_calendar_id,
        accessToken
      );
    }

    return new Response(
      JSON.stringify({ success: true, calendars: calendarList.items.length }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  } catch (error) {
    console.error('Sync error:', error);
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  }
});

async function syncCalendarEvents(
  supabase: any,
  userId: string,
  calendarId: string,
  googleCalendarId: string,
  accessToken: string
) {
  // Fetch events from now to 30 days ahead
  const timeMin = new Date().toISOString();
  const timeMax = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString();

  const params = new URLSearchParams({
    timeMin,
    timeMax,
    singleEvents: 'true',
    orderBy: 'startTime',
    maxResults: '250',
  });

  const eventsResponse = await fetch(
    `https://www.googleapis.com/calendar/v3/calendars/${encodeURIComponent(googleCalendarId)}/events?${params}`,
    {
      headers: { Authorization: `Bearer ${accessToken}` },
    }
  );

  if (!eventsResponse.ok) {
    console.error('Failed to fetch events for calendar:', googleCalendarId);
    return;
  }

  const eventsData = await eventsResponse.json();

  for (const event of eventsData.items || []) {
    // Skip cancelled events
    if (event.status === 'cancelled') continue;

    const startTime = event.start.dateTime || event.start.date;
    const endTime = event.end.dateTime || event.end.date;
    const isAllDay = !event.start.dateTime;

    await supabase.from('events').upsert({
      user_id: userId,
      calendar_id: calendarId,
      google_event_id: event.id,
      title: event.summary || '(No title)',
      description: event.description,
      start_time: startTime,
      end_time: endTime,
      location: event.location,
      is_all_day: isAllDay,
      status: event.status,
    }, {
      onConflict: 'calendar_id,google_event_id',
    });
  }

  // Update last synced timestamp
  await supabase
    .from('calendars')
    .update({ last_synced_at: new Date().toISOString() })
    .eq('id', calendarId);
}
```

## Step 2: Create Event Function

Create `supabase/functions/create-event/index.ts`:

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
    // Get authenticated user
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) throw new Error('Unauthorized');

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } }
    );

    const { data: { user }, error: userError } = await supabase.auth.getUser();
    if (userError || !user) throw new Error('Unauthorized');

    const { calendarId, title, description, startTime, endTime, location, isAllDay } = await req.json();

    // Get Google calendar ID
    const adminClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    );

    const { data: calendar } = await adminClient
      .from('calendars')
      .select('google_calendar_id')
      .eq('id', calendarId)
      .eq('user_id', user.id)
      .single();

    if (!calendar) throw new Error('Calendar not found');

    // Get access token
    const accessToken = await getValidAccessToken(user.id);

    // Create event in Google Calendar
    const eventBody: any = {
      summary: title,
      description,
      location,
    };

    if (isAllDay) {
      eventBody.start = { date: startTime.split('T')[0] };
      eventBody.end = { date: endTime.split('T')[0] };
    } else {
      eventBody.start = { dateTime: startTime, timeZone: 'UTC' };
      eventBody.end = { dateTime: endTime, timeZone: 'UTC' };
    }

    const response = await fetch(
      `https://www.googleapis.com/calendar/v3/calendars/${encodeURIComponent(calendar.google_calendar_id)}/events`,
      {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${accessToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(eventBody),
      }
    );

    if (!response.ok) {
      const error = await response.text();
      throw new Error(`Failed to create event: ${error}`);
    }

    const googleEvent = await response.json();

    // Store in local database
    const { data: event } = await adminClient.from('events').insert({
      user_id: user.id,
      calendar_id: calendarId,
      google_event_id: googleEvent.id,
      title,
      description,
      start_time: startTime,
      end_time: endTime,
      location,
      is_all_day: isAllDay,
      status: 'confirmed',
    }).select().single();

    return new Response(
      JSON.stringify({ success: true, event }),
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

## Step 3: useCalendars Hook

Create `hooks/useCalendars.ts`:

```typescript
import { useState, useEffect, useCallback } from 'react';
import { supabase } from '@/lib/supabase';
import { useAuth } from '@/contexts/AuthContext';

export type Calendar = {
  id: string;
  google_calendar_id: string;
  name: string;
  color: string | null;
  is_primary: boolean;
  sync_enabled: boolean;
  last_synced_at: string | null;
};

export function useCalendars() {
  const { user } = useAuth();
  const [calendars, setCalendars] = useState<Calendar[]>([]);
  const [loading, setLoading] = useState(true);

  const fetchCalendars = useCallback(async () => {
    if (!user) return;

    const { data, error } = await supabase
      .from('calendars')
      .select('*')
      .eq('user_id', user.id)
      .order('is_primary', { ascending: false });

    if (!error) {
      setCalendars(data || []);
    }
    setLoading(false);
  }, [user]);

  useEffect(() => {
    fetchCalendars();
  }, [fetchCalendars]);

  const syncCalendars = async () => {
    if (!user) return;

    setLoading(true);
    const { error } = await supabase.functions.invoke('sync-calendars', {
      body: { userId: user.id },
    });

    if (!error) {
      await fetchCalendars();
    }
    setLoading(false);
  };

  const toggleCalendarSync = async (calendarId: string, enabled: boolean) => {
    await supabase
      .from('calendars')
      .update({ sync_enabled: enabled })
      .eq('id', calendarId);

    setCalendars((prev) =>
      prev.map((c) =>
        c.id === calendarId ? { ...c, sync_enabled: enabled } : c
      )
    );
  };

  return {
    calendars,
    loading,
    syncCalendars,
    toggleCalendarSync,
    refetch: fetchCalendars,
  };
}
```

## Step 4: useEvents Hook

Create `hooks/useEvents.ts`:

```typescript
import { useState, useEffect, useCallback } from 'react';
import { supabase } from '@/lib/supabase';
import { useAuth } from '@/contexts/AuthContext';

export type Event = {
  id: string;
  calendar_id: string;
  title: string;
  description: string | null;
  start_time: string;
  end_time: string;
  location: string | null;
  is_all_day: boolean;
  status: string;
  calendar?: {
    name: string;
    color: string;
  };
};

type EventsFilter = {
  startDate?: string;
  endDate?: string;
  calendarIds?: string[];
};

export function useEvents(filter?: EventsFilter) {
  const { user } = useAuth();
  const [events, setEvents] = useState<Event[]>([]);
  const [loading, setLoading] = useState(true);

  const fetchEvents = useCallback(async () => {
    if (!user) return;

    let query = supabase
      .from('events')
      .select(`
        *,
        calendar:calendars(name, color)
      `)
      .eq('user_id', user.id)
      .order('start_time', { ascending: true });

    if (filter?.startDate) {
      query = query.gte('start_time', filter.startDate);
    }

    if (filter?.endDate) {
      query = query.lte('start_time', filter.endDate);
    }

    if (filter?.calendarIds?.length) {
      query = query.in('calendar_id', filter.calendarIds);
    }

    const { data, error } = await query;

    if (!error) {
      setEvents(data || []);
    }
    setLoading(false);
  }, [user, filter?.startDate, filter?.endDate, filter?.calendarIds?.join(',')]);

  useEffect(() => {
    fetchEvents();
  }, [fetchEvents]);

  const createEvent = async (eventData: {
    calendarId: string;
    title: string;
    description?: string;
    startTime: string;
    endTime: string;
    location?: string;
    isAllDay?: boolean;
  }) => {
    const { data, error } = await supabase.functions.invoke('create-event', {
      body: eventData,
    });

    if (error) throw error;

    await fetchEvents();
    return data.event;
  };

  return {
    events,
    loading,
    createEvent,
    refetch: fetchEvents,
  };
}
```

## Step 5: Today's Agenda Screen

Update `app/(app)/(tabs)/index.tsx`:

```tsx
import { View, Text, FlatList, StyleSheet, RefreshControl } from 'react-native';
import { useEvents, Event } from '@/hooks/useEvents';
import { format, isToday, isTomorrow, parseISO } from 'date-fns';

export default function AgendaScreen() {
  const today = new Date().toISOString().split('T')[0];
  const endDate = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000)
    .toISOString()
    .split('T')[0];

  const { events, loading, refetch } = useEvents({
    startDate: today,
    endDate,
  });

  const groupedEvents = groupEventsByDate(events);

  return (
    <View style={styles.container}>
      <FlatList
        data={Object.entries(groupedEvents)}
        keyExtractor={([date]) => date}
        refreshControl={
          <RefreshControl refreshing={loading} onRefresh={refetch} />
        }
        ListEmptyComponent={
          <View style={styles.empty}>
            <Text style={styles.emptyText}>No upcoming events</Text>
            <Text style={styles.emptySubtext}>
              Connect your Google Calendar to see your schedule
            </Text>
          </View>
        }
        renderItem={({ item: [date, dateEvents] }) => (
          <View style={styles.dateSection}>
            <Text style={styles.dateHeader}>{formatDateHeader(date)}</Text>
            {dateEvents.map((event) => (
              <EventCard key={event.id} event={event} />
            ))}
          </View>
        )}
      />
    </View>
  );
}

function EventCard({ event }: { event: Event }) {
  const startTime = parseISO(event.start_time);

  return (
    <View
      style={[
        styles.eventCard,
        { borderLeftColor: event.calendar?.color || '#3B82F6' },
      ]}
    >
      <View style={styles.eventTime}>
        <Text style={styles.timeText}>
          {event.is_all_day ? 'All day' : format(startTime, 'h:mm a')}
        </Text>
      </View>
      <View style={styles.eventContent}>
        <Text style={styles.eventTitle}>{event.title}</Text>
        {event.location && (
          <Text style={styles.eventLocation}>{event.location}</Text>
        )}
        <Text style={styles.calendarName}>{event.calendar?.name}</Text>
      </View>
    </View>
  );
}

function groupEventsByDate(events: Event[]): Record<string, Event[]> {
  return events.reduce((groups, event) => {
    const date = event.start_time.split('T')[0];
    if (!groups[date]) groups[date] = [];
    groups[date].push(event);
    return groups;
  }, {} as Record<string, Event[]>);
}

function formatDateHeader(dateStr: string): string {
  const date = parseISO(dateStr);
  if (isToday(date)) return 'Today';
  if (isTomorrow(date)) return 'Tomorrow';
  return format(date, 'EEEE, MMMM d');
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#F9FAFB' },
  empty: { alignItems: 'center', paddingVertical: 60 },
  emptyText: { fontSize: 18, fontWeight: '600', color: '#6B7280' },
  emptySubtext: { fontSize: 14, color: '#9CA3AF', marginTop: 8, textAlign: 'center', paddingHorizontal: 32 },
  dateSection: { marginBottom: 24 },
  dateHeader: {
    fontSize: 14,
    fontWeight: '600',
    color: '#6B7280',
    paddingHorizontal: 16,
    paddingVertical: 8,
    backgroundColor: '#F3F4F6',
  },
  eventCard: {
    flexDirection: 'row',
    backgroundColor: '#fff',
    padding: 16,
    borderLeftWidth: 4,
    borderBottomWidth: 1,
    borderBottomColor: '#F3F4F6',
  },
  eventTime: { width: 70 },
  timeText: { fontSize: 14, color: '#6B7280' },
  eventContent: { flex: 1 },
  eventTitle: { fontSize: 16, fontWeight: '600', color: '#1F2937' },
  eventLocation: { fontSize: 14, color: '#6B7280', marginTop: 4 },
  calendarName: { fontSize: 12, color: '#9CA3AF', marginTop: 4 },
});
```

## Step 6: Create Event Screen

Create `app/(app)/event/new.tsx`:

```tsx
import { useState } from 'react';
import {
  View,
  Text,
  TextInput,
  TouchableOpacity,
  StyleSheet,
  Alert,
  ScrollView,
} from 'react-native';
import { router } from 'expo-router';
import DateTimePicker from '@react-native-community/datetimepicker';
import { useEvents } from '@/hooks/useEvents';
import { useCalendars } from '@/hooks/useCalendars';

export default function NewEventScreen() {
  const { calendars } = useCalendars();
  const { createEvent } = useEvents();

  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [location, setLocation] = useState('');
  const [startDate, setStartDate] = useState(new Date());
  const [endDate, setEndDate] = useState(new Date(Date.now() + 60 * 60 * 1000));
  const [calendarId, setCalendarId] = useState(calendars[0]?.id || '');
  const [loading, setLoading] = useState(false);

  const handleCreate = async () => {
    if (!title.trim()) {
      Alert.alert('Error', 'Please enter an event title');
      return;
    }

    if (!calendarId) {
      Alert.alert('Error', 'Please select a calendar');
      return;
    }

    setLoading(true);
    try {
      await createEvent({
        calendarId,
        title,
        description,
        location,
        startTime: startDate.toISOString(),
        endTime: endDate.toISOString(),
      });
      router.back();
    } catch (error: any) {
      Alert.alert('Error', error.message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <ScrollView style={styles.container}>
      <Text style={styles.label}>Title</Text>
      <TextInput
        style={styles.input}
        placeholder="Event title"
        value={title}
        onChangeText={setTitle}
      />

      <Text style={styles.label}>Calendar</Text>
      <View style={styles.calendarPicker}>
        {calendars.map((cal) => (
          <TouchableOpacity
            key={cal.id}
            style={[
              styles.calendarOption,
              calendarId === cal.id && styles.calendarSelected,
            ]}
            onPress={() => setCalendarId(cal.id)}
          >
            <View style={[styles.colorDot, { backgroundColor: cal.color || '#3B82F6' }]} />
            <Text style={styles.calendarName}>{cal.name}</Text>
          </TouchableOpacity>
        ))}
      </View>

      <Text style={styles.label}>Start</Text>
      <DateTimePicker
        value={startDate}
        mode="datetime"
        onChange={(_, date) => date && setStartDate(date)}
      />

      <Text style={styles.label}>End</Text>
      <DateTimePicker
        value={endDate}
        mode="datetime"
        onChange={(_, date) => date && setEndDate(date)}
      />

      <Text style={styles.label}>Location (optional)</Text>
      <TextInput
        style={styles.input}
        placeholder="Add location"
        value={location}
        onChangeText={setLocation}
      />

      <Text style={styles.label}>Description (optional)</Text>
      <TextInput
        style={[styles.input, styles.textArea]}
        placeholder="Add description"
        value={description}
        onChangeText={setDescription}
        multiline
        numberOfLines={4}
      />

      <TouchableOpacity
        style={[styles.button, loading && styles.buttonDisabled]}
        onPress={handleCreate}
        disabled={loading}
      >
        <Text style={styles.buttonText}>
          {loading ? 'Creating...' : 'Create Event'}
        </Text>
      </TouchableOpacity>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#fff', padding: 16 },
  label: { fontSize: 14, fontWeight: '600', color: '#6B7280', marginTop: 16, marginBottom: 8 },
  input: { borderWidth: 1, borderColor: '#E5E7EB', borderRadius: 8, padding: 12, fontSize: 16 },
  textArea: { height: 100, textAlignVertical: 'top' },
  calendarPicker: { gap: 8 },
  calendarOption: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: 12,
    borderRadius: 8,
    borderWidth: 1,
    borderColor: '#E5E7EB',
  },
  calendarSelected: { borderColor: '#3B82F6', backgroundColor: '#EFF6FF' },
  colorDot: { width: 12, height: 12, borderRadius: 6, marginRight: 8 },
  calendarName: { fontSize: 16 },
  button: { backgroundColor: '#3B82F6', padding: 16, borderRadius: 8, alignItems: 'center', marginTop: 24, marginBottom: 40 },
  buttonDisabled: { opacity: 0.6 },
  buttonText: { color: '#fff', fontSize: 16, fontWeight: '600' },
});
```

---

## Checkpoint

Before moving on, verify:

- [ ] Calendars sync from Google
- [ ] Events display in agenda view
- [ ] Can create new events
- [ ] Events appear in Google Calendar
- [ ] Calendar colors show correctly

---

## Next Steps

Continue to [03-cron-jobs.md](./03-cron-jobs.md) to set up automated background sync.
