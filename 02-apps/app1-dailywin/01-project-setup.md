# 01 - Project Setup

> Day 1-2: Create your Expo project with navigation structure

## Prerequisites

Before starting, ensure you have:
- [ ] Node.js 18+ installed
- [ ] Git configured
- [ ] Expo CLI: `npm install -g expo-cli`
- [ ] EAS CLI: `npm install -g eas-cli`
- [ ] Accounts created (see [accounts-checklist.md](../../00-setup/accounts-checklist.md))

---

## Step 1: Create the Expo Project

```bash
# Create new project with expo-router template
npx create-expo-app dailywin -t tabs

# Navigate to project
cd dailywin

# Install additional dependencies
npx expo install @supabase/supabase-js react-native-url-polyfill
npx expo install expo-secure-store expo-linking
npx expo install react-native-reanimated react-native-gesture-handler
```

## Step 2: Project Structure

Create the folder structure for your app:

```bash
mkdir -p contexts hooks lib types
```

Your project should look like:

```
dailywin/
├── app/
│   ├── _layout.tsx
│   ├── (auth)/
│   │   ├── _layout.tsx
│   │   ├── login.tsx
│   │   ├── signup.tsx
│   │   └── forgot-password.tsx
│   └── (app)/
│       ├── _layout.tsx
│       ├── (tabs)/
│       │   ├── _layout.tsx
│       │   ├── index.tsx
│       │   ├── progress.tsx
│       │   └── settings.tsx
│       ├── habit/
│       │   ├── new.tsx
│       │   └── [id].tsx
│       └── paywall.tsx
├── components/
├── contexts/
├── hooks/
├── lib/
├── types/
└── assets/
```

## Step 3: Configure app.json

Update your `app.json`:

```json
{
  "expo": {
    "name": "DailyWin",
    "slug": "dailywin",
    "version": "1.0.0",
    "orientation": "portrait",
    "icon": "./assets/icon.png",
    "scheme": "dailywin",
    "userInterfaceStyle": "automatic",
    "splash": {
      "image": "./assets/splash.png",
      "resizeMode": "contain",
      "backgroundColor": "#3B82F6"
    },
    "ios": {
      "supportsTablet": true,
      "bundleIdentifier": "com.yourcompany.dailywin"
    },
    "android": {
      "adaptiveIcon": {
        "foregroundImage": "./assets/adaptive-icon.png",
        "backgroundColor": "#3B82F6"
      },
      "package": "com.yourcompany.dailywin"
    },
    "web": {
      "bundler": "metro",
      "output": "static",
      "favicon": "./assets/favicon.png"
    },
    "plugins": [
      "expo-router",
      "expo-secure-store"
    ],
    "experiments": {
      "typedRoutes": true
    }
  }
}
```

## Step 4: Root Layout

Create the root layout in `app/_layout.tsx`:

```tsx
import { Stack } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import { AuthProvider } from '@/contexts/AuthContext';

export default function RootLayout() {
  return (
    <AuthProvider>
      <Stack screenOptions={{ headerShown: false }}>
        <Stack.Screen name="(auth)" />
        <Stack.Screen name="(app)" />
      </Stack>
      <StatusBar style="auto" />
    </AuthProvider>
  );
}
```

## Step 5: Auth Layout

Create `app/(auth)/_layout.tsx`:

```tsx
import { Stack } from 'expo-router';

export default function AuthLayout() {
  return (
    <Stack screenOptions={{ headerShown: false }}>
      <Stack.Screen name="login" />
      <Stack.Screen name="signup" />
      <Stack.Screen name="forgot-password" />
    </Stack>
  );
}
```

## Step 6: App Layout with Tabs

Create `app/(app)/_layout.tsx`:

```tsx
import { Redirect, Stack } from 'expo-router';
import { useAuth } from '@/contexts/AuthContext';

export default function AppLayout() {
  const { user, loading } = useAuth();

  if (loading) {
    return null; // Or loading spinner
  }

  if (!user) {
    return <Redirect href="/(auth)/login" />;
  }

  return (
    <Stack screenOptions={{ headerShown: false }}>
      <Stack.Screen name="(tabs)" />
      <Stack.Screen
        name="habit/new"
        options={{ presentation: 'modal' }}
      />
      <Stack.Screen
        name="habit/[id]"
        options={{ presentation: 'modal' }}
      />
      <Stack.Screen
        name="paywall"
        options={{ presentation: 'modal' }}
      />
    </Stack>
  );
}
```

## Step 7: Tab Navigator

Create `app/(app)/(tabs)/_layout.tsx`:

```tsx
import { Tabs } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';

export default function TabLayout() {
  return (
    <Tabs
      screenOptions={{
        tabBarActiveTintColor: '#3B82F6',
        headerShown: true,
      }}
    >
      <Tabs.Screen
        name="index"
        options={{
          title: 'Today',
          tabBarIcon: ({ color, size }) => (
            <Ionicons name="today" size={size} color={color} />
          ),
        }}
      />
      <Tabs.Screen
        name="progress"
        options={{
          title: 'Progress',
          tabBarIcon: ({ color, size }) => (
            <Ionicons name="stats-chart" size={size} color={color} />
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

## Step 8: Placeholder Screens

Create placeholder content for each screen:

**`app/(auth)/login.tsx`:**
```tsx
import { View, Text } from 'react-native';

export default function LoginScreen() {
  return (
    <View style={{ flex: 1, justifyContent: 'center', alignItems: 'center' }}>
      <Text>Login Screen</Text>
    </View>
  );
}
```

Create similar placeholders for `signup.tsx`, `forgot-password.tsx`, and the tab screens.

## Step 9: Initialize Git and EAS

```bash
# Initialize git (if not already)
git init
git add .
git commit -m "Initial project setup"

# Log in to EAS
eas login

# Initialize EAS for this project
eas build:configure
```

## Step 10: First Test Run

```bash
# Start development server
npx expo start

# Press 'w' for web
# Press 'i' for iOS simulator (Mac only)
# Press 'a' for Android emulator
```

---

## Checkpoint

Before moving on, verify:

- [ ] App runs on web without errors
- [ ] Tab navigation works
- [ ] Project structure matches the file tree above
- [ ] EAS is configured (`eas.json` exists)

---

## Common Issues

### "Cannot find module '@/contexts/AuthContext'"

Create a placeholder `contexts/AuthContext.tsx`:

```tsx
import { createContext, useContext, useState, ReactNode } from 'react';

type AuthContextType = {
  user: null | { id: string };
  loading: boolean;
};

const AuthContext = createContext<AuthContextType>({
  user: null,
  loading: true,
});

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user] = useState<null | { id: string }>(null);
  const [loading] = useState(false);

  return (
    <AuthContext.Provider value={{ user, loading }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  return useContext(AuthContext);
}
```

### Metro bundler issues

```bash
# Clear cache and restart
npx expo start --clear
```

---

## Next Steps

Continue to [02-authentication.md](./02-authentication.md) to set up Supabase Auth.
