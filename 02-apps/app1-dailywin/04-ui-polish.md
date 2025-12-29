# 04 - UI Polish

> Day 4 of Week 2: Add animations, improve visual design, and make the app feel polished

## Overview

We'll implement:
- Haptic feedback on completions
- Smooth animations with Reanimated
- Loading states and skeletons
- Pull-to-refresh
- Empty states
- Responsive design

---

## Step 1: Install Animation Dependencies

```bash
npx expo install react-native-reanimated expo-haptics
```

Update `babel.config.js`:

```javascript
module.exports = function (api) {
  api.cache(true);
  return {
    presets: ['babel-preset-expo'],
    plugins: ['react-native-reanimated/plugin'],
  };
};
```

Restart Metro with cache cleared:

```bash
npx expo start --clear
```

## Step 2: Add Haptic Feedback

Create `lib/haptics.ts`:

```typescript
import * as Haptics from 'expo-haptics';
import { Platform } from 'react-native';

export const haptics = {
  light: () => {
    if (Platform.OS !== 'web') {
      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    }
  },
  medium: () => {
    if (Platform.OS !== 'web') {
      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    }
  },
  success: () => {
    if (Platform.OS !== 'web') {
      Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
    }
  },
  error: () => {
    if (Platform.OS !== 'web') {
      Haptics.notificationAsync(Haptics.NotificationFeedbackType.Error);
    }
  },
};
```

## Step 3: Animated Check Button

Create `components/CheckButton.tsx`:

```tsx
import { TouchableOpacity, StyleSheet } from 'react-native';
import Animated, {
  useAnimatedStyle,
  useSharedValue,
  withSpring,
  withSequence,
} from 'react-native-reanimated';
import { Ionicons } from '@expo/vector-icons';
import { haptics } from '@/lib/haptics';

type Props = {
  completed: boolean;
  color: string;
  onPress: () => void;
};

export function CheckButton({ completed, color, onPress }: Props) {
  const scale = useSharedValue(1);

  const animatedStyle = useAnimatedStyle(() => ({
    transform: [{ scale: scale.value }],
  }));

  const handlePress = () => {
    scale.value = withSequence(
      withSpring(0.8, { damping: 4 }),
      withSpring(1.2, { damping: 4 }),
      withSpring(1, { damping: 4 })
    );

    if (!completed) {
      haptics.success();
    } else {
      haptics.light();
    }

    onPress();
  };

  return (
    <TouchableOpacity onPress={handlePress} activeOpacity={0.8}>
      <Animated.View style={animatedStyle}>
        <Ionicons
          name={completed ? 'checkmark-circle' : 'ellipse-outline'}
          size={36}
          color={completed ? color : '#D1D5DB'}
        />
      </Animated.View>
    </TouchableOpacity>
  );
}
```

## Step 4: Animated Habit Card

Create `components/HabitCard.tsx`:

```tsx
import { TouchableOpacity, View, Text, StyleSheet } from 'react-native';
import Animated, {
  useAnimatedStyle,
  withTiming,
  FadeIn,
  Layout,
} from 'react-native-reanimated';
import { CheckButton } from './CheckButton';

type Props = {
  id: string;
  name: string;
  color: string;
  completed: boolean;
  onToggle: () => void;
  onLongPress: () => void;
};

const AnimatedTouchable = Animated.createAnimatedComponent(TouchableOpacity);

export function HabitCard({
  id,
  name,
  color,
  completed,
  onToggle,
  onLongPress,
}: Props) {
  const animatedStyle = useAnimatedStyle(() => ({
    backgroundColor: withTiming(completed ? '#F0FDF4' : '#FFFFFF', {
      duration: 200,
    }),
  }));

  return (
    <AnimatedTouchable
      entering={FadeIn}
      layout={Layout.springify()}
      style={[styles.card, { borderLeftColor: color }, animatedStyle]}
      onPress={onToggle}
      onLongPress={onLongPress}
      activeOpacity={0.8}
      // Accessibility props - essential for screen reader users
      accessible={true}
      accessibilityRole="button"
      accessibilityLabel={`${name} habit`}
      accessibilityState={{ checked: completed }}
      accessibilityHint={
        completed
          ? 'Double tap to mark as incomplete. Long press for options.'
          : 'Double tap to mark as complete. Long press for options.'
      }
    >
      <View style={styles.content}>
        <Text
          style={[styles.name, completed && styles.nameCompleted]}
          numberOfLines={1}
          accessibilityElementsHidden={true} // Parent handles accessibility
        >
          {name}
        </Text>
      </View>
      <CheckButton
        completed={completed}
        color={color}
        onPress={onToggle}
        accessibilityLabel={completed ? 'Completed' : 'Not completed'}
      />
    </AnimatedTouchable>
  );
}

const styles = StyleSheet.create({
  card: {
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
  content: {
    flex: 1,
    marginRight: 12,
  },
  name: {
    fontSize: 16,
    fontWeight: '600',
    color: '#1F2937',
  },
  nameCompleted: {
    textDecorationLine: 'line-through',
    color: '#6B7280',
  },
});
```

## Step 5: Skeleton Loading

Create `components/SkeletonCard.tsx`:

```tsx
import { View, StyleSheet } from 'react-native';
import Animated, {
  useAnimatedStyle,
  useSharedValue,
  withRepeat,
  withTiming,
} from 'react-native-reanimated';
import { useEffect } from 'react';

export function SkeletonCard() {
  const opacity = useSharedValue(0.3);

  useEffect(() => {
    opacity.value = withRepeat(
      withTiming(0.7, { duration: 1000 }),
      -1,
      true
    );
  }, []);

  const animatedStyle = useAnimatedStyle(() => ({
    opacity: opacity.value,
  }));

  return (
    <Animated.View style={[styles.card, animatedStyle]}>
      <View style={styles.content}>
        <View style={styles.titleBar} />
      </View>
      <View style={styles.circle} />
    </Animated.View>
  );
}

export function SkeletonList() {
  return (
    <View style={styles.list}>
      <SkeletonCard />
      <SkeletonCard />
      <SkeletonCard />
    </View>
  );
}

const styles = StyleSheet.create({
  list: {
    padding: 16,
  },
  card: {
    backgroundColor: '#E5E7EB',
    borderRadius: 12,
    padding: 16,
    marginBottom: 12,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    borderLeftWidth: 4,
    borderLeftColor: '#D1D5DB',
  },
  content: {
    flex: 1,
  },
  titleBar: {
    height: 16,
    width: '60%',
    backgroundColor: '#D1D5DB',
    borderRadius: 4,
  },
  circle: {
    width: 36,
    height: 36,
    borderRadius: 18,
    backgroundColor: '#D1D5DB',
  },
});
```

## Step 6: Empty State

Create `components/EmptyState.tsx`:

```tsx
import { View, Text, StyleSheet } from 'react-native';
import Animated, { FadeIn, SlideInUp } from 'react-native-reanimated';
import { Ionicons } from '@expo/vector-icons';

type Props = {
  icon?: string;
  title: string;
  subtitle?: string;
};

export function EmptyState({ icon = 'sunny', title, subtitle }: Props) {
  return (
    <Animated.View
      entering={FadeIn.delay(200)}
      style={styles.container}
    >
      <Animated.View entering={SlideInUp.delay(300)}>
        <Ionicons name={icon as any} size={64} color="#D1D5DB" />
      </Animated.View>
      <Text style={styles.title}>{title}</Text>
      {subtitle && <Text style={styles.subtitle}>{subtitle}</Text>}
    </Animated.View>
  );
}

const styles = StyleSheet.create({
  container: {
    alignItems: 'center',
    paddingVertical: 60,
    paddingHorizontal: 24,
  },
  title: {
    fontSize: 18,
    fontWeight: '600',
    color: '#6B7280',
    marginTop: 16,
    textAlign: 'center',
  },
  subtitle: {
    fontSize: 14,
    color: '#9CA3AF',
    marginTop: 8,
    textAlign: 'center',
  },
});
```

## Step 7: Streak Badge

Create `components/StreakBadge.tsx`:

```tsx
import { View, Text, StyleSheet } from 'react-native';
import Animated, {
  useAnimatedStyle,
  withSpring,
  withSequence,
  useSharedValue,
} from 'react-native-reanimated';
import { Ionicons } from '@expo/vector-icons';
import { useEffect } from 'react';

type Props = {
  count: number;
  label?: string;
};

export function StreakBadge({ count, label = 'day streak' }: Props) {
  const scale = useSharedValue(1);

  useEffect(() => {
    if (count > 0) {
      scale.value = withSequence(
        withSpring(1.2, { damping: 4 }),
        withSpring(1, { damping: 4 })
      );
    }
  }, [count]);

  const animatedStyle = useAnimatedStyle(() => ({
    transform: [{ scale: scale.value }],
  }));

  if (count === 0) {
    return null;
  }

  return (
    <Animated.View style={[styles.container, animatedStyle]}>
      <Ionicons name="flame" size={20} color="#F59E0B" />
      <Text style={styles.count}>{count}</Text>
      <Text style={styles.label}>{label}</Text>
    </Animated.View>
  );
}

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#FEF3C7',
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 20,
    gap: 4,
  },
  count: {
    fontSize: 16,
    fontWeight: '700',
    color: '#D97706',
  },
  label: {
    fontSize: 12,
    color: '#92400E',
  },
});
```

## Step 8: Pull-to-Refresh

Update the Today screen with pull-to-refresh:

```tsx
import { RefreshControl } from 'react-native';
import { useState, useCallback } from 'react';

// Inside TodayScreen component:
const [refreshing, setRefreshing] = useState(false);

const onRefresh = useCallback(async () => {
  setRefreshing(true);
  await Promise.all([refetchHabits(), refetchCompletions()]);
  setRefreshing(false);
}, []);

// In FlatList:
<FlatList
  refreshControl={
    <RefreshControl
      refreshing={refreshing}
      onRefresh={onRefresh}
      tintColor="#3B82F6"
      colors={['#3B82F6']}
    />
  }
  // ... other props
/>
```

## Step 9: Progress Screen with Stats

Update `app/(app)/(tabs)/progress.tsx`:

```tsx
import { View, Text, ScrollView, StyleSheet } from 'react-native';
import { useHabits } from '@/hooks/useHabits';
import { useCompletions } from '@/hooks/useCompletions';
import { calculateStreak } from '@/lib/streaks';
import { StreakBadge } from '@/components/StreakBadge';

export default function ProgressScreen() {
  const { habits } = useHabits();
  const { completions } = useCompletions(
    habits.map((h) => h.id)
  );

  const totalCompletions = completions.length;
  const activeHabits = habits.length;

  return (
    <ScrollView style={styles.container}>
      <View style={styles.statsGrid}>
        <View style={styles.statCard}>
          <Text style={styles.statValue}>{activeHabits}</Text>
          <Text style={styles.statLabel}>Active Habits</Text>
        </View>
        <View style={styles.statCard}>
          <Text style={styles.statValue}>{totalCompletions}</Text>
          <Text style={styles.statLabel}>Total Check-ins</Text>
        </View>
      </View>

      <Text style={styles.sectionTitle}>Habit Streaks</Text>

      {habits.map((habit) => {
        const streak = calculateStreak(habit.id, completions);
        return (
          <View key={habit.id} style={styles.habitRow}>
            <View style={[styles.colorDot, { backgroundColor: habit.color }]} />
            <Text style={styles.habitName}>{habit.name}</Text>
            <View style={styles.streaks}>
              <StreakBadge count={streak.current} />
              {streak.longest > streak.current && (
                <Text style={styles.bestStreak}>
                  Best: {streak.longest}
                </Text>
              )}
            </View>
          </View>
        );
      })}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#F9FAFB',
  },
  statsGrid: {
    flexDirection: 'row',
    padding: 16,
    gap: 12,
  },
  statCard: {
    flex: 1,
    backgroundColor: '#fff',
    borderRadius: 12,
    padding: 20,
    alignItems: 'center',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.05,
    shadowRadius: 2,
    elevation: 1,
  },
  statValue: {
    fontSize: 32,
    fontWeight: 'bold',
    color: '#3B82F6',
  },
  statLabel: {
    fontSize: 12,
    color: '#6B7280',
    marginTop: 4,
  },
  sectionTitle: {
    fontSize: 18,
    fontWeight: '600',
    color: '#1F2937',
    padding: 16,
    paddingBottom: 8,
  },
  habitRow: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#fff',
    padding: 16,
    marginHorizontal: 16,
    marginBottom: 8,
    borderRadius: 12,
  },
  colorDot: {
    width: 12,
    height: 12,
    borderRadius: 6,
    marginRight: 12,
  },
  habitName: {
    flex: 1,
    fontSize: 16,
    color: '#1F2937',
  },
  streaks: {
    alignItems: 'flex-end',
    gap: 4,
  },
  bestStreak: {
    fontSize: 11,
    color: '#9CA3AF',
  },
});
```

## Step 10: Error Boundary

**Critical**: React Native apps without error boundaries crash entirely on any unhandled error. Add an error boundary to gracefully handle errors.

Create `components/ErrorBoundary.tsx`:

```tsx
import React, { Component, ReactNode } from 'react';
import { View, Text, TouchableOpacity, StyleSheet } from 'react-native';
import { Ionicons } from '@expo/vector-icons';

type Props = {
  children: ReactNode;
  fallback?: ReactNode;
};

type State = {
  hasError: boolean;
  error: Error | null;
};

export class ErrorBoundary extends Component<Props, State> {
  constructor(props: Props) {
    super(props);
    this.state = { hasError: false, error: null };
  }

  static getDerivedStateFromError(error: Error): State {
    return { hasError: true, error };
  }

  componentDidCatch(error: Error, errorInfo: React.ErrorInfo) {
    // Log error to your error reporting service (e.g., Sentry)
    console.error('ErrorBoundary caught an error:', error, errorInfo);
  }

  handleRetry = () => {
    this.setState({ hasError: false, error: null });
  };

  render() {
    if (this.state.hasError) {
      if (this.props.fallback) {
        return this.props.fallback;
      }

      return (
        <View style={styles.container}>
          <Ionicons name="warning-outline" size={64} color="#EF4444" />
          <Text style={styles.title}>Something went wrong</Text>
          <Text style={styles.message}>
            {this.state.error?.message || 'An unexpected error occurred'}
          </Text>
          <TouchableOpacity style={styles.button} onPress={this.handleRetry}>
            <Text style={styles.buttonText}>Try Again</Text>
          </TouchableOpacity>
        </View>
      );
    }

    return this.props.children;
  }
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 24,
    backgroundColor: '#fff',
  },
  title: {
    fontSize: 20,
    fontWeight: '600',
    color: '#1F2937',
    marginTop: 16,
  },
  message: {
    fontSize: 14,
    color: '#6B7280',
    textAlign: 'center',
    marginTop: 8,
    marginBottom: 24,
  },
  button: {
    backgroundColor: '#3B82F6',
    paddingHorizontal: 24,
    paddingVertical: 12,
    borderRadius: 8,
  },
  buttonText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '600',
  },
});
```

Update your root layout `app/_layout.tsx` to wrap the app:

```tsx
import { ErrorBoundary } from '@/components/ErrorBoundary';

export default function RootLayout() {
  return (
    <ErrorBoundary>
      <AuthProvider>
        <Stack>
          {/* ... your screens */}
        </Stack>
      </AuthProvider>
    </ErrorBoundary>
  );
}
```

You can also wrap individual screens or components:

```tsx
// Wrap a specific screen that might error
<ErrorBoundary fallback={<Text>Failed to load habits</Text>}>
  <HabitsList />
</ErrorBoundary>
```

---

## Checkpoint

Before moving on, verify:

- [ ] Error boundary catches and displays errors gracefully
- [ ] Check animations play smoothly
- [ ] Haptic feedback works on mobile
- [ ] Loading skeleton appears while fetching
- [ ] Pull-to-refresh works
- [ ] Progress screen shows streaks
- [ ] App feels responsive and polished
- [ ] VoiceOver/TalkBack correctly reads habit names and states
- [ ] All interactive elements have appropriate accessibility labels

---

## Design Tips

1. **Consistent spacing**: Use multiples of 4 (4, 8, 12, 16, 24, 32)
2. **Color palette**: Stick to your brand colors + grays
3. **Typography**: 2-3 font sizes max, use weight for hierarchy
4. **Shadows**: Subtle, consistent elevation
5. **Touch targets**: Minimum 44x44 points

---

## Next Steps

Continue to [05-app-store-submission.md](./05-app-store-submission.md) to prepare and submit your app.
