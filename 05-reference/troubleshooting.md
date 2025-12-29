# Troubleshooting Guide

Common errors and their solutions when building Expo + Supabase apps.

---

## Expo / React Native

### Metro Bundler Issues

**Error:** "Unable to resolve module" or bundler crashes

**Solutions:**
```bash
# Clear Metro cache
npx expo start --clear

# Clear node_modules and reinstall
rm -rf node_modules
rm package-lock.json
npm install

# Reset Expo cache
npx expo start -c
```

### iOS Simulator Not Starting

**Error:** Simulator doesn't launch or app doesn't install

**Solutions:**
```bash
# Reset simulator
xcrun simctl shutdown all
xcrun simctl erase all

# Or try a specific device
npx expo run:ios --device "iPhone 15 Pro"
```

### Android Emulator Issues

**Error:** "No Android device connected"

**Solutions:**
```bash
# List available devices
adb devices

# Kill and restart ADB
adb kill-server
adb start-server

# Check emulator is running
emulator -list-avds
emulator -avd YOUR_AVD_NAME
```

### "Cannot read property 'x' of undefined"

**Cause:** Trying to access data before it's loaded

**Solution:**
```typescript
// Add loading check
if (loading) return <ActivityIndicator />;
if (!data) return <Text>No data</Text>;

// Or use optional chaining
const name = user?.profile?.name ?? 'Guest';
```

---

## Supabase

### "Invalid API key"

**Cause:** Wrong or missing API key

**Solutions:**
- Check `.env` file has correct values
- Verify environment variables are prefixed with `EXPO_PUBLIC_`
- Restart Metro bundler after changing `.env`
- Check for typos in `SUPABASE_URL` and `SUPABASE_ANON_KEY`

### "Row level security policy violation"

**Cause:** RLS policy blocking access

**Solutions:**
```sql
-- Check RLS is enabled
select tablename, rowsecurity from pg_tables where schemaname = 'public';

-- View existing policies
select * from pg_policies where tablename = 'your_table';

-- Example fix: Allow users to manage own data
create policy "Users manage own data"
on your_table for all
using (auth.uid() = user_id);
```

### "JWT expired"

**Cause:** Session token has expired

**Solutions:**
```typescript
// Enable auto refresh in client config
const supabase = createClient(url, key, {
  auth: {
    autoRefreshToken: true,
    persistSession: true,
  },
});

// Or manually refresh
await supabase.auth.refreshSession();
```

### "Foreign key constraint violation"

**Cause:** Trying to insert/delete with invalid references

**Solutions:**
- Ensure referenced record exists before insert
- Use `on delete cascade` for automatic cleanup
- Check the order of operations

### Real-time Not Working

**Cause:** Multiple possible issues

**Checklist:**
```typescript
// 1. Enable replication on table (SQL)
alter table your_table replica identity full;

// 2. Check subscription is active
const channel = supabase.channel('changes')
  .on('postgres_changes', { ... }, callback)
  .subscribe((status) => {
    console.log('Subscription status:', status);
  });

// 3. Ensure RLS allows select
create policy "Users can see own changes"
on your_table for select
using (auth.uid() = user_id);
```

---

## Authentication

### "Email not confirmed"

**Cause:** User hasn't confirmed email

**Solutions:**
- Check spam folder for confirmation email
- Resend confirmation:
```typescript
await supabase.auth.resend({
  type: 'signup',
  email: 'user@example.com',
});
```
- Disable email confirmation in Supabase Dashboard (dev only)

### Google OAuth Not Working

**Cause:** Configuration issues

**Checklist:**
1. Verify redirect URIs match exactly in Google Cloud Console
2. Check OAuth consent screen is configured
3. Add yourself as test user (during development)
4. Verify `scheme` is set in `app.json`

```json
{
  "expo": {
    "scheme": "yourapp"
  }
}
```

### Session Not Persisting

**Cause:** Storage not working

**Solutions:**
```typescript
// Check SecureStore is available
import * as SecureStore from 'expo-secure-store';

const available = await SecureStore.isAvailableAsync();
console.log('SecureStore available:', available);

// On web, check localStorage
console.log('localStorage:', window.localStorage);
```

---

## Payments

### RevenueCat "Product Not Found"

**Cause:** Product sync issues

**Solutions:**
- Products take 24-48 hours to propagate in stores
- Verify product IDs match exactly (case-sensitive)
- Check RevenueCat dashboard for sync status
- Ensure products are "Approved" not "Waiting for Review"

### Stripe Checkout Fails

**Cause:** Various configuration issues

**Checklist:**
1. Verify Stripe secret key is correct
2. Check price ID exists and is active
3. Ensure success/cancel URLs are valid
4. Check webhook logs in Stripe Dashboard

### "Purchase failed" on iOS

**Cause:** Sandbox testing issues

**Solutions:**
- Sign out of regular App Store account
- Use sandbox tester account from App Store Connect
- Reset sandbox account if corrupted:
  - App Store Connect → Users & Access → Sandbox Testers

---

## EAS Build

### Build Fails with Code Signing Error

**Cause:** Certificate/provisioning issues

**Solutions:**
```bash
# Reset credentials
eas credentials

# Clear cached credentials
eas credentials --platform ios
# Select "Remove credentials"

# Rebuild with new credentials
eas build --platform ios --clear-cache
```

### Android Build Fails

**Cause:** Gradle or SDK issues

**Solutions:**
```bash
# Update build configuration
eas build:configure

# Clear gradle cache
cd android && ./gradlew clean

# Update SDK versions in app.json
{
  "expo": {
    "android": {
      "compileSdkVersion": 34,
      "targetSdkVersion": 34,
      "buildToolsVersion": "34.0.0"
    }
  }
}
```

### "Version code has already been used"

**Cause:** Build number already exists in store

**Solutions:**
```json
// app.json - Increment version code
{
  "expo": {
    "android": {
      "versionCode": 2  // Increment this
    }
  }
}

// Or use auto-increment in eas.json
{
  "build": {
    "production": {
      "autoIncrement": true
    }
  }
}
```

---

## Common TypeScript Errors

### "Property does not exist on type"

```typescript
// Bad
const name = user.name; // Error if user type doesn't have name

// Good
type User = {
  id: string;
  name: string;
};
const user: User = await getUser();
const name = user.name; // OK
```

### "Argument of type X is not assignable"

```typescript
// Bad
function greet(name: string) {}
greet(undefined); // Error

// Good
function greet(name: string | undefined) {}
// Or
function greet(name?: string) {}
```

### "Cannot find module"

```bash
# Check path alias in tsconfig.json
{
  "compilerOptions": {
    "baseUrl": ".",
    "paths": {
      "@/*": ["./*"]
    }
  }
}

# Restart TypeScript server in VS Code
# Cmd/Ctrl + Shift + P → "TypeScript: Restart TS Server"
```

---

## Performance Issues

### App is Slow

**Checklist:**
1. Use `React.memo` for expensive components
2. Use `useMemo` and `useCallback` for expensive computations
3. Avoid inline functions in render
4. Use FlatList instead of ScrollView for long lists
5. Profile with React DevTools

### Memory Leaks

**Cause:** Uncleared subscriptions or timers

**Solution:**
```typescript
useEffect(() => {
  const subscription = someObservable.subscribe(callback);
  const timer = setInterval(tick, 1000);

  // Clean up!
  return () => {
    subscription.unsubscribe();
    clearInterval(timer);
  };
}, []);
```

### Large Bundle Size

**Solutions:**
```bash
# Analyze bundle
npx expo export --dump-sourcemap
npx source-map-explorer dist/bundles/ios-xxx.js

# Use dynamic imports
const HeavyComponent = lazy(() => import('./HeavyComponent'));
```

---

## Debugging Tips

### Enable Verbose Logging

```typescript
// Supabase
const supabase = createClient(url, key, {
  auth: {
    debug: true,
  },
});

// React Navigation
import { LogBox } from 'react-native';
LogBox.ignoreLogs(['Warning: ...']); // Filter noise
```

### Use React Native Debugger

1. Install React Native Debugger
2. Press `j` in Expo CLI to open debugger
3. Use Network tab to inspect API calls
4. Use React DevTools for component tree

### Remote Debugging

```typescript
// Add console logs that appear in Expo dev tools
console.log('Debug:', someValue);

// Or use a service like LogRocket/Sentry
import * as Sentry from 'sentry-expo';
Sentry.Native.captureMessage('Debug info', { extra: { data } });
```

---

## Still Stuck?

### Resources

1. **Expo Forums:** [forums.expo.dev](https://forums.expo.dev)
2. **Supabase Discord:** [discord.supabase.com](https://discord.supabase.com)
3. **Stack Overflow:** Tag with `expo` or `supabase`
4. **GitHub Issues:** Check existing issues in respective repos

### Getting Help

When asking for help, include:
- Expo SDK version
- Platform (iOS/Android/web)
- Full error message
- Relevant code snippet
- Steps to reproduce
- What you've already tried
