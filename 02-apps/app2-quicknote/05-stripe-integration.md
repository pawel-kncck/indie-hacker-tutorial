# 05 - Stripe Integration

> Day 3-4 of Week 5: Implement web payments with Stripe

## Overview

We'll implement:
- Stripe account setup
- Checkout sessions
- Customer portal
- Webhook handling
- Subscription status sync

---

## Step 1: Set Up Stripe

1. Create account at [stripe.com](https://stripe.com)
2. Go to **Developers → API keys**
3. Copy **Publishable key** and **Secret key**

### Create Products

In Stripe Dashboard → Products:

1. **QuickNote Pro Monthly**
   - Price: $4.99/month
   - Product ID: Save this
   - Price ID: Save this (e.g., `price_xxxxx`)

2. **QuickNote Pro Yearly**
   - Price: $29.99/year
   - Product ID: Save this
   - Price ID: Save this

## Step 2: Install Dependencies

For web:
```bash
npm install @stripe/stripe-js stripe
```

## Step 3: Create Checkout Edge Function

```bash
supabase functions new create-checkout
```

Edit `supabase/functions/create-checkout/index.ts`:

```typescript
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import Stripe from 'https://esm.sh/stripe@12.0.0?target=deno';

const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY')!, {
  apiVersion: '2023-10-16',
  httpClient: Stripe.createFetchHttpClient(),
});

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // Get user from JWT
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) throw new Error('No authorization header');

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } }
    );

    const { data: { user }, error: userError } = await supabase.auth.getUser();
    if (userError || !user) throw new Error('Unauthorized');

    const { priceId, successUrl, cancelUrl } = await req.json();

    // Check if customer exists
    let customerId: string | undefined;

    const { data: profile } = await supabase
      .from('profiles')
      .select('stripe_customer_id')
      .eq('id', user.id)
      .single();

    if (profile?.stripe_customer_id) {
      customerId = profile.stripe_customer_id;
    } else {
      // Create new customer
      const customer = await stripe.customers.create({
        email: user.email,
        metadata: { supabase_user_id: user.id },
      });
      customerId = customer.id;

      // Save customer ID
      await supabase
        .from('profiles')
        .update({ stripe_customer_id: customerId })
        .eq('id', user.id);
    }

    // Create checkout session
    const session = await stripe.checkout.sessions.create({
      customer: customerId,
      line_items: [{ price: priceId, quantity: 1 }],
      mode: 'subscription',
      success_url: successUrl || `${req.headers.get('origin')}/success`,
      cancel_url: cancelUrl || `${req.headers.get('origin')}/pricing`,
      subscription_data: {
        metadata: { supabase_user_id: user.id },
      },
    });

    return new Response(
      JSON.stringify({ url: session.url }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  } catch (error) {
    console.error('Checkout error:', error);
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

## Step 4: Customer Portal Function

```bash
supabase functions new create-portal
```

Edit `supabase/functions/create-portal/index.ts`:

```typescript
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import Stripe from 'https://esm.sh/stripe@12.0.0?target=deno';

const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY')!, {
  apiVersion: '2023-10-16',
  httpClient: Stripe.createFetchHttpClient(),
});

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) throw new Error('No authorization header');

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } }
    );

    const { data: { user }, error: userError } = await supabase.auth.getUser();
    if (userError || !user) throw new Error('Unauthorized');

    // Get customer ID
    const { data: profile } = await supabase
      .from('profiles')
      .select('stripe_customer_id')
      .eq('id', user.id)
      .single();

    if (!profile?.stripe_customer_id) {
      throw new Error('No subscription found');
    }

    const { returnUrl } = await req.json();

    const session = await stripe.billingPortal.sessions.create({
      customer: profile.stripe_customer_id,
      return_url: returnUrl || req.headers.get('origin'),
    });

    return new Response(
      JSON.stringify({ url: session.url }),
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

## Step 5: Webhook Handler

```bash
supabase functions new stripe-webhook
```

Edit `supabase/functions/stripe-webhook/index.ts`:

```typescript
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import Stripe from 'https://esm.sh/stripe@12.0.0?target=deno';

const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY')!, {
  apiVersion: '2023-10-16',
  httpClient: Stripe.createFetchHttpClient(),
});

const webhookSecret = Deno.env.get('STRIPE_WEBHOOK_SECRET')!;

serve(async (req) => {
  const signature = req.headers.get('stripe-signature');
  if (!signature) {
    return new Response('No signature', { status: 400 });
  }

  const body = await req.text();
  let event: Stripe.Event;

  try {
    event = await stripe.webhooks.constructEventAsync(
      body,
      signature,
      webhookSecret
    );
  } catch (err) {
    console.error('Webhook signature verification failed:', err);
    return new Response('Invalid signature', { status: 400 });
  }

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  );

  try {
    switch (event.type) {
      case 'customer.subscription.created':
      case 'customer.subscription.updated': {
        const subscription = event.data.object as Stripe.Subscription;
        const userId = subscription.metadata.supabase_user_id;

        if (userId) {
          await supabase.from('subscriptions').upsert({
            user_id: userId,
            stripe_subscription_id: subscription.id,
            stripe_customer_id: subscription.customer as string,
            status: subscription.status,
            price_id: subscription.items.data[0].price.id,
            current_period_start: new Date(subscription.current_period_start * 1000).toISOString(),
            current_period_end: new Date(subscription.current_period_end * 1000).toISOString(),
            cancel_at_period_end: subscription.cancel_at_period_end,
          });
        }
        break;
      }

      case 'customer.subscription.deleted': {
        const subscription = event.data.object as Stripe.Subscription;
        const userId = subscription.metadata.supabase_user_id;

        if (userId) {
          await supabase
            .from('subscriptions')
            .update({ status: 'canceled' })
            .eq('stripe_subscription_id', subscription.id);
        }
        break;
      }

      case 'invoice.paid': {
        const invoice = event.data.object as Stripe.Invoice;
        console.log('Invoice paid:', invoice.id);
        break;
      }

      case 'invoice.payment_failed': {
        const invoice = event.data.object as Stripe.Invoice;
        console.log('Payment failed:', invoice.id);
        // Send email notification to user
        break;
      }
    }

    return new Response(JSON.stringify({ received: true }), {
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (error) {
    console.error('Webhook error:', error);
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }
});
```

## Step 6: Database Schema

```sql
-- Add Stripe fields to profiles
alter table profiles add column stripe_customer_id text unique;

-- Subscriptions table
create table subscriptions (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users(id) on delete cascade unique,
  stripe_subscription_id text unique,
  stripe_customer_id text,
  status text,
  price_id text,
  current_period_start timestamptz,
  current_period_end timestamptz,
  cancel_at_period_end boolean default false,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- RLS
alter table subscriptions enable row level security;

create policy "Users can view own subscription"
on subscriptions for select
using (auth.uid() = user_id);

-- Index
create index idx_subscriptions_user on subscriptions(user_id);
```

## Step 7: Set Secrets

```bash
supabase secrets set STRIPE_SECRET_KEY=sk_xxx
supabase secrets set STRIPE_WEBHOOK_SECRET=whsec_xxx
```

## Step 8: Configure Webhook in Stripe

1. Go to Stripe Dashboard → Developers → Webhooks
2. Add endpoint: `https://YOUR_PROJECT.supabase.co/functions/v1/stripe-webhook`
3. Select events:
   - `customer.subscription.created`
   - `customer.subscription.updated`
   - `customer.subscription.deleted`
   - `invoice.paid`
   - `invoice.payment_failed`
4. Copy webhook secret to Supabase secrets

## Step 9: Client-Side Implementation

Create `lib/stripe.ts`:

```typescript
import { supabase } from './supabase';

export async function createCheckoutSession(priceId: string) {
  const { data, error } = await supabase.functions.invoke('create-checkout', {
    body: {
      priceId,
      successUrl: `${window.location.origin}/settings?success=true`,
      cancelUrl: `${window.location.origin}/settings?canceled=true`,
    },
  });

  if (error) throw error;

  // Redirect to Stripe
  window.location.href = data.url;
}

export async function openCustomerPortal() {
  const { data, error } = await supabase.functions.invoke('create-portal', {
    body: {
      returnUrl: window.location.href,
    },
  });

  if (error) throw error;

  window.location.href = data.url;
}
```

### Subscription Hook

Create `hooks/useSubscription.ts`:

```typescript
import { useState, useEffect } from 'react';
import { supabase } from '@/lib/supabase';
import { useAuth } from '@/contexts/AuthContext';

export type Subscription = {
  status: string;
  price_id: string;
  current_period_end: string;
  cancel_at_period_end: boolean;
};

export function useSubscription() {
  const { user } = useAuth();
  const [subscription, setSubscription] = useState<Subscription | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!user) {
      setSubscription(null);
      setLoading(false);
      return;
    }

    const fetchSubscription = async () => {
      const { data } = await supabase
        .from('subscriptions')
        .select('*')
        .eq('user_id', user.id)
        .single();

      setSubscription(data);
      setLoading(false);
    };

    fetchSubscription();

    // Listen for changes
    const channel = supabase
      .channel('subscription_changes')
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'subscriptions',
          filter: `user_id=eq.${user.id}`,
        },
        (payload) => {
          setSubscription(payload.new as Subscription);
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [user]);

  const isPro = subscription?.status === 'active' || subscription?.status === 'trialing';

  return { subscription, isPro, loading };
}
```

## Step 10: Pricing Component

```tsx
import { View, Text, TouchableOpacity, StyleSheet } from 'react-native';
import { createCheckoutSession } from '@/lib/stripe';

const PRICES = {
  monthly: 'price_xxxxx', // Replace with your price ID
  yearly: 'price_xxxxx',
};

export function PricingCard() {
  const [loading, setLoading] = useState(false);

  const handleSubscribe = async (priceId: string) => {
    setLoading(true);
    try {
      await createCheckoutSession(priceId);
    } catch (error) {
      Alert.alert('Error', 'Failed to start checkout');
    } finally {
      setLoading(false);
    }
  };

  return (
    <View style={styles.container}>
      <Text style={styles.title}>Upgrade to Pro</Text>

      <TouchableOpacity
        style={styles.card}
        onPress={() => handleSubscribe(PRICES.yearly)}
        disabled={loading}
      >
        <Text style={styles.badge}>BEST VALUE</Text>
        <Text style={styles.price}>$29.99/year</Text>
        <Text style={styles.savings}>Save 50%</Text>
      </TouchableOpacity>

      <TouchableOpacity
        style={styles.card}
        onPress={() => handleSubscribe(PRICES.monthly)}
        disabled={loading}
      >
        <Text style={styles.price}>$4.99/month</Text>
      </TouchableOpacity>
    </View>
  );
}
```

---

## Checkpoint

Before launching, verify:

- [ ] Checkout flow works in test mode
- [ ] Webhook receives events
- [ ] Subscription status updates in database
- [ ] Customer portal works
- [ ] Pro features unlock after payment

---

## Testing

### Test Cards

| Scenario | Card Number |
|----------|-------------|
| Success | 4242 4242 4242 4242 |
| Decline | 4000 0000 0000 0002 |
| 3D Secure | 4000 0025 0000 3155 |

### Webhook Testing

```bash
# Install Stripe CLI
brew install stripe/stripe-cli/stripe

# Forward webhooks to local
stripe listen --forward-to localhost:54321/functions/v1/stripe-webhook

# Trigger test event
stripe trigger customer.subscription.created
```

---

## Go Live Checklist

- [ ] Switch to production API keys
- [ ] Update webhook endpoint to production
- [ ] Test with real card (then refund)
- [ ] Set up Stripe Tax (if required)
- [ ] Configure email notifications in Stripe

---

## Congratulations!

You've completed QuickNote with:
- Audio recording
- Cloud storage
- AI transcription & summarization
- Stripe payments

Return to the [App Overview](./README.md) for launch tips.
