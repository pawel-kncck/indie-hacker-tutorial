# Tech Stack Deep Dive

This document explains why each technology was chosen and what alternatives exist.

## Frontend: Expo (React Native)

### What It Is
Expo is a framework built on top of React Native that simplifies mobile development. You write JavaScript/TypeScript using React patterns, and it compiles to native iOS and Android apps plus a web version.

### Why Expo Over Alternatives

| Option | Pros | Cons | Verdict |
|--------|------|------|---------|
| **Expo** | One JS codebase, no Xcode/Android Studio needed, OTA updates | Slightly larger app size, some native limitations | ✅ Best for speed |
| **React Native (bare)** | Full native access | Complex setup, need both Xcode + Android Studio | Too slow for indie |
| **Flutter** | Great performance, good DX | Must learn Dart, different paradigm | Extra learning curve |
| **Native (Swift/Kotlin)** | Best performance | Two codebases, 2x the work | Not viable solo |
| **PWA** | Easiest web deploy | No app store presence, limited device APIs | Missing mobile market |

### Key Expo Concepts

**Managed vs Bare Workflow**
- **Managed** (recommended): Expo handles all native code. You never touch Xcode/Android Studio.
- **Bare**: Eject to full React Native when you need custom native modules.

Start managed. You can eject later if needed (rare for indie apps).

**EAS (Expo Application Services)**
- **EAS Build**: Compiles your app in the cloud. No Mac needed for iOS.
- **EAS Submit**: Uploads to App Store/Play Store automatically.
- **EAS Update**: Push JavaScript updates without app store review.

**Expo SDK**
Pre-built modules for common needs: camera, notifications, auth, storage, etc. Saves weeks of native development.

### When Expo Won't Work
- Apps requiring Bluetooth Low Energy (limited support)
- Heavy 3D graphics (use Unity instead)
- Apps that need background audio processing
- Custom native SDKs not yet supported

For 95% of indie app ideas, Expo is perfect.

---

## Backend: Supabase

### What It Is
Supabase is an open-source Firebase alternative built on PostgreSQL. It provides database, authentication, file storage, edge functions, and realtime subscriptions in one platform.

### Why Supabase Over Alternatives

| Option | Pros | Cons | Verdict |
|--------|------|------|---------|
| **Supabase** | PostgreSQL, generous free tier, all-in-one | Newer, smaller community | ✅ Best balance |
| **Firebase** | Mature, huge community | NoSQL (Firestore), vendor lock-in | Data modeling pain |
| **AWS Amplify** | Full AWS power | Complex, expensive, overkill | Too heavy |
| **PlanetScale** | Great MySQL | DB only, need separate auth/storage | More integration work |
| **Roll your own** | Full control | Massive time investment | Not for speed |

### Key Supabase Features

**PostgreSQL Database**
- Real SQL with joins, transactions, constraints
- Row Level Security (RLS) for data protection
- Full-text search built-in
- JSON columns when you need flexibility

**Authentication**
- Email/password, magic links, phone
- OAuth providers (Google, Apple, GitHub, etc.)
- JWT tokens that work seamlessly with RLS
- Session management handled automatically

**Storage**
- S3-compatible file storage
- Automatic image transformations
- Signed URLs for private files
- Integrates with RLS policies

**Edge Functions**
- Deno-based serverless functions
- Deploy alongside your database
- Perfect for API integrations, webhooks
- TypeScript out of the box

**Realtime**
- Subscribe to database changes
- Presence (who's online)
- Broadcast messages between clients

### Free Tier Limits
- 500 MB database
- 1 GB file storage
- 2 GB bandwidth
- 500K Edge Function invocations
- Unlimited API requests

This covers most apps until you have paying customers.

---

## Payments: RevenueCat + Stripe

### Why Two Payment Systems?

**The Problem**: Apple and Google require you to use their in-app purchase (IAP) systems for digital goods sold in mobile apps. You cannot use Stripe directly for subscriptions in iOS/Android apps.

**The Solution**:
- **RevenueCat** handles App Store and Play Store IAP
- **Stripe** handles web payments

RevenueCat also syncs subscription status across platforms, so a user who subscribes on iOS can access premium features on web.

### RevenueCat

**What It Does**
- Abstracts App Store Connect and Google Play Console APIs
- Unified SDK for iOS, Android, web
- Handles receipt validation, subscription status, trial periods
- Webhooks to sync with your backend
- Analytics dashboard

**Why Not Native IAP Directly?**
- Different APIs for iOS vs Android
- Receipt validation is complex
- Subscription state management is error-prone
- RevenueCat handles edge cases (refunds, family sharing, grace periods)

**Free Tier**
- Up to $2,500 monthly tracked revenue (MTR)
- Then 1% of MTR above that

### Stripe

**What It Does**
- Web payments (credit card, Apple Pay, Google Pay)
- Subscription management
- Invoicing, taxes, compliance
- Connect for marketplaces (if needed later)

**When to Use**
- Web-only subscriptions
- One-time purchases on web
- Physical goods (not subject to IAP rules)
- B2B/enterprise sales

---

## Deployment: Vercel + EAS

### Vercel (Web)

**What It Does**
- Hosts your Expo web build
- Git push = automatic deploy
- Preview URLs for pull requests
- Edge CDN, automatic SSL
- Custom domains

**Why Vercel**
- Zero configuration for Expo web
- Generous free tier (100GB bandwidth)
- Instant rollbacks
- Great developer experience

**Alternatives**: Netlify (similar), Cloudflare Pages (cheaper at scale)

### EAS (Mobile)

**What It Does**
- Builds iOS and Android apps in the cloud
- Submits directly to App Store and Play Store
- Manages signing credentials
- OTA updates without app store review

**Why EAS Over Local Builds**
- No Mac required for iOS
- No Android Studio required
- Consistent build environment
- Credential management handled
- CI/CD built-in

**Free Tier**
- 30 builds per month
- Unlimited submissions
- Unlimited OTA updates

---

## Domains: Cloudflare

### Why Cloudflare

- **Cheap domains**: Often $2-5 less than competitors per year
- **Free DNS**: Fast, reliable, with great dashboard
- **Free SSL**: Automatic HTTPS
- **DDoS protection**: Included
- **Email routing**: Forward emails to your main inbox for free

### Alternatives
- Namecheap: Good prices, decent interface
- Google Domains: Simple but being sold to Squarespace
- Porkbun: Cheapest for some TLDs

### Recommended TLDs for Apps

| TLD | Price/year | Notes |
|-----|------------|-------|
| `.app` | ~$14 | Requires HTTPS (good), professional |
| `.io` | ~$35 | Developer favorite, but expensive |
| `.co` | ~$12 | Short, startup-y |
| `.com` | ~$10 | Classic, but good names are taken |

---

## Push Notifications: Expo Notifications

### Why Expo Notifications

- Built into Expo SDK
- Handles iOS/Android differences
- Free tier is generous
- Works with EAS for credentials

### How It Works

1. Request permission from user
2. Get device push token
3. Store token in your database
4. Send notifications via Expo's push service

### Alternatives
- **OneSignal**: More features, but another service to manage
- **Firebase Cloud Messaging**: Free, but Firebase lock-in
- **AWS SNS**: Enterprise-grade, complex

For indie apps, Expo Notifications is simplest.

---

## Summary: The Speed Stack

```
┌─────────────────────────────────────────────┐
│                   User                       │
└─────────────────────┬───────────────────────┘
                      │
        ┌─────────────┼─────────────┐
        ▼             ▼             ▼
   ┌─────────┐   ┌─────────┐   ┌─────────┐
   │   Web   │   │   iOS   │   │ Android │
   │ (Vercel)│   │  (EAS)  │   │  (EAS)  │
   └────┬────┘   └────┬────┘   └────┬────┘
        │             │             │
        └─────────────┼─────────────┘
                      │
                      ▼
              ┌──────────────┐
              │  Expo App    │
              │  (One Code)  │
              └──────┬───────┘
                     │
        ┌────────────┼────────────┐
        ▼            ▼            ▼
   ┌─────────┐  ┌─────────┐  ┌─────────┐
   │Supabase │  │ Stripe  │  │Revenue- │
   │ (All)   │  │  (Web)  │  │  Cat    │
   └─────────┘  └─────────┘  └─────────┘
```

This stack lets one developer ship to all platforms in a weekend.
