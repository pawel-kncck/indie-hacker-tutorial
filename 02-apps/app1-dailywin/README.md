# App 1: DailyWin - Habit Streak Tracker

Your first production app. Simple enough to finish in 3 weeks, complex enough to learn real patterns.

## Overview

| Attribute | Value |
|-----------|-------|
| **Timeline** | Weeks 1-3 |
| **Complexity** | Beginner |
| **Revenue Model** | Freemium (3 habits free, unlimited = $2.99/mo) |
| **Platforms** | Web, iOS, Android |

## The Product

DailyWin helps users build habits through daily check-ins and streak tracking.

**Core Features:**
- Create habits with name and color
- Mark habits complete each day
- Track current and longest streaks
- Simple progress visualization

**Why This App:**
- Proven market (habit trackers are popular)
- Simple CRUD operations
- Clear subscription value (more habits)
- Visual feedback is satisfying

---

## Database Schema

```sql
-- Users are handled by Supabase Auth

-- Habits table
create table habits (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users(id) on delete cascade not null,
  name text not null,
  color text default '#3B82F6',
  icon text default 'checkmark-circle',
  created_at timestamptz default now(),
  archived_at timestamptz
);

-- Daily completions
create table completions (
  id uuid default gen_random_uuid() primary key,
  habit_id uuid references habits(id) on delete cascade not null,
  completed_date date not null,
  created_at timestamptz default now(),
  
  -- Prevent duplicate completions for same day
  unique(habit_id, completed_date)
);

-- Indexes for performance
create index idx_habits_user on habits(user_id);
create index idx_completions_habit on completions(habit_id);
create index idx_completions_date on completions(completed_date);

-- Row Level Security
alter table habits enable row level security;
alter table completions enable row level security;

-- Policies
create policy "Users manage own habits"
  on habits for all
  using (auth.uid() = user_id);

create policy "Users manage completions for own habits"
  on completions for all
  using (
    habit_id in (
      select id from habits where user_id = auth.uid()
    )
  );
```

---

## Screen Map

```
(auth)
├── login.tsx          # Email/password + Google sign-in
├── signup.tsx         # Create account
└── forgot-password.tsx

(app)
├── (tabs)
│   ├── index.tsx      # Today's habits with check buttons
│   ├── progress.tsx   # Streaks and statistics
│   └── settings.tsx   # Account, subscription, preferences
├── habit/
│   ├── new.tsx        # Create habit (modal)
│   └── [id].tsx       # View/edit habit details
└── paywall.tsx        # Subscription screen (modal)
```

---

## Week-by-Week Guide

### Week 1: Foundation + First Deploy

| Day | Focus | Deliverable |
|-----|-------|-------------|
| 1-2 | Project setup | Expo project with navigation structure |
| 3 | Supabase setup | Database tables, auth configured |
| 4 | Authentication | Login/signup working on all platforms |
| 5 | First deploy | Live on Vercel, development build on EAS |
| Weekend | Domain | Custom domain connected |

**Milestone:** Live app skeleton with working auth at yourdomain.com

→ [Detailed guide: 01-project-setup.md](./01-project-setup.md)
→ [Detailed guide: 02-authentication.md](./02-authentication.md)

### Week 2: Core Features + App Store Prep

| Day | Focus | Deliverable |
|-----|-------|-------------|
| 1-2 | Habit CRUD | Create, edit, delete, list habits |
| 3 | Completions | Mark complete, calculate streaks |
| 4 | UI polish | Animations, colors, responsive |
| 5 | Store assets | Icon, screenshots, descriptions |
| Weekend | Submit | Production builds submitted to stores |

**Milestone:** Feature-complete app submitted to App Store and Play Store

→ [Detailed guide: 03-database-crud.md](./03-database-crud.md)
→ [Detailed guide: 04-ui-polish.md](./04-ui-polish.md)
→ [Detailed guide: 05-app-store-submission.md](./05-app-store-submission.md)

### Week 3: Payments + Launch

| Day | Focus | Deliverable |
|-----|-------|-------------|
| 1-2 | RevenueCat setup | Products configured in stores + RC |
| 3 | Paywall | Subscription screen, purchase flow |
| 4 | Test payments | Sandbox testing, webhook to Supabase |
| 5 | Submit update | New build with payments |
| Weekend | Launch! | Marketing, first users, first sale |

**Milestone:** App live on all stores with working payments

→ [Detailed guide: 06-payments.md](./06-payments.md)

---

## Tech Decisions

### Why These Choices

| Decision | Choice | Reason |
|----------|--------|--------|
| Date handling | `date` type, not `timestamptz` | Completions are day-based, not time-based |
| Streak calculation | Compute on read | Simpler than maintaining streak counters |
| Free tier limit | Client-side check | Simple for MVP, add server check later |
| Color picker | Preset colors | Faster than full color picker |

### What We're Skipping (For Now)

- Habit reminders/notifications (add in App 3)
- Social features (sharing streaks)
- Detailed analytics
- Custom icons upload

These can be added later as upsell features or v2.

---

## Revenue Model

### Subscription Tiers

| Tier | Price | Limits |
|------|-------|--------|
| Free | $0 | 3 habits |
| Pro | $2.99/mo or $19.99/yr | Unlimited habits |

### Paywall Triggers

1. When user tries to create 4th habit
2. Settings → "Upgrade to Pro"
3. Soft prompt after 7-day streak (celebration moment)

### RevenueCat Products

```
Products:
- dailywin_pro_monthly ($2.99)
- dailywin_pro_yearly ($19.99)

Entitlements:
- pro (grants unlimited habits)

Offerings:
- default
  - monthly: dailywin_pro_monthly
  - yearly: dailywin_pro_yearly (BEST VALUE badge)
```

---

## Marketing Launch Checklist

### Pre-Launch (Week 2)

- [ ] Create landing page at domain
- [ ] Set up Twitter/X account for app
- [ ] Write Product Hunt listing (don't post yet)
- [ ] Create demo video (60 seconds)
- [ ] Prepare App Store screenshots

### Launch Day (Week 3)

- [ ] Post to Product Hunt
- [ ] Share on Twitter/X, LinkedIn
- [ ] Post in relevant subreddits (r/productivity, r/getdisciplined)
- [ ] Share in Indie Hackers community
- [ ] Email friends/family to download and review

### Post-Launch

- [ ] Respond to all reviews
- [ ] Monitor crash reports (Sentry)
- [ ] Gather feedback for v1.1

---

## Success Metrics

### Week 3 Goals

| Metric | Target |
|--------|--------|
| App Store approval | ✓ |
| Play Store approval | ✓ |
| First download (not you) | 1+ |
| First paying customer | 1+ |

### Month 1 Goals

| Metric | Target |
|--------|--------|
| Downloads | 100+ |
| Active users | 20+ |
| Paying subscribers | 5+ |
| App Store rating | 4.0+ |

---

## File Structure

```
dailywin/
├── app/
│   ├── _layout.tsx
│   ├── (auth)/
│   │   ├── _layout.tsx
│   │   ├── login.tsx
│   │   ├── signup.tsx
│   │   └── forgot-password.tsx
│   ├── (app)/
│   │   ├── _layout.tsx
│   │   ├── (tabs)/
│   │   │   ├── _layout.tsx
│   │   │   ├── index.tsx
│   │   │   ├── progress.tsx
│   │   │   └── settings.tsx
│   │   ├── habit/
│   │   │   ├── new.tsx
│   │   │   └── [id].tsx
│   │   └── paywall.tsx
├── components/
│   ├── HabitCard.tsx
│   ├── StreakBadge.tsx
│   ├── CheckButton.tsx
│   └── PaywallModal.tsx
├── contexts/
│   ├── AuthContext.tsx
│   └── SubscriptionContext.tsx
├── hooks/
│   ├── useHabits.ts
│   ├── useCompletions.ts
│   └── useSubscription.ts
├── lib/
│   ├── supabase.ts
│   └── revenuecat.ts
├── types/
│   └── supabase.ts
├── assets/
├── app.json
└── eas.json
```

---

## Guides

1. [Project Setup](./01-project-setup.md)
2. [Authentication](./02-authentication.md)
3. [Database & CRUD](./03-database-crud.md)
4. [UI Polish](./04-ui-polish.md)
5. [App Store Submission](./05-app-store-submission.md)
6. [Payments](./06-payments.md)

Start with [01-project-setup.md](./01-project-setup.md).
