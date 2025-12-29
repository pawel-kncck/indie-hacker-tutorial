# Code Snippets

Copy-paste patterns for common tasks in Expo + Supabase apps.

---

## Authentication

### Supabase Client Setup

```typescript
// lib/supabase.ts
import 'react-native-url-polyfill/auto';
import { createClient } from '@supabase/supabase-js';
import * as SecureStore from 'expo-secure-store';
import { Platform } from 'react-native';

const ExpoSecureStoreAdapter = {
  getItem: (key: string) => {
    if (Platform.OS === 'web') {
      return localStorage.getItem(key);
    }
    return SecureStore.getItemAsync(key);
  },
  setItem: (key: string, value: string) => {
    if (Platform.OS === 'web') {
      localStorage.setItem(key, value);
      return;
    }
    SecureStore.setItemAsync(key, value);
  },
  removeItem: (key: string) => {
    if (Platform.OS === 'web') {
      localStorage.removeItem(key);
      return;
    }
    SecureStore.deleteItemAsync(key);
  },
};

export const supabase = createClient(
  process.env.EXPO_PUBLIC_SUPABASE_URL!,
  process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY!,
  {
    auth: {
      storage: ExpoSecureStoreAdapter,
      autoRefreshToken: true,
      persistSession: true,
      detectSessionInUrl: false,
    },
  }
);
```

### Auth Context

```typescript
// contexts/AuthContext.tsx
import { createContext, useContext, useEffect, useState, ReactNode } from 'react';
import { Session, User } from '@supabase/supabase-js';
import { supabase } from '@/lib/supabase';

type AuthContextType = {
  user: User | null;
  session: Session | null;
  loading: boolean;
};

const AuthContext = createContext<AuthContextType>({
  user: null,
  session: null,
  loading: true,
});

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [session, setSession] = useState<Session | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    supabase.auth.getSession().then(({ data: { session } }) => {
      setSession(session);
      setUser(session?.user ?? null);
      setLoading(false);
    });

    const { data: { subscription } } = supabase.auth.onAuthStateChange(
      (_event, session) => {
        setSession(session);
        setUser(session?.user ?? null);
      }
    );

    return () => subscription.unsubscribe();
  }, []);

  return (
    <AuthContext.Provider value={{ user, session, loading }}>
      {children}
    </AuthContext.Provider>
  );
}

export const useAuth = () => useContext(AuthContext);
```

---

## Data Fetching

### Basic CRUD Hook

```typescript
// hooks/useItems.ts
import { useState, useEffect, useCallback } from 'react';
import { supabase } from '@/lib/supabase';
import { useAuth } from '@/contexts/AuthContext';

type Item = {
  id: string;
  name: string;
  created_at: string;
};

export function useItems() {
  const { user } = useAuth();
  const [items, setItems] = useState<Item[]>([]);
  const [loading, setLoading] = useState(true);

  const fetchItems = useCallback(async () => {
    if (!user) return;

    const { data, error } = await supabase
      .from('items')
      .select('*')
      .eq('user_id', user.id)
      .order('created_at', { ascending: false });

    if (!error) setItems(data || []);
    setLoading(false);
  }, [user]);

  useEffect(() => {
    fetchItems();
  }, [fetchItems]);

  const createItem = async (name: string) => {
    if (!user) throw new Error('Not authenticated');

    const { data, error } = await supabase
      .from('items')
      .insert({ user_id: user.id, name })
      .select()
      .single();

    if (error) throw error;
    setItems((prev) => [data, ...prev]);
    return data;
  };

  const updateItem = async (id: string, name: string) => {
    const { data, error } = await supabase
      .from('items')
      .update({ name })
      .eq('id', id)
      .select()
      .single();

    if (error) throw error;
    setItems((prev) => prev.map((item) => (item.id === id ? data : item)));
    return data;
  };

  const deleteItem = async (id: string) => {
    const { error } = await supabase.from('items').delete().eq('id', id);
    if (error) throw error;
    setItems((prev) => prev.filter((item) => item.id !== id));
  };

  return { items, loading, createItem, updateItem, deleteItem, refetch: fetchItems };
}
```

### Real-time Subscription

```typescript
useEffect(() => {
  if (!user) return;

  const channel = supabase
    .channel('items_changes')
    .on(
      'postgres_changes',
      {
        event: '*',
        schema: 'public',
        table: 'items',
        filter: `user_id=eq.${user.id}`,
      },
      (payload) => {
        if (payload.eventType === 'INSERT') {
          setItems((prev) => [payload.new as Item, ...prev]);
        } else if (payload.eventType === 'UPDATE') {
          setItems((prev) =>
            prev.map((item) => (item.id === payload.new.id ? payload.new as Item : item))
          );
        } else if (payload.eventType === 'DELETE') {
          setItems((prev) => prev.filter((item) => item.id !== payload.old.id));
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

## File Upload

### Upload to Supabase Storage

```typescript
import * as FileSystem from 'expo-file-system';
import { decode } from 'base64-arraybuffer';

async function uploadFile(localUri: string, bucket: string, path: string) {
  // Read file as base64
  const base64 = await FileSystem.readAsStringAsync(localUri, {
    encoding: FileSystem.EncodingType.Base64,
  });

  // Convert to ArrayBuffer
  const arrayBuffer = decode(base64);

  // Upload to Supabase
  const { data, error } = await supabase.storage
    .from(bucket)
    .upload(path, arrayBuffer, {
      contentType: 'image/jpeg', // Adjust based on file type
      upsert: true,
    });

  if (error) throw error;

  // Get public URL
  const { data: { publicUrl } } = supabase.storage
    .from(bucket)
    .getPublicUrl(path);

  return publicUrl;
}
```

### Image Picker

```typescript
import * as ImagePicker from 'expo-image-picker';

async function pickImage() {
  const result = await ImagePicker.launchImageLibraryAsync({
    mediaTypes: ImagePicker.MediaTypeOptions.Images,
    allowsEditing: true,
    aspect: [1, 1],
    quality: 0.8,
  });

  if (!result.canceled) {
    return result.assets[0].uri;
  }
  return null;
}
```

---

## Navigation

### Protected Route Layout

```typescript
// app/(app)/_layout.tsx
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

  return <Stack />;
}
```

### Tab Navigator

```typescript
// app/(app)/(tabs)/_layout.tsx
import { Tabs } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';

export default function TabLayout() {
  return (
    <Tabs screenOptions={{ tabBarActiveTintColor: '#3B82F6' }}>
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

---

## UI Components

### Loading Button

```typescript
import { TouchableOpacity, Text, ActivityIndicator, StyleSheet } from 'react-native';

type Props = {
  title: string;
  loading?: boolean;
  onPress: () => void;
  disabled?: boolean;
};

export function Button({ title, loading, onPress, disabled }: Props) {
  return (
    <TouchableOpacity
      style={[styles.button, (loading || disabled) && styles.disabled]}
      onPress={onPress}
      disabled={loading || disabled}
    >
      {loading ? (
        <ActivityIndicator color="#fff" />
      ) : (
        <Text style={styles.text}>{title}</Text>
      )}
    </TouchableOpacity>
  );
}

const styles = StyleSheet.create({
  button: {
    backgroundColor: '#3B82F6',
    paddingVertical: 16,
    paddingHorizontal: 24,
    borderRadius: 8,
    alignItems: 'center',
  },
  disabled: {
    opacity: 0.6,
  },
  text: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '600',
  },
});
```

### Pull to Refresh List

```typescript
import { FlatList, RefreshControl } from 'react-native';
import { useState, useCallback } from 'react';

function ItemList() {
  const { items, refetch } = useItems();
  const [refreshing, setRefreshing] = useState(false);

  const onRefresh = useCallback(async () => {
    setRefreshing(true);
    await refetch();
    setRefreshing(false);
  }, [refetch]);

  return (
    <FlatList
      data={items}
      renderItem={({ item }) => <ItemRow item={item} />}
      keyExtractor={(item) => item.id}
      refreshControl={
        <RefreshControl
          refreshing={refreshing}
          onRefresh={onRefresh}
          tintColor="#3B82F6"
        />
      }
    />
  );
}
```

---

## Animations

### Animated Scale on Press

```typescript
import Animated, {
  useAnimatedStyle,
  useSharedValue,
  withSpring,
} from 'react-native-reanimated';

function AnimatedButton({ onPress, children }) {
  const scale = useSharedValue(1);

  const animatedStyle = useAnimatedStyle(() => ({
    transform: [{ scale: scale.value }],
  }));

  const handlePressIn = () => {
    scale.value = withSpring(0.95);
  };

  const handlePressOut = () => {
    scale.value = withSpring(1);
  };

  return (
    <TouchableOpacity
      onPress={onPress}
      onPressIn={handlePressIn}
      onPressOut={handlePressOut}
      activeOpacity={1}
    >
      <Animated.View style={animatedStyle}>{children}</Animated.View>
    </TouchableOpacity>
  );
}
```

### Skeleton Loading

```typescript
import Animated, {
  useAnimatedStyle,
  useSharedValue,
  withRepeat,
  withTiming,
} from 'react-native-reanimated';
import { useEffect } from 'react';

function Skeleton({ width, height }) {
  const opacity = useSharedValue(0.3);

  useEffect(() => {
    opacity.value = withRepeat(withTiming(0.7, { duration: 1000 }), -1, true);
  }, []);

  const animatedStyle = useAnimatedStyle(() => ({
    opacity: opacity.value,
  }));

  return (
    <Animated.View
      style={[
        { width, height, backgroundColor: '#E5E7EB', borderRadius: 4 },
        animatedStyle,
      ]}
    />
  );
}
```

---

## Edge Functions

### Basic Edge Function

```typescript
// supabase/functions/hello/index.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { name } = await req.json();

    return new Response(
      JSON.stringify({ message: `Hello, ${name}!` }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
```

### Call Edge Function from Client

```typescript
const { data, error } = await supabase.functions.invoke('hello', {
  body: { name: 'World' },
});

if (error) throw error;
console.log(data.message); // "Hello, World!"
```

---

## Utilities

### Format Date

```typescript
export function formatDate(dateString: string): string {
  const date = new Date(dateString);
  return date.toLocaleDateString('en-US', {
    month: 'short',
    day: 'numeric',
    year: 'numeric',
  });
}
```

### Format Duration

```typescript
export function formatDuration(seconds: number): string {
  const mins = Math.floor(seconds / 60);
  const secs = seconds % 60;
  return `${mins}:${secs.toString().padStart(2, '0')}`;
}
```

### Debounce

```typescript
export function debounce<T extends (...args: any[]) => any>(
  func: T,
  wait: number
): (...args: Parameters<T>) => void {
  let timeoutId: NodeJS.Timeout;

  return (...args: Parameters<T>) => {
    clearTimeout(timeoutId);
    timeoutId = setTimeout(() => func(...args), wait);
  };
}
```

### Generate UUID

```typescript
export function uuid(): string {
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
    const r = (Math.random() * 16) | 0;
    const v = c === 'x' ? r : (r & 0x3) | 0x8;
    return v.toString(16);
  });
}
```
