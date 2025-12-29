# Deployment Checklist

Use this checklist every time you deploy. Speed comes from having a repeatable process.

---

## Web Deploy (Vercel)

### Before Deploying

- [ ] All changes committed to git
- [ ] No TypeScript errors (`npx tsc --noEmit`)
- [ ] Tested locally on web (`npx expo start` → `w`)
- [ ] Environment variables set in Vercel dashboard

### Deploy Steps

- [ ] Push to main branch: `git push origin main`
- [ ] Vercel auto-deploys (watch dashboard for status)
- [ ] Wait for "Ready" status

### After Deploying

- [ ] Visit production URL
- [ ] Test critical flows:
  - [ ] App loads without errors
  - [ ] Authentication works
  - [ ] Main features function
- [ ] Check console for errors
- [ ] Verify SSL certificate is valid

---

## Mobile Deploy (EAS)

### Before Building

- [ ] Update version in `app.json` if needed
- [ ] Increment `buildNumber` (iOS) and `versionCode` (Android)
- [ ] Commit all changes
- [ ] Verify environment variables in `eas.json`

```json
// app.json version fields
{
  "version": "1.0.0",
  "ios": { "buildNumber": "1" },
  "android": { "versionCode": 1 }
}
```

### Build Commands

```bash
# Development build (for testing)
eas build --profile development --platform all

# Preview build (for stakeholders)
eas build --profile preview --platform all

# Production build (for stores)
eas build --profile production --platform all
```

### During Build

- [ ] Note the build ID for reference
- [ ] Monitor build status in Expo dashboard
- [ ] Expected time: 15-30 minutes

### After Build

- [ ] Download and test on device
- [ ] Verify app opens without crash
- [ ] Test critical flows
- [ ] Check that version number is correct

---

## App Store Submission (iOS)

### Pre-Submission Checklist

- [ ] App icon (1024×1024, no alpha/transparency)
- [ ] Screenshots for required device sizes:
  - [ ] iPhone 6.7" (1290×2796)
  - [ ] iPhone 6.5" (1284×2778)
  - [ ] iPhone 5.5" (1242×2208)
  - [ ] iPad Pro 12.9" (2048×2732) if supporting iPad
- [ ] App description (max 4000 chars)
- [ ] Keywords (max 100 chars, comma-separated)
- [ ] Privacy policy URL
- [ ] Support URL
- [ ] What's New text (for updates)

### Submit via EAS

```bash
eas submit --platform ios
```

Or manually:
1. Go to App Store Connect
2. Select your app
3. Click `+` next to iOS App
4. Select the build
5. Fill in required metadata
6. Submit for review

### Post-Submission

- [ ] Status changes to "Waiting for Review"
- [ ] Monitor for review notes (usually 24-48 hours)
- [ ] Respond to any rejections within 24 hours

---

## Play Store Submission (Android)

### Pre-Submission Checklist

- [ ] App icon (512×512)
- [ ] Feature graphic (1024×500)
- [ ] Screenshots (min 2, max 8 per device type):
  - [ ] Phone screenshots
  - [ ] Tablet screenshots (if supporting)
- [ ] Short description (max 80 chars)
- [ ] Full description (max 4000 chars)
- [ ] Privacy policy URL
- [ ] Content rating questionnaire completed
- [ ] Target audience selected

### Submit via EAS

```bash
eas submit --platform android
```

Or manually:
1. Go to Google Play Console
2. Select your app
3. Production → Create new release
4. Upload AAB file
5. Fill in release notes
6. Review and roll out

### Post-Submission

- [ ] Review typically takes hours to a few days
- [ ] Monitor for policy violations
- [ ] Check crash reports in Play Console

---

## OTA Update (EAS Update)

### When to Use

✅ JavaScript/TypeScript changes
✅ Styling changes  
✅ New screens (no new native modules)
✅ Bug fixes in JS code

❌ Native module changes
❌ Expo SDK upgrades
❌ app.json changes

### Update Steps

```bash
# Preview what will be updated
npx expo export

# Publish update
eas update --branch production --message "Description of changes"
```

### After Update

- [ ] Verify update is live in Expo dashboard
- [ ] Test on device (may need to restart app)
- [ ] Monitor for issues

---

## Domain Setup Checklist

### Buy Domain (Cloudflare)

- [ ] Go to Cloudflare dashboard
- [ ] Registrar → Register Domain
- [ ] Search and purchase domain
- [ ] Domain is now in your account

### Connect to Vercel

- [ ] Go to Vercel project → Settings → Domains
- [ ] Add your domain
- [ ] Copy the DNS records Vercel provides

### Configure DNS (Cloudflare)

- [ ] Go to your domain in Cloudflare
- [ ] DNS → Add records from Vercel
- [ ] Typically: CNAME `@` → `cname.vercel-dns.com`
- [ ] Enable "Proxied" for DDoS protection
- [ ] Wait for DNS propagation (few minutes to hours)

### Verify

- [ ] Visit your domain
- [ ] SSL certificate is active (HTTPS works)
- [ ] Redirects work (www → non-www or vice versa)

---

## Emergency Rollback

### Web (Vercel)

1. Go to Vercel dashboard
2. Deployments tab
3. Find previous working deployment
4. Click `...` → Promote to Production

### Mobile (OTA)

```bash
# List updates
eas update:list

# Rollback to previous update
eas update:rollback --branch production
```

### Mobile (Full Build)

If native code is broken:
1. Previous version remains on stores
2. Users won't get update until new build approved
3. Submit fixed build ASAP

---

## Quick Deploy Commands

```bash
# Web: push to deploy
git push origin main

# Mobile: development build
eas build --profile development --platform all

# Mobile: production build + submit
eas build --profile production --platform all
eas submit --platform all

# OTA update
eas update --branch production --message "Fix: description"

# Check build status
eas build:list
```
