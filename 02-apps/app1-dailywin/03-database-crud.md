# 03 - Database & CRUD

> Day 1-3 of Week 2: Implement habit creation, reading, updating, and deletion

## Overview

We'll implement:
- Database schema setup in Supabase
- TypeScript types for database
- Habit CRUD operations
- Completion tracking
- Streak calculation

---

## Step 1: Create Database Tables

Go to Supabase **SQL Editor** and run:

```sql
-- Habits table
create table habits (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users(id) on delete cascade not null,
  name text not null,
  color text default '#3B82F6',
  icon text default 'checkmark-circle',
  created_at timestamptz default now(),
  archived_at timestamptz
);

-- Daily completions
-- NOTE: user_id is denormalized for RLS performance (avoids subquery joins)
create table completions (
  id uuid default gen_random_uuid() primary key,
  habit_id uuid references habits(id) on delete cascade not null,
  user_id uuid references auth.users(id) on delete cascade not null,
  completed_date date not null,
  created_at timestamptz default now(),

  -- Prevent duplicate completions for same day
  unique(habit_id, completed_date)
);

-- Indexes for performance
create index idx_habits_user on habits(user_id);
create index idx_completions_habit on completions(habit_id);
create index idx_completions_date on completions(completed_date);
-- Important: Index on user_id for RLS policy performance
create index idx_completions_user on completions(user_id);

-- Row Level Security
alter table habits enable row level security;
alter table completions enable row level security;

-- Policies
create policy "Users manage own habits"
  on habits for all
  using (auth.uid() = user_id);

-- Optimized policy: Direct user_id check instead of subquery
-- This is much faster than joining to habits table for each row
create policy "Users manage own completions"
  on completions for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- Trigger to auto-populate user_id from habit on insert
create or replace function set_completion_user_id()
returns trigger as $$
begin
  select user_id into new.user_id from habits where id = new.habit_id;
  return new;
end;
$$ language plpgsql security definer;

create trigger completion_set_user_id
before insert on completions
for each row
execute function set_completion_user_id();
```

## Step 2: Generate TypeScript Types

Install Supabase CLI and generate types:

```bash
npm install -D supabase

# Login to Supabase
npx supabase login

# Generate types (replace with your project ref)
npx supabase gen types typescript --project-id YOUR_PROJECT_REF > types/supabase.ts
```

Or manually create `types/supabase.ts`:

```typescript
export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export interface Database {
  public: {
    Tables: {
      habits: {
        Row: {
          id: string
          user_id: string
          name: string
          color: string
          icon: string
          created_at: string
          archived_at: string | null
        }
        Insert: {
          id?: string
          user_id: string
          name: string
          color?: string
          icon?: string
          created_at?: string
          archived_at?: string | null
        }
        Update: {
          id?: string
          user_id?: string
          name?: string
          color?: string
          icon?: string
          created_at?: string
          archived_at?: string | null
        }
      }
      completions: {
        Row: {
          id: string
          habit_id: string
          completed_date: string
          created_at: string
        }
        Insert: {
          id?: string
          habit_id: string
          completed_date: string
          created_at?: string
        }
        Update: {
          id?: string
          habit_id?: string
          completed_date?: string
          created_at?: string
        }
      }
    }
  }
}

export type Habit = Database['public']['Tables']['habits']['Row']
export type Completion = Database['public']['Tables']['completions']['Row']
```

## Step 3: Update Supabase Client

Update `lib/supabase.ts` to use types:

```typescript
import { createClient } from '@supabase/supabase-js';
import { Database } from '@/types/supabase';

// ... rest of config

export const supabase = createClient<Database>(supabaseUrl, supabaseAnonKey, {
  // ... options
});
```

## Step 4: Create useHabits Hook

Create `hooks/useHabits.ts`:

```typescript
import { useState, useEffect, useCallback } from 'react';
import { supabase } from '@/lib/supabase';
import { useAuth } from '@/contexts/AuthContext';
import { Habit } from '@/types/supabase';

export function useHabits() {
  const { user } = useAuth();
  const [habits, setHabits] = useState<Habit[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchHabits = useCallback(async () => {
    if (!user) return;

    try {
      setLoading(true);
      const { data, error } = await supabase
        .from('habits')
        .select('*')
        .eq('user_id', user.id)
        .is('archived_at', null)
        .order('created_at', { ascending: true });

      if (error) throw error;
      setHabits(data || []);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'An unexpected error occurred');
    } finally {
      setLoading(false);
    }
  }, [user]);

  useEffect(() => {
    fetchHabits();
  }, [fetchHabits]);

  const createHabit = async (name: string, color: string = '#3B82F6') => {
    if (!user) throw new Error('Not authenticated');

    const { data, error } = await supabase
      .from('habits')
      .insert({ user_id: user.id, name, color })
      .select()
      .single();

    if (error) throw error;
    setHabits((prev) => [...prev, data]);
    return data;
  };

  const updateHabit = async (id: string, updates: { name?: string; color?: string }) => {
    const { data, error } = await supabase
      .from('habits')
      .update(updates)
      .eq('id', id)
      .select()
      .single();

    if (error) throw error;
    setHabits((prev) => prev.map((h) => (h.id === id ? data : h)));
    return data;
  };

  const archiveHabit = async (id: string) => {
    const { error } = await supabase
      .from('habits')
      .update({ archived_at: new Date().toISOString() })
      .eq('id', id);

    if (error) throw error;
    setHabits((prev) => prev.filter((h) => h.id !== id));
  };

  const deleteHabit = async (id: string) => {
    const { error } = await supabase
      .from('habits')
      .delete()
      .eq('id', id);

    if (error) throw error;
    setHabits((prev) => prev.filter((h) => h.id !== id));
  };

  return {
    habits,
    loading,
    error,
    createHabit,
    updateHabit,
    archiveHabit,
    deleteHabit,
    refetch: fetchHabits,
  };
}
```

## Step 5: Create useCompletions Hook

Create `hooks/useCompletions.ts`:

```typescript
import { useState, useEffect, useCallback } from 'react';
import { supabase } from '@/lib/supabase';
import { Completion } from '@/types/supabase';

export function useCompletions(habitIds: string[], dateRange?: { start: string; end: string }) {
  const [completions, setCompletions] = useState<Completion[]>([]);
  const [loading, setLoading] = useState(true);

  const fetchCompletions = useCallback(async () => {
    if (habitIds.length === 0) {
      setCompletions([]);
      setLoading(false);
      return;
    }

    try {
      setLoading(true);
      let query = supabase
        .from('completions')
        .select('*')
        .in('habit_id', habitIds);

      if (dateRange) {
        query = query
          .gte('completed_date', dateRange.start)
          .lte('completed_date', dateRange.end);
      }

      const { data, error } = await query;
      if (error) throw error;
      setCompletions(data || []);
    } catch (err) {
      console.error('Error fetching completions:', err);
    } finally {
      setLoading(false);
    }
  }, [habitIds.join(','), dateRange?.start, dateRange?.end]);

  useEffect(() => {
    fetchCompletions();
  }, [fetchCompletions]);

  // Track which habits are currently being toggled to prevent double-submissions
  const [togglingHabits, setTogglingHabits] = useState<Set<string>>(new Set());

  const isToggling = (habitId: string) => togglingHabits.has(habitId);

  const toggleCompletion = async (habitId: string, date: string) => {
    // Prevent double-submissions
    if (togglingHabits.has(habitId)) {
      return null;
    }

    // Add to loading state
    setTogglingHabits((prev) => new Set(prev).add(habitId));

    try {
      const existing = completions.find(
        (c) => c.habit_id === habitId && c.completed_date === date
      );

      if (existing) {
        // Remove completion
        const { error } = await supabase
          .from('completions')
          .delete()
          .eq('id', existing.id);

        if (error) throw error;
        setCompletions((prev) => prev.filter((c) => c.id !== existing.id));
        return false;
      } else {
        // Add completion
        const { data, error } = await supabase
          .from('completions')
          .insert({ habit_id: habitId, completed_date: date })
          .select()
          .single();

        if (error) throw error;
        setCompletions((prev) => [...prev, data]);
        return true;
      }
    } finally {
      // Remove from loading state
      setTogglingHabits((prev) => {
        const next = new Set(prev);
        next.delete(habitId);
        return next;
      });
    }
  };

  const isCompleted = (habitId: string, date: string) => {
    return completions.some(
      (c) => c.habit_id === habitId && c.completed_date === date
    );
  };

  return {
    completions,
    loading,
    toggleCompletion,
    isCompleted,
    isToggling,  // Expose loading state for individual habits
    refetch: fetchCompletions,
  };
}
```

## Step 6: Streak Calculation

Add streak calculation utility in `lib/streaks.ts`:

First, install date-fns for proper timezone handling:

```bash
npm install date-fns date-fns-tz
```

```typescript
import { Completion } from '@/types/supabase';
import { format, subDays, differenceInCalendarDays } from 'date-fns';
import { toZonedTime } from 'date-fns-tz';

/**
 * Get user's local date string accounting for timezone
 * This prevents streak breaks caused by server/client timezone differences
 */
function getLocalDateString(timezone?: string): string {
  const tz = timezone || Intl.DateTimeFormat().resolvedOptions().timeZone;
  const zonedDate = toZonedTime(new Date(), tz);
  return format(zonedDate, 'yyyy-MM-dd');
}

function getYesterdayString(timezone?: string): string {
  const tz = timezone || Intl.DateTimeFormat().resolvedOptions().timeZone;
  const zonedDate = toZonedTime(new Date(), tz);
  const yesterday = subDays(zonedDate, 1);
  return format(yesterday, 'yyyy-MM-dd');
}

export function calculateStreak(
  habitId: string,
  completions: Completion[],
  userTimezone?: string
): { current: number; longest: number } {
  const habitCompletions = completions
    .filter((c) => c.habit_id === habitId)
    .map((c) => c.completed_date)
    .sort()
    .reverse();

  if (habitCompletions.length === 0) {
    return { current: 0, longest: 0 };
  }

  // Use timezone-aware date calculation
  const today = getLocalDateString(userTimezone);
  const yesterday = getYesterdayString(userTimezone);

  // Current streak
  let currentStreak = 0;
  let checkDate = today;

  // Allow starting from today or yesterday
  if (habitCompletions[0] !== today && habitCompletions[0] !== yesterday) {
    currentStreak = 0;
  } else {
    checkDate = habitCompletions[0];
    for (const date of habitCompletions) {
      if (date === checkDate) {
        currentStreak++;
        // Go to previous day using proper date math
        const d = new Date(checkDate + 'T12:00:00'); // Use noon to avoid DST issues
        const prevDay = subDays(d, 1);
        checkDate = format(prevDay, 'yyyy-MM-dd');
      } else if (date < checkDate) {
        break;
      }
    }
  }

  // Longest streak - use differenceInCalendarDays for proper calculation
  let longestStreak = 0;
  let tempStreak = 1;

  for (let i = 0; i < habitCompletions.length - 1; i++) {
    const current = new Date(habitCompletions[i] + 'T12:00:00');
    const next = new Date(habitCompletions[i + 1] + 'T12:00:00');
    const diffDays = differenceInCalendarDays(current, next);

    if (diffDays === 1) {
      tempStreak++;
    } else {
      longestStreak = Math.max(longestStreak, tempStreak);
      tempStreak = 1;
    }
  }
  longestStreak = Math.max(longestStreak, tempStreak);

  return { current: currentStreak, longest: longestStreak };
}
```

## Step 7: Today's Habits Screen

Update `app/(app)/(tabs)/index.tsx`:

```tsx
import { View, Text, FlatList, TouchableOpacity, StyleSheet } from 'react-native';
import { router } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { useHabits } from '@/hooks/useHabits';
import { useCompletions } from '@/hooks/useCompletions';

export default function TodayScreen() {
  const { habits, loading: habitsLoading } = useHabits();
  const today = new Date().toISOString().split('T')[0];

  const { isCompleted, toggleCompletion, loading: completionsLoading } = useCompletions(
    habits.map((h) => h.id),
    { start: today, end: today }
  );

  const handleToggle = async (habitId: string) => {
    try {
      await toggleCompletion(habitId, today);
    } catch (error) {
      console.error('Error toggling completion:', error);
    }
  };

  if (habitsLoading || completionsLoading) {
    return (
      <View style={styles.center}>
        <Text>Loading...</Text>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <FlatList
        data={habits}
        keyExtractor={(item) => item.id}
        contentContainerStyle={styles.list}
        ListEmptyComponent={
          <View style={styles.empty}>
            <Text style={styles.emptyText}>No habits yet</Text>
            <Text style={styles.emptySubtext}>
              Tap the + button to create your first habit
            </Text>
          </View>
        }
        renderItem={({ item }) => {
          const completed = isCompleted(item.id, today);
          return (
            <TouchableOpacity
              style={[
                styles.habitCard,
                { borderLeftColor: item.color },
                completed && styles.habitCardCompleted,
              ]}
              onPress={() => handleToggle(item.id)}
              onLongPress={() => router.push(`/habit/${item.id}`)}
            >
              <View style={styles.habitInfo}>
                <Text style={[styles.habitName, completed && styles.habitNameCompleted]}>
                  {item.name}
                </Text>
              </View>
              <Ionicons
                name={completed ? 'checkmark-circle' : 'ellipse-outline'}
                size={32}
                color={completed ? item.color : '#D1D5DB'}
              />
            </TouchableOpacity>
          );
        }}
      />

      <TouchableOpacity
        style={styles.fab}
        onPress={() => router.push('/habit/new')}
      >
        <Ionicons name="add" size={28} color="#fff" />
      </TouchableOpacity>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#F9FAFB',
  },
  center: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  list: {
    padding: 16,
    paddingBottom: 100,
  },
  empty: {
    alignItems: 'center',
    marginTop: 60,
  },
  emptyText: {
    fontSize: 18,
    fontWeight: '600',
    color: '#6B7280',
  },
  emptySubtext: {
    fontSize: 14,
    color: '#9CA3AF',
    marginTop: 8,
  },
  habitCard: {
    backgroundColor: '#fff',
    borderRadius: 12,
    padding: 16,
    marginBottom: 12,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    borderLeftWidth: 4,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.05,
    shadowRadius: 2,
    elevation: 1,
  },
  habitCardCompleted: {
    backgroundColor: '#F0FDF4',
  },
  habitInfo: {
    flex: 1,
  },
  habitName: {
    fontSize: 16,
    fontWeight: '600',
    color: '#1F2937',
  },
  habitNameCompleted: {
    textDecorationLine: 'line-through',
    color: '#6B7280',
  },
  fab: {
    position: 'absolute',
    bottom: 24,
    right: 24,
    width: 56,
    height: 56,
    borderRadius: 28,
    backgroundColor: '#3B82F6',
    justifyContent: 'center',
    alignItems: 'center',
    shadowColor: '#3B82F6',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.3,
    shadowRadius: 8,
    elevation: 8,
  },
});
```

## Step 8: Create Habit Screen

Create `app/(app)/habit/new.tsx`:

```tsx
import { useState } from 'react';
import {
  View,
  Text,
  TextInput,
  TouchableOpacity,
  StyleSheet,
  Alert,
} from 'react-native';
import { router } from 'expo-router';
import { useHabits } from '@/hooks/useHabits';

const COLORS = [
  '#3B82F6', // blue
  '#10B981', // green
  '#F59E0B', // yellow
  '#EF4444', // red
  '#8B5CF6', // purple
  '#EC4899', // pink
  '#06B6D4', // cyan
  '#F97316', // orange
];

export default function NewHabitScreen() {
  const [name, setName] = useState('');
  const [color, setColor] = useState(COLORS[0]);
  const [loading, setLoading] = useState(false);
  const { createHabit, habits } = useHabits();

  const handleCreate = async () => {
    if (!name.trim()) {
      Alert.alert('Error', 'Please enter a habit name');
      return;
    }

    // Check habit limit (free tier = 3)
    if (habits.length >= 3) {
      // Check subscription status here
      // For now, show paywall
      router.push('/paywall');
      return;
    }

    setLoading(true);
    try {
      await createHabit(name.trim(), color);
      router.back();
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Failed to create habit';
      Alert.alert('Error', message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <View style={styles.container}>
      <Text style={styles.title}>New Habit</Text>

      <Text style={styles.label}>Name</Text>
      <TextInput
        style={styles.input}
        placeholder="e.g., Exercise, Read, Meditate"
        value={name}
        onChangeText={setName}
        autoFocus
      />

      <Text style={styles.label}>Color</Text>
      <View style={styles.colorGrid}>
        {COLORS.map((c) => (
          <TouchableOpacity
            key={c}
            style={[
              styles.colorOption,
              { backgroundColor: c },
              color === c && styles.colorSelected,
            ]}
            onPress={() => setColor(c)}
          />
        ))}
      </View>

      <View style={styles.buttons}>
        <TouchableOpacity
          style={styles.cancelButton}
          onPress={() => router.back()}
        >
          <Text style={styles.cancelText}>Cancel</Text>
        </TouchableOpacity>

        <TouchableOpacity
          style={[styles.createButton, loading && styles.buttonDisabled]}
          onPress={handleCreate}
          disabled={loading}
        >
          <Text style={styles.createText}>
            {loading ? 'Creating...' : 'Create Habit'}
          </Text>
        </TouchableOpacity>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#fff',
    padding: 24,
  },
  title: {
    fontSize: 24,
    fontWeight: 'bold',
    marginBottom: 24,
    color: '#1F2937',
  },
  label: {
    fontSize: 14,
    fontWeight: '600',
    color: '#6B7280',
    marginBottom: 8,
  },
  input: {
    borderWidth: 1,
    borderColor: '#E5E7EB',
    borderRadius: 8,
    padding: 16,
    fontSize: 16,
    marginBottom: 24,
  },
  colorGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 12,
    marginBottom: 32,
  },
  colorOption: {
    width: 48,
    height: 48,
    borderRadius: 24,
  },
  colorSelected: {
    borderWidth: 3,
    borderColor: '#1F2937',
  },
  buttons: {
    flexDirection: 'row',
    gap: 12,
  },
  cancelButton: {
    flex: 1,
    padding: 16,
    borderRadius: 8,
    backgroundColor: '#F3F4F6',
    alignItems: 'center',
  },
  cancelText: {
    fontSize: 16,
    fontWeight: '600',
    color: '#6B7280',
  },
  createButton: {
    flex: 1,
    padding: 16,
    borderRadius: 8,
    backgroundColor: '#3B82F6',
    alignItems: 'center',
  },
  buttonDisabled: {
    opacity: 0.6,
  },
  createText: {
    fontSize: 16,
    fontWeight: '600',
    color: '#fff',
  },
});
```

---

## Checkpoint

Before moving on, verify:

- [ ] Can create new habits
- [ ] Habits display on Today screen
- [ ] Can mark habits complete/incomplete
- [ ] Completions persist after refresh
- [ ] Can navigate to habit detail

---

## Next Steps

Continue to [04-ui-polish.md](./04-ui-polish.md) to add animations and polish.
