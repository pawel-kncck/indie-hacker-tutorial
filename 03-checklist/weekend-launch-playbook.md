# Weekend Launch Playbook

The ultimate speed-run guide. Go from idea to deployed app in 48 hours.

---

## Prerequisites (Before the Weekend)

### Accounts Ready
- [ ] Apple Developer ($99/year)
- [ ] Google Play Developer ($25)
- [ ] Expo account
- [ ] Supabase account
- [ ] Vercel account
- [ ] Cloudflare account
- [ ] Stripe account
- [ ] RevenueCat account

### Tools Installed
- [ ] Node.js 18+
- [ ] EAS CLI (`npm install -g eas-cli`)
- [ ] Logged into EAS (`eas login`)
- [ ] VS Code with extensions

### Domain Ready
- [ ] Domain purchased on Cloudflare
- [ ] Know how to configure DNS

---

## Friday Evening (2-3 hours)

### Hour 1: Validate & Plan

**Validate the idea:**
- [ ] Can you explain it in one sentence?
- [ ] Who is the target user?
- [ ] What's the free tier limit?
- [ ] What's the subscription price?

**Define MVP scope:**
- [ ] List 3-5 core features only
- [ ] Cut everything else
- [ ] Sketch main screens on paper

### Hour 2: Project Setup

```bash
# Create project
npx create-expo-app@latest my-app
cd my-app

# Install essentials
npx expo install @supabase/supabase-js expo-secure-store

# Initialize EAS
eas init

# Create git repo
git init
git add .
git commit -m "Initial setup"
gh repo create my-app --public --push
```

### Hour 3: Supabase Setup

1. Create Supabase project
2. Design database tables (keep it simple!)
3. Write SQL for tables + RLS policies
4. Enable email auth
5. Get API keys
6. Create `.env` file

```bash
# .env
EXPO_PUBLIC_SUPABASE_URL=xxx
EXPO_PUBLIC_SUPABASE_ANON_KEY=xxx
```

### End of Friday

- [ ] Project created
- [ ] Supabase configured
- [ ] Basic file structure ready
- [ ] Git repo initialized

---

## Saturday (8-10 hours)

### Morning (4 hours): Core Features

**Hour 1-2: Authentication**
- [ ] Create Supabase client
- [ ] Build login screen
- [ ] Build signup screen
- [ ] Add auth context
- [ ] Test auth flow

**Hour 3-4: Main Feature**
- [ ] Create data tables in Supabase
- [ ] Build list view
- [ ] Build create form
- [ ] Add edit/delete
- [ ] Test CRUD operations

### Afternoon (4 hours): Polish & Deploy

**Hour 5-6: Navigation & UI**
- [ ] Set up tab navigation
- [ ] Style components
- [ ] Add loading states
- [ ] Add error handling

**Hour 7: First Deploy**
- [ ] Push to GitHub
- [ ] Connect Vercel
- [ ] Add environment variables
- [ ] Connect custom domain

**Hour 8: Development Build**
```bash
eas build --profile development --platform all
```
- [ ] Wait for builds (work on other things)
- [ ] Test on real device

### End of Saturday

- [ ] Auth working
- [ ] Core feature working
- [ ] Live on web at custom domain
- [ ] Development builds ready

---

## Sunday (8-10 hours)

### Morning (4 hours): Payments & Store Prep

**Hour 1-2: RevenueCat Setup**
- [ ] Create RevenueCat project
- [ ] Configure products in App Store Connect
- [ ] Configure products in Play Console
- [ ] Link to RevenueCat
- [ ] Test sandbox purchases

**Hour 3: Paywall**
- [ ] Build paywall screen
- [ ] Integrate RevenueCat SDK
- [ ] Add purchase buttons
- [ ] Handle success/restore

**Hour 4: Store Assets**
- [ ] Create app icon (1024×1024)
- [ ] Take screenshots
- [ ] Write app description
- [ ] Write keywords

### Afternoon (4-6 hours): Submit & Launch

**Hour 5-6: Production Builds**
```bash
# Bump version
# Update app.json: version, buildNumber, versionCode

# Build for production
eas build --profile production --platform all
```

**Hour 7: Submit to Stores**
```bash
eas submit --platform all
```

Fill in metadata:
- [ ] App Store Connect metadata
- [ ] Play Console listing
- [ ] Privacy policy URL
- [ ] Screenshots uploaded

**Hour 8: Marketing Prep**
- [ ] Write Product Hunt draft
- [ ] Prepare social posts
- [ ] Email to friends/family
- [ ] Reddit/forum posts

### End of Sunday

- [ ] App submitted to App Store
- [ ] App submitted to Play Store
- [ ] Marketing materials ready
- [ ] Celebrating 🎉

---

## The Next Week

### Monday-Tuesday
- [ ] Monitor review status
- [ ] Respond to any rejections quickly
- [ ] Android usually approves faster

### When Approved
- [ ] Post to Product Hunt
- [ ] Share on social media
- [ ] Post in communities
- [ ] Ask friends for reviews

---

## Speed Tips

### Cut Scope Ruthlessly
- No onboarding flow (just dump into app)
- No settings beyond logout
- No dark mode
- No animations beyond basics
- Hardcode things you can change later

### Use Templates
- Copy auth code from App 1
- Reuse component patterns
- Keep same project structure

### Parallel Work
- While builds run, work on assets
- While waiting for review, work on marketing
- While one platform builds, test on another

### Premade Assets
- Use AI for app icon drafts
- Screenshot tools: Simulator + Figma
- Copy privacy policy template

---

## Time Budget Template

| Block | Duration | Focus |
|-------|----------|-------|
| Friday Eve | 3h | Setup + Supabase |
| Sat AM | 4h | Auth + Core Feature |
| Sat PM | 4h | UI + Deploy |
| Sun AM | 4h | Payments + Assets |
| Sun PM | 4h | Submit + Marketing |
| **Total** | **19h** | |

Adjust based on complexity. Simple apps can be faster.

---

## Common Blockers & Fixes

### "EAS Build is taking too long"
- Free tier builds queue behind paid
- Start builds before lunch/dinner breaks
- Use development builds for testing, production only for submit

### "App Store rejected for metadata"
- Most common: missing privacy policy URL
- Second: screenshots don't match app
- Fix and resubmit, usually approved within hours

### "Supabase RLS blocking queries"
- Check policies with SQL Editor
- Use `auth.uid()` correctly
- Test with Supabase dashboard first

### "OAuth not working"
- Check redirect URLs in Supabase
- Add app scheme to allowed URLs
- Test on web first (easier debugging)

---

## Post-Weekend Roadmap

### Week 1 After Launch
- [ ] Gather user feedback
- [ ] Fix critical bugs
- [ ] Thank early reviewers
- [ ] OTA updates for quick fixes

### Week 2 After Launch
- [ ] Analyze usage patterns
- [ ] Plan v1.1 features
- [ ] A/B test paywall copy
- [ ] Iterate on marketing

### Month 1 Goals
- 100+ downloads
- 4.0+ star rating
- 5+ paying subscribers
- Clear path to App 2
