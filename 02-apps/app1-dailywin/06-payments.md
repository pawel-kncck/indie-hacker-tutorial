# 06 - Payments

> Week 3: Implement subscriptions with RevenueCat for mobile and Stripe for web

## Overview

We'll implement:
- RevenueCat setup for iOS/Android
- In-app purchase products
- Paywall screen
- Subscription status checking
- Webhook to Supabase for server-side validation

---

## Step 1: Create RevenueCat Account

1. Go to [RevenueCat](https://www.revenuecat.com)
2. Sign up and create a new project
3. Name it "DailyWin"
4. Get your **API Key** from Project Settings

## Step 2: Connect App Stores

### iOS (App Store Connect)

1. In RevenueCat, go to **Apps** → **Add App** → **iOS**
2. Enter your Bundle ID: `com.yourcompany.dailywin`
3. Create a **Shared Secret** in App Store Connect:
   - Go to App Store Connect → Users & Access → Shared Secret
   - Generate and copy
4. Paste into RevenueCat

### Android (Google Play)

1. In RevenueCat, go to **Apps** → **Add App** → **Android**
2. Enter your Package Name: `com.yourcompany.dailywin`
3. Create a **Service Account** in Google Cloud:
   - Go to Google Cloud Console
   - Create service account with Editor role
   - Download JSON key
4. Upload JSON key to RevenueCat

## Step 3: Create Products in App Stores

### App Store Connect

1. Go to **My Apps** → **DailyWin** → **Subscriptions**
2. Create Subscription Group: "DailyWin Pro"
3. Add subscriptions:
   - `dailywin_pro_monthly` - $2.99/month
   - `dailywin_pro_yearly` - $19.99/year

Fill in:
- Display Name
- Description
- App Store Localization

### Google Play Console

1. Go to **Monetize** → **Subscriptions**
2. Create subscriptions:
   - `dailywin_pro_monthly` - $2.99/month
   - `dailywin_pro_yearly` - $19.99/year

## Step 4: Configure RevenueCat

### Products

In RevenueCat Dashboard:
1. Go to **Products**
2. Click **+ New** for each:
   - App Store: `dailywin_pro_monthly`
   - App Store: `dailywin_pro_yearly`
   - Play Store: `dailywin_pro_monthly`
   - Play Store: `dailywin_pro_yearly`

### Entitlements

1. Go to **Entitlements** → **+ New**
2. Create: `pro`
3. Attach all 4 products to this entitlement

### Offerings

1. Go to **Offerings**
2. Edit "default" offering:
   - Add package "monthly" → `dailywin_pro_monthly`
   - Add package "annual" → `dailywin_pro_yearly`

## Step 5: Install RevenueCat SDK

```bash
npx expo install react-native-purchases expo-build-properties
```

Update `app.json`:

```json
{
  "expo": {
    "plugins": [
      [
        "expo-build-properties",
        {
          "ios": {
            "deploymentTarget": "13.4"
          }
        }
      ]
    ]
  }
}
```

## Step 6: Initialize RevenueCat

Create `lib/revenuecat.ts`:

```typescript
import { Platform } from 'react-native';
import Purchases, {
  CustomerInfo,
  PurchasesOffering,
  LOG_LEVEL,
} from 'react-native-purchases';

const API_KEYS = {
  ios: process.env.EXPO_PUBLIC_REVENUECAT_IOS_KEY!,
  android: process.env.EXPO_PUBLIC_REVENUECAT_ANDROID_KEY!,
};

export async function initializePurchases(userId: string) {
  if (Platform.OS === 'web') {
    console.log('RevenueCat not available on web');
    return;
  }

  Purchases.setLogLevel(LOG_LEVEL.DEBUG);

  const apiKey = Platform.OS === 'ios' ? API_KEYS.ios : API_KEYS.android;

  await Purchases.configure({
    apiKey,
    appUserID: userId,
  });
}

export async function getOfferings(): Promise<PurchasesOffering | null> {
  if (Platform.OS === 'web') return null;

  try {
    const offerings = await Purchases.getOfferings();
    return offerings.current;
  } catch (error) {
    console.error('Error fetching offerings:', error);
    return null;
  }
}

export async function purchasePackage(packageId: string): Promise<boolean> {
  if (Platform.OS === 'web') return false;

  try {
    const offerings = await Purchases.getOfferings();
    const pkg = offerings.current?.availablePackages.find(
      (p) => p.identifier === packageId
    );

    if (!pkg) throw new Error('Package not found');

    await Purchases.purchasePackage(pkg);
    return true;
  } catch (error: any) {
    if (error.userCancelled) return false;
    throw error;
  }
}

export async function restorePurchases(): Promise<CustomerInfo> {
  return Purchases.restorePurchases();
}

export async function getCustomerInfo(): Promise<CustomerInfo | null> {
  if (Platform.OS === 'web') return null;

  try {
    return await Purchases.getCustomerInfo();
  } catch (error) {
    console.error('Error getting customer info:', error);
    return null;
  }
}

export function hasProAccess(customerInfo: CustomerInfo | null): boolean {
  if (!customerInfo) return false;
  return customerInfo.entitlements.active['pro'] !== undefined;
}
```

## Step 7: Subscription Context

Create `contexts/SubscriptionContext.tsx`:

```tsx
import {
  createContext,
  useContext,
  useEffect,
  useState,
  ReactNode,
} from 'react';
import { Platform } from 'react-native';
import Purchases, { CustomerInfo } from 'react-native-purchases';
import { useAuth } from './AuthContext';
import { initializePurchases, hasProAccess } from '@/lib/revenuecat';

type SubscriptionContextType = {
  isPro: boolean;
  loading: boolean;
  customerInfo: CustomerInfo | null;
  refresh: () => Promise<void>;
};

const SubscriptionContext = createContext<SubscriptionContextType>({
  isPro: false,
  loading: true,
  customerInfo: null,
  refresh: async () => {},
});

export function SubscriptionProvider({ children }: { children: ReactNode }) {
  const { user } = useAuth();
  const [customerInfo, setCustomerInfo] = useState<CustomerInfo | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!user) {
      setCustomerInfo(null);
      setLoading(false);
      return;
    }

    const initialize = async () => {
      if (Platform.OS === 'web') {
        // Check Supabase for web subscription status
        setLoading(false);
        return;
      }

      await initializePurchases(user.id);

      // Listen for customer info updates
      Purchases.addCustomerInfoUpdateListener((info) => {
        setCustomerInfo(info);
      });

      // Get initial customer info
      const info = await Purchases.getCustomerInfo();
      setCustomerInfo(info);
      setLoading(false);
    };

    initialize();

    return () => {
      if (Platform.OS !== 'web') {
        Purchases.removeCustomerInfoUpdateListener(() => {});
      }
    };
  }, [user]);

  const refresh = async () => {
    if (Platform.OS === 'web') return;
    const info = await Purchases.getCustomerInfo();
    setCustomerInfo(info);
  };

  const isPro = hasProAccess(customerInfo);

  return (
    <SubscriptionContext.Provider
      value={{ isPro, loading, customerInfo, refresh }}
    >
      {children}
    </SubscriptionContext.Provider>
  );
}

export function useSubscription() {
  return useContext(SubscriptionContext);
}
```

## Step 8: Paywall Screen

Create `app/(app)/paywall.tsx`:

```tsx
import { useState, useEffect } from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
  Alert,
  ActivityIndicator,
} from 'react-native';
import { router } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { PurchasesPackage } from 'react-native-purchases';
import { getOfferings, purchasePackage, restorePurchases } from '@/lib/revenuecat';
import { useSubscription } from '@/contexts/SubscriptionContext';

export default function PaywallScreen() {
  const [packages, setPackages] = useState<PurchasesPackage[]>([]);
  const [loading, setLoading] = useState(true);
  const [purchasing, setPurchasing] = useState(false);
  const { refresh } = useSubscription();

  useEffect(() => {
    loadOfferings();
  }, []);

  const loadOfferings = async () => {
    const offering = await getOfferings();
    if (offering) {
      setPackages(offering.availablePackages);
    }
    setLoading(false);
  };

  const handlePurchase = async (pkg: PurchasesPackage) => {
    setPurchasing(true);
    try {
      const success = await purchasePackage(pkg.identifier);
      if (success) {
        await refresh();
        router.back();
      }
    } catch (error: any) {
      Alert.alert('Purchase Failed', error.message);
    } finally {
      setPurchasing(false);
    }
  };

  const handleRestore = async () => {
    setPurchasing(true);
    try {
      await restorePurchases();
      await refresh();
      Alert.alert('Restored', 'Your purchases have been restored.');
      router.back();
    } catch (error: any) {
      Alert.alert('Restore Failed', error.message);
    } finally {
      setPurchasing(false);
    }
  };

  if (loading) {
    return (
      <View style={styles.center}>
        <ActivityIndicator size="large" color="#3B82F6" />
      </View>
    );
  }

  const monthly = packages.find((p) => p.identifier === '$rc_monthly');
  const annual = packages.find((p) => p.identifier === '$rc_annual');

  return (
    <View style={styles.container}>
      <TouchableOpacity style={styles.close} onPress={() => router.back()}>
        <Ionicons name="close" size={24} color="#6B7280" />
      </TouchableOpacity>

      <View style={styles.content}>
        <Ionicons name="diamond" size={64} color="#3B82F6" />
        <Text style={styles.title}>Upgrade to Pro</Text>
        <Text style={styles.subtitle}>
          Create unlimited habits and achieve your goals faster
        </Text>

        <View style={styles.features}>
          <Feature text="Unlimited habits" />
          <Feature text="Priority support" />
          <Feature text="Early access to new features" />
        </View>

        <View style={styles.packages}>
          {annual && (
            <PackageOption
              title="Annual"
              price={annual.product.priceString}
              period="/year"
              badge="BEST VALUE"
              onPress={() => handlePurchase(annual)}
              disabled={purchasing}
            />
          )}
          {monthly && (
            <PackageOption
              title="Monthly"
              price={monthly.product.priceString}
              period="/month"
              onPress={() => handlePurchase(monthly)}
              disabled={purchasing}
            />
          )}
        </View>

        <TouchableOpacity onPress={handleRestore} disabled={purchasing}>
          <Text style={styles.restore}>Restore Purchases</Text>
        </TouchableOpacity>
      </View>
    </View>
  );
}

function Feature({ text }: { text: string }) {
  return (
    <View style={styles.feature}>
      <Ionicons name="checkmark-circle" size={20} color="#10B981" />
      <Text style={styles.featureText}>{text}</Text>
    </View>
  );
}

function PackageOption({
  title,
  price,
  period,
  badge,
  onPress,
  disabled,
}: {
  title: string;
  price: string;
  period: string;
  badge?: string;
  onPress: () => void;
  disabled: boolean;
}) {
  return (
    <TouchableOpacity
      style={[styles.package, badge && styles.packageHighlight]}
      onPress={onPress}
      disabled={disabled}
    >
      {badge && <Text style={styles.badge}>{badge}</Text>}
      <Text style={styles.packageTitle}>{title}</Text>
      <Text style={styles.packagePrice}>
        {price}
        <Text style={styles.packagePeriod}>{period}</Text>
      </Text>
    </TouchableOpacity>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#fff',
  },
  center: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  close: {
    position: 'absolute',
    top: 60,
    right: 20,
    zIndex: 1,
    padding: 8,
  },
  content: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    padding: 24,
  },
  title: {
    fontSize: 28,
    fontWeight: 'bold',
    color: '#1F2937',
    marginTop: 16,
  },
  subtitle: {
    fontSize: 16,
    color: '#6B7280',
    textAlign: 'center',
    marginTop: 8,
    marginBottom: 32,
  },
  features: {
    alignSelf: 'stretch',
    marginBottom: 32,
  },
  feature: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 12,
    gap: 8,
  },
  featureText: {
    fontSize: 16,
    color: '#374151',
  },
  packages: {
    alignSelf: 'stretch',
    gap: 12,
    marginBottom: 24,
  },
  package: {
    borderWidth: 2,
    borderColor: '#E5E7EB',
    borderRadius: 12,
    padding: 20,
    alignItems: 'center',
  },
  packageHighlight: {
    borderColor: '#3B82F6',
    backgroundColor: '#EFF6FF',
  },
  badge: {
    fontSize: 10,
    fontWeight: 'bold',
    color: '#3B82F6',
    backgroundColor: '#DBEAFE',
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 4,
    marginBottom: 8,
  },
  packageTitle: {
    fontSize: 14,
    color: '#6B7280',
    marginBottom: 4,
  },
  packagePrice: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#1F2937',
  },
  packagePeriod: {
    fontSize: 14,
    fontWeight: 'normal',
    color: '#6B7280',
  },
  restore: {
    fontSize: 14,
    color: '#3B82F6',
  },
});
```

## Step 9: Check Subscription in App

Update `app/(app)/habit/new.tsx` to check limits:

```tsx
import { useSubscription } from '@/contexts/SubscriptionContext';

// Inside component:
const { isPro } = useSubscription();

const handleCreate = async () => {
  // Check habit limit for free users
  if (!isPro && habits.length >= 3) {
    router.push('/paywall');
    return;
  }

  // ... rest of create logic
};
```

## Step 10: Set Up Webhook (Optional)

For server-side validation, set up a webhook from RevenueCat to Supabase:

### Create Edge Function

Create `supabase/functions/revenuecat-webhook/index.ts`:

```typescript
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

serve(async (req) => {
  const authHeader = req.headers.get('Authorization');
  if (authHeader !== `Bearer ${Deno.env.get('REVENUECAT_WEBHOOK_SECRET')}`) {
    return new Response('Unauthorized', { status: 401 });
  }

  const event = await req.json();
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  );

  const userId = event.app_user_id;
  const isPro = event.subscriber?.entitlements?.pro?.is_active ?? false;

  // Update user's subscription status in database
  await supabase
    .from('user_subscriptions')
    .upsert({
      user_id: userId,
      is_pro: isPro,
      updated_at: new Date().toISOString(),
    });

  return new Response(JSON.stringify({ success: true }), {
    headers: { 'Content-Type': 'application/json' },
  });
});
```

---

## Checkpoint

Before launching, verify:

- [ ] Products created in App Store Connect
- [ ] Products created in Google Play Console
- [ ] Products configured in RevenueCat
- [ ] Entitlement "pro" grants access
- [ ] Paywall displays correctly
- [ ] Purchase flow works (test in sandbox)
- [ ] Restore purchases works
- [ ] Free tier limit is enforced

---

## Testing Purchases

### iOS Sandbox

1. Create Sandbox tester in App Store Connect
2. Sign out of regular App Store account on device
3. When prompted during purchase, use sandbox account

### Android Test Track

1. Add test email to license testers in Play Console
2. Use internal testing track
3. Purchases are free in test mode

---

## Common Issues

### "Product not found"

- Products take up to 24 hours to propagate
- Verify product IDs match exactly
- Check RevenueCat logs for sync status

### "Purchase failed"

- Ensure you're using sandbox/test accounts
- Check that products are approved in stores
- Verify agreements are signed in stores

### Subscription not recognized

- Check entitlement name matches: `pro`
- Verify webhook is configured (if using server-side)
- Try restore purchases

---

## Web Payments (Stripe)

For web, use Stripe Checkout:

```typescript
// Create checkout session via Edge Function
const { data } = await supabase.functions.invoke('create-checkout', {
  body: { priceId: 'price_xxxxx' },
});

// Redirect to Stripe
window.location.href = data.url;
```

See [Stripe documentation](https://stripe.com/docs/payments/checkout) for full implementation.

---

## Launch Checklist

- [ ] Submit app update with payment features
- [ ] Test purchases in production (refund after)
- [ ] Monitor RevenueCat dashboard for first sales
- [ ] Set up Slack/email notifications for purchases
- [ ] Plan your launch marketing

---

## Congratulations!

You've built a complete app with:
- Authentication
- Database CRUD
- Real-time updates
- Beautiful UI
- Subscriptions

Your app is ready to launch!

Return to the [App Overview](./README.md) for marketing and launch tips.
