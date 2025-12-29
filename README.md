# Indie Hacker Launch Curriculum

> From zero to three published apps in 8 weeks

## Philosophy

This curriculum follows three core principles:

1. **Deploy First** - Every feature gets deployed immediately. No local-only development.
2. **Revenue Early** - Payments are integrated from the start, not bolted on later.
3. **One Codebase** - Web, iOS, and Android from a single JavaScript codebase.

By the end, you'll have a repeatable playbook to launch any app idea in a single weekend.

## The Stack

| Layer | Technology | Why |
|-------|------------|-----|
| Frontend | Expo (React Native) | One codebase → Web + iOS + Android |
| Backend | Supabase | PostgreSQL + Auth + Storage + Functions |
| Payments | RevenueCat + Stripe | Mobile IAP + Web payments |
| Mobile Deploy | EAS | Cloud builds, auto-submission |
| Web Deploy | Vercel | Git push = deploy |
| Domain | Cloudflare | Cheap, fast, easy |

## The Three Apps

| App | Complexity | Weeks | What You'll Learn |
|-----|------------|-------|-------------------|
| **DailyWin** (Habit Tracker) | Beginner | 1-3 | Auth, CRUD, first app store submission |
| **QuickNote** (Voice → AI Notes) | Intermediate | 4-5 | File storage, Edge Functions, external APIs |
| **SyncCal** (Calendar Assistant) | Advanced | 6-8 | OAuth, cron jobs, push notifications |

## Curriculum Structure

### [00-setup/](./00-setup/)
Everything you need before writing code: accounts, tools, costs.

- [tech-stack.md](./00-setup/tech-stack.md) - Deep dive into why each technology
- [accounts-checklist.md](./00-setup/accounts-checklist.md) - All accounts with setup steps
- [local-environment.md](./00-setup/local-environment.md) - Dev machine configuration
- [cost-breakdown.md](./00-setup/cost-breakdown.md) - What you'll spend and when

### [01-foundations/](./01-foundations/)
Core concepts you'll use in every app.

- [expo-essentials.md](./01-foundations/expo-essentials.md) - Project structure, components, patterns
- [supabase-essentials.md](./01-foundations/supabase-essentials.md) - Database, auth, storage
- [navigation-patterns.md](./01-foundations/navigation-patterns.md) - React Navigation setup
- [deployment-pipeline.md](./01-foundations/deployment-pipeline.md) - Vercel + EAS workflow

### [02-apps/](./02-apps/)
Step-by-step guides for each app.

- [app1-dailywin/](./02-apps/app1-dailywin/) - Habit tracker (Weeks 1-3)
- [app2-quicknote/](./02-apps/app2-quicknote/) - Voice notes with AI (Weeks 4-5)
- [app3-synccal/](./02-apps/app3-synccal/) - Calendar assistant (Weeks 6-8)

### [03-checklists/](./03-checklists/)
Repeatable processes for speed.

- [deployment-checklist.md](./03-checklists/deployment-checklist.md) - Web + mobile deploy
- [app-store-checklist.md](./03-checklists/app-store-checklist.md) - Submission requirements
- [launch-day-checklist.md](./03-checklists/launch-day-checklist.md) - Go-live tasks
- [weekend-launch-playbook.md](./03-checklists/weekend-launch-playbook.md) - Speed-run guide

### [04-templates/](./04-templates/)
Copy-paste starting points.

- [privacy-policy.md](./04-templates/privacy-policy.md) - Required for app stores
- [terms-of-service.md](./04-templates/terms-of-service.md) - Legal protection
- [app-store-description.md](./04-templates/app-store-description.md) - Copywriting template
- [supabase-schema.sql](./04-templates/supabase-schema.sql) - Starter database patterns

### [05-reference/](./05-reference/)
Quick lookups and troubleshooting.

- [code-snippets.md](./05-reference/code-snippets.md) - Common patterns
- [troubleshooting.md](./05-reference/troubleshooting.md) - Error solutions
- [resources.md](./05-reference/resources.md) - Links and communities

## Weekly Schedule

| Week | Focus | Milestone |
|------|-------|-----------|
| 0 | Setup | All accounts created, environment ready |
| 1 | Foundation | Auth working, first deploy to all platforms |
| 2 | App 1 Features | Core features done, submitted to stores |
| 3 | App 1 Launch | Payments working, app live, first sale |
| 4 | App 2 Foundation | Audio + file storage + Edge Functions |
| 5 | App 2 Launch | AI integration, Stripe, app live |
| 6 | App 3 OAuth | Google Calendar connected |
| 7 | App 3 Automation | Cron jobs + push notifications |
| 8 | App 3 Launch | Three apps live! |

## Getting Started

1. Complete everything in [00-setup/](./00-setup/)
2. Read through [01-foundations/](./01-foundations/) 
3. Start [App 1: DailyWin](./02-apps/app1-dailywin/)

Total estimated time: 8 weeks at 15-20 hours/week.

---

*Built for developers who want to ship fast and learn by doing.*
