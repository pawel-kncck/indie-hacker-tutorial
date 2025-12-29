# 01 - Google OAuth

> Day 2-3 of Week 6: Implement Google OAuth 2.0 for calendar access

## Overview

We'll implement:
- Google Cloud project setup
- OAuth consent screen
- Authorization flow
- Token storage and refresh
- Secure token handling

---

## Step 1: Create Google Cloud Project

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Create new project: "SyncCal"
3. Enable **Google Calendar API**:
   - Go to APIs & Services → Library
   - Search "Google Calendar API"
   - Click Enable

## Step 2: Configure OAuth Consent Screen

Go to **APIs & Services → OAuth consent screen**:

1. User Type: **External**
2. App information:
   - App name: SyncCal
   - User support email: your email
   - App logo: optional
3. Scopes:
   - `https://www.googleapis.com/auth/calendar.readonly`
   - `https://www.googleapis.com/auth/calendar.events`
4. Test users: Add your email (required during testing)

## Step 3: Create OAuth Credentials

Go to **APIs & Services → Credentials**:

1. Click **Create Credentials → OAuth client ID**
2. Application type: **Web application**
3. Name: "SyncCal Web"
4. Authorized redirect URIs:
   - `https://YOUR_PROJECT.supabase.co/functions/v1/google-callback`
   - `http://localhost:54321/functions/v1/google-callback` (for local dev)
5. Save **Client ID** and **Client Secret**

## Step 4: Store Secrets

```bash
supabase secrets set GOOGLE_CLIENT_ID=xxx.apps.googleusercontent.com
supabase secrets set GOOGLE_CLIENT_SECRET=xxx
supabase secrets set GOOGLE_REDIRECT_URI=https://YOUR_PROJECT.supabase.co/functions/v1/google-callback
```

## Step 5: Create Auth URL Generator

Create `supabase/functions/google-auth-url/index.ts`:

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
    // Verify user is authenticated
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) throw new Error('No authorization header');

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } }
    );

    const { data: { user }, error } = await supabase.auth.getUser();
    if (error || !user) throw new Error('Unauthorized');

    // Generate state token (prevents CSRF)
    const state = crypto.randomUUID();

    // Store state in database for verification
    const adminClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    );

    await adminClient.from('oauth_states').insert({
      state,
      user_id: user.id,
      expires_at: new Date(Date.now() + 10 * 60 * 1000).toISOString(), // 10 min
    });

    // Build OAuth URL
    const params = new URLSearchParams({
      client_id: Deno.env.get('GOOGLE_CLIENT_ID')!,
      redirect_uri: Deno.env.get('GOOGLE_REDIRECT_URI')!,
      response_type: 'code',
      scope: [
        'https://www.googleapis.com/auth/calendar.readonly',
        'https://www.googleapis.com/auth/calendar.events',
      ].join(' '),
      access_type: 'offline', // Get refresh token
      prompt: 'consent', // Always show consent to get refresh token
      state,
    });

    const authUrl = `https://accounts.google.com/o/oauth2/v2/auth?${params}`;

    return new Response(
      JSON.stringify({ url: authUrl }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  }
});
```

## Step 6: Create Callback Handler

Create `supabase/functions/google-callback/index.ts`:

```typescript
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

serve(async (req) => {
  const url = new URL(req.url);
  const code = url.searchParams.get('code');
  const state = url.searchParams.get('state');
  const error = url.searchParams.get('error');

  // Handle errors from Google
  if (error) {
    return redirectWithError('Google authorization failed');
  }

  if (!code || !state) {
    return redirectWithError('Missing authorization code');
  }

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  );

  try {
    // Verify state token
    const { data: stateData, error: stateError } = await supabase
      .from('oauth_states')
      .select('user_id')
      .eq('state', state)
      .gt('expires_at', new Date().toISOString())
      .single();

    if (stateError || !stateData) {
      return redirectWithError('Invalid or expired state');
    }

    // Delete used state
    await supabase.from('oauth_states').delete().eq('state', state);

    // Exchange code for tokens
    const tokenResponse = await fetch('https://oauth2.googleapis.com/token', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        client_id: Deno.env.get('GOOGLE_CLIENT_ID')!,
        client_secret: Deno.env.get('GOOGLE_CLIENT_SECRET')!,
        code,
        grant_type: 'authorization_code',
        redirect_uri: Deno.env.get('GOOGLE_REDIRECT_URI')!,
      }),
    });

    if (!tokenResponse.ok) {
      const errorData = await tokenResponse.text();
      console.error('Token exchange failed:', errorData);
      return redirectWithError('Failed to exchange authorization code');
    }

    const tokens = await tokenResponse.json();

    // Store tokens (encrypted in production)
    await supabase.from('oauth_tokens').upsert({
      user_id: stateData.user_id,
      provider: 'google',
      access_token: tokens.access_token,
      refresh_token: tokens.refresh_token,
      expires_at: new Date(Date.now() + tokens.expires_in * 1000).toISOString(),
      scope: tokens.scope,
    });

    // Trigger initial calendar sync
    await fetch(`${Deno.env.get('SUPABASE_URL')}/functions/v1/sync-calendars`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ userId: stateData.user_id }),
    });

    // Redirect to success page
    return new Response(null, {
      status: 302,
      headers: {
        Location: `${Deno.env.get('APP_URL')}/settings?google=connected`,
      },
    });
  } catch (err) {
    console.error('Callback error:', err);
    return redirectWithError('An unexpected error occurred');
  }
});

function redirectWithError(message: string) {
  const appUrl = Deno.env.get('APP_URL') || 'http://localhost:8081';
  return new Response(null, {
    status: 302,
    headers: {
      Location: `${appUrl}/settings?error=${encodeURIComponent(message)}`,
    },
  });
}
```

## Step 7: Token Refresh Helper

Create `supabase/functions/_shared/google-auth.ts`:

```typescript
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

export async function getValidAccessToken(userId: string): Promise<string> {
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  );

  // Get stored tokens
  const { data: tokenData, error } = await supabase
    .from('oauth_tokens')
    .select('*')
    .eq('user_id', userId)
    .eq('provider', 'google')
    .single();

  if (error || !tokenData) {
    throw new Error('No Google account connected');
  }

  // Check if token is expired (with 5 min buffer)
  const expiresAt = new Date(tokenData.expires_at);
  const now = new Date();
  const bufferMs = 5 * 60 * 1000;

  if (expiresAt.getTime() - now.getTime() > bufferMs) {
    return tokenData.access_token;
  }

  // Refresh token
  const refreshResponse = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      client_id: Deno.env.get('GOOGLE_CLIENT_ID')!,
      client_secret: Deno.env.get('GOOGLE_CLIENT_SECRET')!,
      refresh_token: tokenData.refresh_token,
      grant_type: 'refresh_token',
    }),
  });

  if (!refreshResponse.ok) {
    // Token revoked, clear it
    await supabase
      .from('oauth_tokens')
      .delete()
      .eq('user_id', userId);

    throw new Error('Google authorization expired. Please reconnect.');
  }

  const newTokens = await refreshResponse.json();

  // Update stored tokens
  await supabase.from('oauth_tokens').update({
    access_token: newTokens.access_token,
    expires_at: new Date(Date.now() + newTokens.expires_in * 1000).toISOString(),
    // refresh_token might not be returned, keep existing
    ...(newTokens.refresh_token && { refresh_token: newTokens.refresh_token }),
  }).eq('user_id', userId);

  return newTokens.access_token;
}
```

## Step 8: OAuth States Table

```sql
-- Store OAuth state tokens
create table oauth_states (
  id uuid default gen_random_uuid() primary key,
  state text unique not null,
  user_id uuid references auth.users(id) on delete cascade not null,
  expires_at timestamptz not null,
  created_at timestamptz default now()
);

-- Auto-cleanup expired states
create index idx_oauth_states_expires on oauth_states(expires_at);
```

## Step 9: Client-Side Implementation

Create `lib/google.ts`:

```typescript
import { supabase } from './supabase';
import { Platform, Linking } from 'react-native';
import * as WebBrowser from 'expo-web-browser';

export async function connectGoogleCalendar() {
  // Get OAuth URL from backend
  const { data, error } = await supabase.functions.invoke('google-auth-url');

  if (error) throw error;

  if (Platform.OS === 'web') {
    // Redirect in same window
    window.location.href = data.url;
  } else {
    // Open in-app browser
    const result = await WebBrowser.openAuthSessionAsync(
      data.url,
      'synccal://' // Your app scheme
    );

    if (result.type === 'success') {
      // Handle callback URL
      const url = new URL(result.url);
      const success = url.searchParams.get('google');
      const error = url.searchParams.get('error');

      if (error) throw new Error(error);
      return success === 'connected';
    }
  }
}

export async function disconnectGoogleCalendar() {
  const { error } = await supabase.functions.invoke('disconnect-google');
  if (error) throw error;
}

export async function isGoogleConnected(): Promise<boolean> {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return false;

  const { data } = await supabase
    .from('oauth_tokens')
    .select('id')
    .eq('user_id', user.id)
    .eq('provider', 'google')
    .single();

  return !!data;
}
```

## Step 10: Connect Button Component

```tsx
import { useState, useEffect } from 'react';
import { View, Text, TouchableOpacity, StyleSheet, Alert } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { connectGoogleCalendar, disconnectGoogleCalendar, isGoogleConnected } from '@/lib/google';

export function GoogleConnectButton() {
  const [connected, setConnected] = useState(false);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    checkConnection();
  }, []);

  const checkConnection = async () => {
    const status = await isGoogleConnected();
    setConnected(status);
    setLoading(false);
  };

  const handlePress = async () => {
    setLoading(true);
    try {
      if (connected) {
        Alert.alert(
          'Disconnect Google',
          'This will remove access to your calendars. Continue?',
          [
            { text: 'Cancel', style: 'cancel' },
            {
              text: 'Disconnect',
              style: 'destructive',
              onPress: async () => {
                await disconnectGoogleCalendar();
                setConnected(false);
              },
            },
          ]
        );
      } else {
        await connectGoogleCalendar();
        await checkConnection();
      }
    } catch (error: any) {
      Alert.alert('Error', error.message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <TouchableOpacity
      style={[styles.button, connected && styles.buttonConnected]}
      onPress={handlePress}
      disabled={loading}
    >
      <Ionicons
        name="logo-google"
        size={24}
        color={connected ? '#10B981' : '#EA4335'}
      />
      <Text style={[styles.text, connected && styles.textConnected]}>
        {loading
          ? 'Loading...'
          : connected
          ? 'Google Calendar Connected'
          : 'Connect Google Calendar'}
      </Text>
      {connected && (
        <Ionicons name="checkmark-circle" size={20} color="#10B981" />
      )}
    </TouchableOpacity>
  );
}

const styles = StyleSheet.create({
  button: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: 16,
    backgroundColor: '#fff',
    borderRadius: 12,
    borderWidth: 1,
    borderColor: '#E5E7EB',
    gap: 12,
  },
  buttonConnected: {
    borderColor: '#10B981',
    backgroundColor: '#ECFDF5',
  },
  text: {
    flex: 1,
    fontSize: 16,
    color: '#1F2937',
  },
  textConnected: {
    color: '#059669',
  },
});
```

---

## Checkpoint

Before moving on, verify:

- [ ] OAuth consent screen is configured
- [ ] Can initiate Google authorization
- [ ] Callback receives code and exchanges for tokens
- [ ] Tokens are stored in database
- [ ] Token refresh works automatically
- [ ] Can disconnect Google account

---

## Common Issues

### "Access blocked: Authorization Error"

- Verify OAuth consent screen is configured
- Add your email as test user
- Check redirect URI matches exactly

### "Invalid redirect_uri"

- URIs must match character-for-character
- Include trailing slash if configured
- Check http vs https

### "Refresh token not returned"

- Include `prompt: 'consent'` in auth URL
- Include `access_type: 'offline'`
- User must grant consent again

---

## Security Considerations

1. **Encrypt tokens at rest** - Use Supabase Vault or similar
2. **Validate state parameter** - Prevents CSRF attacks
3. **Use short-lived access tokens** - Refresh as needed
4. **Handle revocation** - Clear tokens if refresh fails

---

## Next Steps

Continue to [02-calendar-api.md](./02-calendar-api.md) to fetch and display calendar data.
