# Navigation Patterns

Common navigation setups for mobile apps using Expo Router.

## Authentication Flow

Most apps need: unauthenticated screens (login, signup) and authenticated screens (main app).

### File Structure

```
app/
├── _layout.tsx          # Root - auth provider, routing logic
├── (auth)/
│   ├── _layout.tsx      # Auth group layout
│   ├── login.tsx
│   ├── signup.tsx
│   └── forgot-password.tsx
├── (app)/
│   ├── _layout.tsx      # Main app layout (tabs)
│   ├── (tabs)/
│   │   ├── _layout.tsx  # Tab bar config
│   │   ├── index.tsx    # Home tab
│   │   ├── settings.tsx # Settings tab
│   │   └── profile.tsx  # Profile tab
│   └── habit/
│       └── [id].tsx     # Detail screen (modal or push)
└── +not-found.tsx
```

### Root Layout with Auth Routing

`app/_layout.tsx`:

```tsx
import { useEffect } from 'react';
import { Stack, useRouter, useSegments } from 'expo-router';
import { AuthProvider, useAuth } from '@/contexts/AuthContext';

function RootLayoutNav() {
  const { user, loading } = useAuth();
  const segments = useSegments();
  const router = useRouter();

  useEffect(() => {
    if (loading) return;

    const inAuthGroup = segments[0] === '(auth)';

    if (!user && !inAuthGroup) {
      // Not signed in, redirect to login
      router.replace('/login');
    } else if (user && inAuthGroup) {
      // Signed in, redirect to main app
      router.replace('/');
    }
  }, [user, loading, segments]);

  if (loading) {
    return null; // Or a loading screen
  }

  return (
    <Stack screenOptions={{ headerShown: false }}>
      <Stack.Screen name="(auth)" />
      <Stack.Screen name="(app)" />
    </Stack>
  );
}

export default function RootLayout() {
  return (
    <AuthProvider>
      <RootLayoutNav />
    </AuthProvider>
  );
}
```

### Auth Group Layout

`app/(auth)/_layout.tsx`:

```tsx
import { Stack } from 'expo-router';

export default function AuthLayout() {
  return (
    <Stack
      screenOptions={{
        headerShown: true,
        headerBackTitle: 'Back',
      }}
    >
      <Stack.Screen 
        name="login" 
        options={{ title: 'Log In', headerShown: false }} 
      />
      <Stack.Screen 
        name="signup" 
        options={{ title: 'Create Account' }} 
      />
      <Stack.Screen 
        name="forgot-password" 
        options={{ title: 'Reset Password' }} 
      />
    </Stack>
  );
}
```

---

## Tab Navigation

The most common pattern for mobile apps.

### Tab Layout

`app/(app)/(tabs)/_layout.tsx`:

```tsx
import { Tabs } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';

export default function TabLayout() {
  return (
    <Tabs
      screenOptions={{
        tabBarActiveTintColor: '#3B82F6',
        tabBarInactiveTintColor: '#9CA3AF',
        headerShown: true,
      }}
    >
      <Tabs.Screen
        name="index"
        options={{
          title: 'Home',
          tabBarIcon: ({ color, size }) => (
            <Ionicons name="home" size={size} color={color} />
          ),
        }}
      />
      <Tabs.Screen
        name="profile"
        options={{
          title: 'Profile',
          tabBarIcon: ({ color, size }) => (
            <Ionicons name="person" size={size} color={color} />
          ),
        }}
      />
      <Tabs.Screen
        name="settings"
        options={{
          title: 'Settings',
          tabBarIcon: ({ color, size }) => (
            <Ionicons name="settings" size={size} color={color} />
          ),
        }}
      />
    </Tabs>
  );
}
```

### Custom Tab Bar

For more control over appearance:

```tsx
import { Tabs } from 'expo-router';
import { View, Pressable, Text, StyleSheet } from 'react-native';

function CustomTabBar({ state, descriptors, navigation }) {
  return (
    <View style={styles.tabBar}>
      {state.routes.map((route, index) => {
        const { options } = descriptors[route.key];
        const isFocused = state.index === index;

        const onPress = () => {
          const event = navigation.emit({
            type: 'tabPress',
            target: route.key,
          });
          if (!isFocused && !event.defaultPrevented) {
            navigation.navigate(route.name);
          }
        };

        return (
          <Pressable
            key={route.key}
            onPress={onPress}
            style={styles.tabItem}
          >
            {options.tabBarIcon?.({ 
              color: isFocused ? '#3B82F6' : '#9CA3AF', 
              size: 24 
            })}
            <Text style={[
              styles.tabLabel,
              { color: isFocused ? '#3B82F6' : '#9CA3AF' }
            ]}>
              {options.title}
            </Text>
          </Pressable>
        );
      })}
    </View>
  );
}

export default function TabLayout() {
  return (
    <Tabs tabBar={(props) => <CustomTabBar {...props} />}>
      {/* ... screens */}
    </Tabs>
  );
}

const styles = StyleSheet.create({
  tabBar: {
    flexDirection: 'row',
    backgroundColor: '#fff',
    borderTopWidth: 1,
    borderTopColor: '#E5E7EB',
    paddingBottom: 20, // Safe area
    paddingTop: 10,
  },
  tabItem: {
    flex: 1,
    alignItems: 'center',
  },
  tabLabel: {
    fontSize: 12,
    marginTop: 4,
  },
});
```

---

## Modal Screens

Screens that slide up over the current content.

### Define Modal in Layout

```tsx
// app/(app)/_layout.tsx
import { Stack } from 'expo-router';

export default function AppLayout() {
  return (
    <Stack>
      <Stack.Screen name="(tabs)" options={{ headerShown: false }} />
      <Stack.Screen
        name="habit/[id]"
        options={{
          presentation: 'modal',
          title: 'Habit Details',
        }}
      />
      <Stack.Screen
        name="new-habit"
        options={{
          presentation: 'modal',
          title: 'New Habit',
        }}
      />
    </Stack>
  );
}
```

### Navigate to Modal

```tsx
import { router } from 'expo-router';

// Open modal
router.push('/habit/123');

// Or with Link
<Link href="/habit/123" asChild>
  <Pressable>
    <Text>View Habit</Text>
  </Pressable>
</Link>
```

### Dismiss Modal

```tsx
import { router } from 'expo-router';

// In the modal screen
<Pressable onPress={() => router.back()}>
  <Text>Close</Text>
</Pressable>

// Or dismiss all modals
router.dismissAll();
```

---

## Drawer Navigation

Side menu, often used for settings or secondary navigation.

```bash
npx expo install @react-navigation/drawer react-native-gesture-handler react-native-reanimated
```

```tsx
// app/(app)/_layout.tsx
import { Drawer } from 'expo-router/drawer';
import { GestureHandlerRootView } from 'react-native-gesture-handler';

export default function AppLayout() {
  return (
    <GestureHandlerRootView style={{ flex: 1 }}>
      <Drawer>
        <Drawer.Screen
          name="(tabs)"
          options={{
            drawerLabel: 'Home',
            title: 'Home',
          }}
        />
        <Drawer.Screen
          name="settings"
          options={{
            drawerLabel: 'Settings',
            title: 'Settings',
          }}
        />
      </Drawer>
    </GestureHandlerRootView>
  );
}
```

---

## Passing Data Between Screens

### Via URL Params

```tsx
// Navigate with params
router.push('/habit/123?name=Exercise');

// Access in target screen
import { useLocalSearchParams } from 'expo-router';

export default function HabitScreen() {
  const { id, name } = useLocalSearchParams<{ id: string; name: string }>();
  // id = "123", name = "Exercise"
}
```

### Via State (for complex data)

Use React Context or a state management library for complex data:

```tsx
// contexts/SelectedHabitContext.tsx
const SelectedHabitContext = createContext<Habit | null>(null);

// Set before navigation
setSelectedHabit(habit);
router.push('/habit/details');

// Access in target screen
const habit = useContext(SelectedHabitContext);
```

---

## Deep Linking

Configure which URLs open which screens.

### app.json Configuration

```json
{
  "expo": {
    "scheme": "dailywin",
    "web": {
      "bundler": "metro"
    }
  }
}
```

### URL to Screen Mapping

Expo Router handles this automatically based on file structure:

- `dailywin://` → `/` (index)
- `dailywin:///habit/123` → `/habit/123`
- `https://dailywin.app/habit/123` → `/habit/123` (universal links)

### Handle Incoming Links

```tsx
import { useURL } from 'expo-linking';
import { useEffect } from 'react';

export default function App() {
  const url = useURL();

  useEffect(() => {
    if (url) {
      // Parse and navigate based on URL
      console.log('Opened via URL:', url);
    }
  }, [url]);
}
```

---

## Header Customization

### Per-Screen Headers

```tsx
import { Stack } from 'expo-router';

<Stack.Screen
  name="profile"
  options={{
    title: 'My Profile',
    headerStyle: { backgroundColor: '#3B82F6' },
    headerTintColor: '#fff',
    headerRight: () => (
      <Pressable onPress={handleEdit}>
        <Ionicons name="pencil" size={24} color="#fff" />
      </Pressable>
    ),
  }}
/>
```

### Dynamic Headers

```tsx
// In the screen file
import { useNavigation } from 'expo-router';
import { useLayoutEffect } from 'react';

export default function ProfileScreen() {
  const navigation = useNavigation();

  useLayoutEffect(() => {
    navigation.setOptions({
      title: `${user.name}'s Profile`,
    });
  }, [navigation, user]);
}
```

### Hide Header

```tsx
<Stack.Screen name="fullscreen" options={{ headerShown: false }} />
```

---

## Common Patterns

### Loading Screen While Checking Auth

```tsx
export default function RootLayout() {
  const [isReady, setIsReady] = useState(false);

  useEffect(() => {
    // Check auth, load fonts, etc.
    prepare().then(() => setIsReady(true));
  }, []);

  if (!isReady) {
    return <SplashScreen />;
  }

  return <Stack />;
}
```

### Prevent Going Back

```tsx
<Stack.Screen
  name="checkout"
  options={{
    headerBackVisible: false,
    gestureEnabled: false, // Disable swipe back on iOS
  }}
/>
```

### Navigate After Async Action

```tsx
const handleSubmit = async () => {
  try {
    await saveData();
    router.replace('/success'); // replace prevents going back
  } catch (error) {
    // Handle error
  }
};
```

---

## Next Steps

1. Set up the auth flow for your app
2. Create your tab structure
3. Read [deployment-pipeline.md](./deployment-pipeline.md) to start deploying
