# Supabase Essentials

Your backend in a box: PostgreSQL database, authentication, file storage, and serverless functions.

## Project Setup

### Create a Project

1. Go to https://supabase.com/dashboard
2. Click "New Project"
3. Choose organization (or create one)
4. Enter project details:
   - **Name**: Your app name (e.g., "dailywin")
   - **Database Password**: Save this securely
   - **Region**: Choose closest to your users

Project takes ~2 minutes to provision.

### Get Your Keys

Once ready, go to **Settings → API**:

```
Project URL: https://xxxxx.supabase.co
anon (public) key: eyJhbGciOiJIUzI1NiIs...
service_role key: eyJhbGciOiJIUzI1NiIs...  # Keep secret!
```

- **anon key**: Safe for client-side, limited by Row Level Security
- **service_role key**: Bypasses RLS, never expose to client

---

## Client Setup in Expo

```bash
npx expo install @supabase/supabase-js
```

Create `lib/supabase.ts`:

```typescript
import { createClient } from '@supabase/supabase-js';
import * as SecureStore from 'expo-secure-store';

const supabaseUrl = process.env.EXPO_PUBLIC_SUPABASE_URL!;
const supabaseAnonKey = process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY!;

// Custom storage for auth tokens (secure on mobile)
const ExpoSecureStoreAdapter = {
  getItem: (key: string) => SecureStore.getItemAsync(key),
  setItem: (key: string, value: string) => SecureStore.setItemAsync(key, value),
  removeItem: (key: string) => SecureStore.deleteItemAsync(key),
};

export const supabase = createClient(supabaseUrl, supabaseAnonKey, {
  auth: {
    storage: ExpoSecureStoreAdapter,
    autoRefreshToken: true,
    persistSession: true,
    detectSessionInUrl: false,
  },
});
```

---

## Authentication

### Email/Password

```typescript
// Sign up
const { data, error } = await supabase.auth.signUp({
  email: 'user@example.com',
  password: 'password123',
});

// Sign in
const { data, error } = await supabase.auth.signInWithPassword({
  email: 'user@example.com',
  password: 'password123',
});

// Sign out
await supabase.auth.signOut();

// Get current user
const { data: { user } } = await supabase.auth.getUser();

// Listen to auth changes
supabase.auth.onAuthStateChange((event, session) => {
  if (event === 'SIGNED_IN') {
    console.log('User signed in:', session?.user);
  } else if (event === 'SIGNED_OUT') {
    console.log('User signed out');
  }
});
```

### OAuth (Google, Apple)

```typescript
// In Supabase Dashboard: Authentication → Providers → Enable Google/Apple

import * as AuthSession from 'expo-auth-session';
import * as WebBrowser from 'expo-web-browser';

WebBrowser.maybeCompleteAuthSession();

const signInWithGoogle = async () => {
  const { data, error } = await supabase.auth.signInWithOAuth({
    provider: 'google',
    options: {
      redirectTo: AuthSession.makeRedirectUri(),
    },
  });
  
  if (data?.url) {
    const result = await WebBrowser.openAuthSessionAsync(
      data.url,
      AuthSession.makeRedirectUri()
    );
    // Handle result...
  }
};
```

### Auth Context Pattern

Create `contexts/AuthContext.tsx`:

```tsx
import { createContext, useContext, useEffect, useState } from 'react';
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

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [session, setSession] = useState<Session | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    // Get initial session
    supabase.auth.getSession().then(({ data: { session } }) => {
      setSession(session);
      setUser(session?.user ?? null);
      setLoading(false);
    });

    // Listen for changes
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

## Database Operations

### Creating Tables

Use the SQL Editor in Supabase Dashboard:

```sql
-- Example: Habits table
create table habits (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users(id) on delete cascade not null,
  name text not null,
  color text default '#3B82F6',
  created_at timestamptz default now()
);

-- Enable Row Level Security
alter table habits enable row level security;

-- Policy: Users can only see their own habits
create policy "Users can view own habits"
  on habits for select
  using (auth.uid() = user_id);

-- Policy: Users can insert their own habits
create policy "Users can insert own habits"
  on habits for insert
  with check (auth.uid() = user_id);

-- Policy: Users can update their own habits
create policy "Users can update own habits"
  on habits for update
  using (auth.uid() = user_id);

-- Policy: Users can delete their own habits
create policy "Users can delete own habits"
  on habits for delete
  using (auth.uid() = user_id);
```

### CRUD Operations

```typescript
// CREATE
const { data, error } = await supabase
  .from('habits')
  .insert({ name: 'Exercise', color: '#10B981' })
  .select()
  .single();

// READ (all)
const { data, error } = await supabase
  .from('habits')
  .select('*')
  .order('created_at', { ascending: false });

// READ (single)
const { data, error } = await supabase
  .from('habits')
  .select('*')
  .eq('id', habitId)
  .single();

// UPDATE
const { data, error } = await supabase
  .from('habits')
  .update({ name: 'Morning Exercise' })
  .eq('id', habitId)
  .select()
  .single();

// DELETE
const { error } = await supabase
  .from('habits')
  .delete()
  .eq('id', habitId);
```

### Querying with Filters

```typescript
// Multiple conditions
const { data } = await supabase
  .from('habits')
  .select('*')
  .eq('user_id', userId)
  .gte('created_at', startDate)
  .order('name');

// Related data (joins)
const { data } = await supabase
  .from('habits')
  .select(`
    *,
    completions (
      id,
      completed_at
    )
  `);

// Count
const { count } = await supabase
  .from('habits')
  .select('*', { count: 'exact', head: true });
```

---

## Row Level Security (RLS)

RLS is Supabase's security model. It filters data at the database level.

**Always enable RLS on tables with user data.**

```sql
-- Enable RLS
alter table my_table enable row level security;

-- Common patterns:

-- 1. User owns row
create policy "Users own their data"
  on my_table for all
  using (auth.uid() = user_id);

-- 2. Public read, authenticated write
create policy "Anyone can read"
  on my_table for select
  using (true);

create policy "Authenticated users can insert"
  on my_table for insert
  with check (auth.role() = 'authenticated');

-- 3. Check via related table
create policy "Team members can access"
  on projects for select
  using (
    exists (
      select 1 from team_members
      where team_members.project_id = projects.id
      and team_members.user_id = auth.uid()
    )
  );
```

---

## File Storage

### Create a Bucket

In Dashboard: **Storage → Create bucket**

```sql
-- Or via SQL
insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true);
```

### Upload Files

```typescript
// Upload file
const { data, error } = await supabase.storage
  .from('avatars')
  .upload(`${userId}/avatar.png`, file, {
    cacheControl: '3600',
    upsert: true,
  });

// Get public URL (for public buckets)
const { data } = supabase.storage
  .from('avatars')
  .getPublicUrl(`${userId}/avatar.png`);

// Get signed URL (for private buckets)
const { data, error } = await supabase.storage
  .from('private-files')
  .createSignedUrl('path/to/file.pdf', 3600); // expires in 1 hour
```

### Storage RLS Policies

```sql
-- Users can upload to their own folder
create policy "Users can upload own avatar"
  on storage.objects for insert
  with check (
    bucket_id = 'avatars' and
    auth.uid()::text = (storage.foldername(name))[1]
  );

-- Users can read their own files
create policy "Users can read own files"
  on storage.objects for select
  using (
    bucket_id = 'private-files' and
    auth.uid()::text = (storage.foldername(name))[1]
  );
```

---

## Edge Functions

Serverless functions that run close to your users.

### Create a Function

```bash
# Install Supabase CLI
npm install -g supabase

# Login
supabase login

# Link to your project
supabase link --project-ref your-project-ref

# Create function
supabase functions new my-function
```

### Function Code

`supabase/functions/my-function/index.ts`:

```typescript
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

serve(async (req) => {
  try {
    // Get auth header
    const authHeader = req.headers.get('Authorization');
    
    // Create Supabase client with user's token
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader! } } }
    );
    
    // Get user
    const { data: { user }, error: userError } = await supabase.auth.getUser();
    if (userError) throw userError;
    
    // Parse request body
    const { message } = await req.json();
    
    // Do something...
    const result = { echo: message, userId: user?.id };
    
    return new Response(JSON.stringify(result), {
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 400,
      headers: { 'Content-Type': 'application/json' },
    });
  }
});
```

### Deploy

```bash
supabase functions deploy my-function
```

### Call from Client

```typescript
const { data, error } = await supabase.functions.invoke('my-function', {
  body: { message: 'Hello!' },
});
```

---

## Realtime Subscriptions

Listen to database changes in real-time:

```typescript
// Subscribe to changes
const subscription = supabase
  .channel('habits-changes')
  .on(
    'postgres_changes',
    {
      event: '*', // or 'INSERT', 'UPDATE', 'DELETE'
      schema: 'public',
      table: 'habits',
      filter: `user_id=eq.${userId}`,
    },
    (payload) => {
      console.log('Change received:', payload);
      // Update local state
    }
  )
  .subscribe();

// Unsubscribe when done
subscription.unsubscribe();
```

---

## Type Generation

Generate TypeScript types from your database schema:

```bash
supabase gen types typescript --project-id your-project-ref > types/supabase.ts
```

Then use in client:

```typescript
import { Database } from '@/types/supabase';

const supabase = createClient<Database>(supabaseUrl, supabaseAnonKey);

// Now you get full type inference
const { data } = await supabase.from('habits').select('*');
// data is properly typed as Habit[]
```

---

## Common Patterns

### Upsert (Insert or Update)

```typescript
const { data, error } = await supabase
  .from('user_settings')
  .upsert({ user_id: userId, theme: 'dark' })
  .select()
  .single();
```

### Transactions (via RPC)

```sql
-- Create a function in SQL Editor
create or replace function complete_habit_and_update_streak(
  p_habit_id uuid,
  p_completed_at timestamptz
) returns void as $$
begin
  -- Insert completion
  insert into completions (habit_id, completed_at)
  values (p_habit_id, p_completed_at);
  
  -- Update streak
  update habits
  set current_streak = current_streak + 1
  where id = p_habit_id;
end;
$$ language plpgsql;
```

```typescript
// Call from client
const { error } = await supabase.rpc('complete_habit_and_update_streak', {
  p_habit_id: habitId,
  p_completed_at: new Date().toISOString(),
});
```

### Soft Deletes

```sql
-- Add deleted_at column
alter table habits add column deleted_at timestamptz;

-- Update RLS to filter deleted
create policy "Users see non-deleted habits"
  on habits for select
  using (auth.uid() = user_id and deleted_at is null);
```

---

## Next Steps

1. Create a Supabase project for your first app
2. Set up authentication
3. Design your database schema
4. Read [navigation-patterns.md](./navigation-patterns.md) for app structure
