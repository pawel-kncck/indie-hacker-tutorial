# Expo Essentials

Core concepts you'll use in every Expo app.

## Creating a New Project

```bash
# Create new project with latest Expo SDK
npx create-expo-app@latest my-app

# Navigate into project
cd my-app

# Start development server
npx expo start
```

**Options when starting**:
- Press `w` - Open in web browser
- Press `i` - Open in iOS simulator (macOS only)
- Press `a` - Open in Android emulator
- Scan QR - Open in Expo Go on your phone

---

## Project Structure

```
my-app/
├── app/                    # Routes (file-based routing)
│   ├── (tabs)/            # Tab navigator group
│   │   ├── index.tsx      # First tab (home)
│   │   ├── explore.tsx    # Second tab
│   │   └── _layout.tsx    # Tab bar configuration
│   ├── _layout.tsx        # Root layout
│   └── +not-found.tsx     # 404 page
├── assets/                # Images, fonts
├── components/            # Reusable components
├── constants/             # Colors, config values
├── hooks/                 # Custom React hooks
├── app.json              # App configuration
├── package.json          # Dependencies
└── tsconfig.json         # TypeScript config
```

---

## File-Based Routing (Expo Router)

Expo Router uses the file system for navigation. Every file in `app/` becomes a route.

```
app/
├── index.tsx           → /
├── settings.tsx        → /settings
├── profile/
│   ├── index.tsx       → /profile
│   └── [id].tsx        → /profile/123 (dynamic route)
└── (auth)/
    ├── login.tsx       → /login
    └── signup.tsx      → /signup
```

### Special Files

| File | Purpose |
|------|---------|
| `_layout.tsx` | Wrap child routes (navigation, providers) |
| `+not-found.tsx` | 404 page |
| `(folder)/` | Group without affecting URL |
| `[param].tsx` | Dynamic segment |

### Basic Navigation

```tsx
import { Link, router } from 'expo-router';

// Declarative navigation
<Link href="/settings">Go to Settings</Link>

// Imperative navigation
router.push('/settings');
router.replace('/home');  // Replace current screen
router.back();            // Go back
```

---

## Core Components

### View (like div)
```tsx
import { View, StyleSheet } from 'react-native';

<View style={styles.container}>
  {/* children */}
</View>

const styles = StyleSheet.create({
  container: {
    flex: 1,
    padding: 16,
    backgroundColor: '#fff',
  },
});
```

### Text (required for all text)
```tsx
import { Text } from 'react-native';

<Text style={{ fontSize: 18, fontWeight: 'bold' }}>
  Hello World
</Text>
```

### Pressable (touchable areas)
```tsx
import { Pressable, Text } from 'react-native';

<Pressable 
  onPress={() => console.log('pressed')}
  style={({ pressed }) => [
    styles.button,
    pressed && styles.buttonPressed
  ]}
>
  <Text>Press Me</Text>
</Pressable>
```

### TextInput
```tsx
import { TextInput } from 'react-native';
import { useState } from 'react';

const [text, setText] = useState('');

<TextInput
  value={text}
  onChangeText={setText}
  placeholder="Enter text..."
  style={styles.input}
  autoCapitalize="none"
  keyboardType="email-address"  // or "numeric", "phone-pad"
/>
```

### ScrollView vs FlatList
```tsx
// ScrollView: For small, fixed lists
import { ScrollView } from 'react-native';

<ScrollView>
  {items.map(item => <Item key={item.id} {...item} />)}
</ScrollView>

// FlatList: For large, dynamic lists (virtualized)
import { FlatList } from 'react-native';

<FlatList
  data={items}
  keyExtractor={(item) => item.id}
  renderItem={({ item }) => <Item {...item} />}
/>
```

### Image
```tsx
import { Image } from 'react-native';

// Local image
<Image source={require('../assets/logo.png')} style={{ width: 100, height: 100 }} />

// Remote image (must specify dimensions)
<Image source={{ uri: 'https://example.com/image.jpg' }} style={{ width: 100, height: 100 }} />
```

---

## Styling

React Native uses a subset of CSS with camelCase names.

```tsx
import { StyleSheet } from 'react-native';

const styles = StyleSheet.create({
  container: {
    flex: 1,
    flexDirection: 'row',      // or 'column' (default)
    justifyContent: 'center',  // main axis
    alignItems: 'center',      // cross axis
    padding: 16,
    gap: 8,                    // spacing between children
  },
  card: {
    backgroundColor: '#fff',
    borderRadius: 12,
    padding: 16,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,              // Android shadow
  },
  text: {
    fontSize: 16,
    fontWeight: '600',
    color: '#333',
  },
});
```

**Key Differences from CSS**:
- No units (numbers are density-independent pixels)
- `flex: 1` means "take available space"
- Default `flexDirection` is `column` (not `row`)
- Use `gap` for spacing (not margins on children)

---

## Handling Safe Areas

Phones have notches, status bars, and home indicators. Use SafeAreaView.

```tsx
import { SafeAreaView } from 'react-native-safe-area-context';

export default function Screen() {
  return (
    <SafeAreaView style={{ flex: 1 }}>
      {/* Your content */}
    </SafeAreaView>
  );
}
```

**In layouts** (usually only root layout needs this):
```tsx
import { SafeAreaProvider } from 'react-native-safe-area-context';

export default function RootLayout() {
  return (
    <SafeAreaProvider>
      <Stack />
    </SafeAreaProvider>
  );
}
```

---

## Environment Variables

```bash
# .env
EXPO_PUBLIC_SUPABASE_URL=https://xxx.supabase.co
EXPO_PUBLIC_SUPABASE_ANON_KEY=eyJhbGci...
```

**Access in code**:
```tsx
const supabaseUrl = process.env.EXPO_PUBLIC_SUPABASE_URL;
```

**Rules**:
- Prefix with `EXPO_PUBLIC_` for client-accessible vars
- Restart dev server after changing `.env`
- Don't commit `.env` to git (add to `.gitignore`)

---

## App Configuration (app.json)

```json
{
  "expo": {
    "name": "DailyWin",
    "slug": "dailywin",
    "version": "1.0.0",
    "orientation": "portrait",
    "icon": "./assets/icon.png",
    "splash": {
      "image": "./assets/splash.png",
      "resizeMode": "contain",
      "backgroundColor": "#ffffff"
    },
    "ios": {
      "bundleIdentifier": "com.yourstudio.dailywin",
      "supportsTablet": true
    },
    "android": {
      "package": "com.yourstudio.dailywin",
      "adaptiveIcon": {
        "foregroundImage": "./assets/adaptive-icon.png",
        "backgroundColor": "#ffffff"
      }
    },
    "web": {
      "favicon": "./assets/favicon.png"
    }
  }
}
```

**Key Fields**:
- `slug`: URL-friendly name, used in expo.dev URLs
- `bundleIdentifier` / `package`: Unique app ID for stores (can't change after publishing)
- `version`: User-facing version string

---

## Useful Expo SDK Packages

Pre-built solutions for common needs:

```bash
# Install with
npx expo install <package-name>
```

| Package | Use For |
|---------|---------|
| `expo-secure-store` | Encrypted key-value storage |
| `expo-image-picker` | Camera and photo library |
| `expo-notifications` | Push notifications |
| `expo-av` | Audio/video recording and playback |
| `expo-file-system` | Read/write files |
| `expo-haptics` | Vibration feedback |
| `expo-clipboard` | Copy/paste |
| `expo-linking` | Deep links and URL handling |
| `expo-splash-screen` | Control splash screen |

Always use `npx expo install` instead of `npm install` for Expo packages - it picks compatible versions.

---

## Development Workflow

1. **Make changes** - Edit files, hot reload updates automatically
2. **Test on device** - Use Expo Go or development build
3. **Debug** - Shake device → "Debug Remote JS" or use React DevTools
4. **Commit** - Git commit your changes
5. **Push** - Vercel auto-deploys web on push

### Development Builds vs Expo Go

| Expo Go | Development Build |
|---------|-------------------|
| Pre-built app with common SDKs | Custom build with your native deps |
| Instant testing | Requires EAS Build |
| Limited to Expo SDK | Full native access |
| Good for learning | Required for production |

Start with Expo Go. Create development builds when you need native modules not in Expo Go.

```bash
# Create development build
eas build --profile development --platform all
```

---

## Platform-Specific Code

When you need different behavior per platform:

```tsx
import { Platform } from 'react-native';

// Check platform
if (Platform.OS === 'ios') {
  // iOS-specific code
}

// Platform-specific styles
const styles = StyleSheet.create({
  container: {
    paddingTop: Platform.OS === 'android' ? 25 : 0,
  },
});

// Platform select (cleaner for values)
const iconSize = Platform.select({
  ios: 24,
  android: 26,
  web: 22,
  default: 24,
});
```

---

## Common Patterns

### Loading States
```tsx
const [loading, setLoading] = useState(true);

if (loading) {
  return <ActivityIndicator size="large" />;
}
```

### Error Handling
```tsx
const [error, setError] = useState<string | null>(null);

if (error) {
  return <Text style={styles.error}>{error}</Text>;
}
```

### Pull to Refresh
```tsx
<FlatList
  data={items}
  refreshing={refreshing}
  onRefresh={() => {
    setRefreshing(true);
    fetchData().then(() => setRefreshing(false));
  }}
  renderItem={...}
/>
```

---

## Next Steps

1. Create your first project and explore the file structure
2. Modify the default tabs to understand routing
3. Read [supabase-essentials.md](./supabase-essentials.md) for backend setup
