# 05 - App Store Submission

> Day 5 + Weekend of Week 2: Prepare assets, create store listings, and submit your app

## Overview

We'll cover:
- Creating app icons and screenshots
- Setting up App Store Connect
- Setting up Google Play Console
- Building production apps with EAS
- Submitting for review

---

## Step 1: Create App Icon

### Design Requirements

| Platform | Size | Format |
|----------|------|--------|
| iOS | 1024x1024 | PNG, no alpha |
| Android | 512x512 | PNG |

### Quick Icon Creation

Use [Figma](https://figma.com) or these tools:
- [Icon Kitchen](https://icon.kitchen) - Free icon generator
- [Canva](https://canva.com) - Templates available
- [Midjourney](https://midjourney.com) - AI-generated icons

### Icon Tips

1. Keep it simple - recognizable at small sizes
2. Use your brand color
3. Avoid text (unreadable when small)
4. Test at 29x29 and 60x60 sizes

### Export for Expo

Place your icon at `assets/icon.png` (1024x1024).

For adaptive Android icons:
- `assets/adaptive-icon.png` (foreground, with padding)

## Step 2: Create Screenshots

### Requirements

| Store | Device | Size |
|-------|--------|------|
| iOS | iPhone 6.7" | 1290x2796 |
| iOS | iPhone 6.5" | 1284x2778 |
| iOS | iPad 12.9" | 2048x2732 |
| Android | Phone | 1080x1920 min |

### Screenshot Strategy

Create 4-6 screenshots showing:
1. **Hero** - Main value prop, today's habits
2. **Feature 1** - Creating a habit
3. **Feature 2** - Checking off habits
4. **Feature 3** - Progress/streaks view
5. **Feature 4** - Settings/subscription (optional)
6. **Social Proof** - Reviews or stats (if available)

### Tools for Screenshots

- [Shots.so](https://shots.so) - Free device mockups
- [AppMockUp](https://app-mockup.com) - Store screenshots
- [Figma App Store Template](https://www.figma.com/community/file/1021254680899878390)

### Tips

1. Add captions to each screenshot
2. Use your brand colors for backgrounds
3. Show actual app content (not lorem ipsum)
4. Highlight the key benefit in each image

## Step 3: Write Store Listing

### App Store Description Template

```
[Main Value Prop - 1 line]

Build lasting habits and track your streaks with DailyWin.

[Key Features]

SIMPLE HABIT TRACKING
- Create habits in seconds
- One-tap daily check-ins
- Visual progress tracking

STREAK MOTIVATION
- Current and longest streaks
- Satisfying completion animations
- Daily reminders (optional)

BEAUTIFUL DESIGN
- Clean, distraction-free interface
- Multiple color themes
- Works on all your devices

[Call to Action]

Start your first habit today - it only takes 30 seconds.

[Subscription Info - Required for apps with IAP]

DailyWin Pro: $2.99/month or $19.99/year
- Unlimited habits (free users: 3 habits)
- Priority support

Payment will be charged to your Apple ID account at confirmation of purchase. Subscription automatically renews unless canceled at least 24 hours before the end of the current period. Manage subscriptions in Account Settings after purchase.

Terms of Service: [your-url]/terms
Privacy Policy: [your-url]/privacy
```

### Keywords (iOS)

100 characters max, comma-separated:

```
habit tracker,streak,daily habits,routine,goals,productivity,wellness,self improvement,motivation
```

### Google Play Short Description

80 characters max:

```
Build habits, track streaks, achieve goals. Simple and beautiful.
```

## Step 4: Set Up App Store Connect

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Click **Apps** → **+** → **New App**
3. Fill in:
   - Platform: iOS
   - Name: DailyWin
   - Primary Language: English
   - Bundle ID: Select from dropdown (from EAS)
   - SKU: `dailywin-001`
   - User Access: Full Access

### App Information

Fill in all required fields:
- Subtitle (30 chars): "Build Better Habits"
- Category: Health & Fitness or Productivity
- Age Rating: Complete the questionnaire (usually 4+)
- Privacy Policy URL: Your privacy policy link

### App Privacy

Apple requires you to disclose data collection:
- For Supabase auth: Account info (email), identifiers
- For analytics: Usage data
- For purchases: Purchase history

## Step 5: Set Up Google Play Console

1. Go to [Google Play Console](https://play.google.com/console)
2. Click **Create app**
3. Fill in:
   - App name: DailyWin
   - Default language: English
   - App or game: App
   - Free or paid: Free (with IAP)

### Store Listing

- Short description: 80 chars
- Full description: 4000 chars max
- App icon: 512x512
- Feature graphic: 1024x500
- Screenshots: At least 2

### Content Rating

Complete the IARC questionnaire for age rating.

### Data Safety

Declare data collection similar to iOS App Privacy.

## Step 6: Build with EAS

### Configure eas.json

```json
{
  "cli": {
    "version": ">= 5.0.0"
  },
  "build": {
    "development": {
      "developmentClient": true,
      "distribution": "internal"
    },
    "preview": {
      "distribution": "internal",
      "ios": {
        "simulator": true
      }
    },
    "production": {
      "autoIncrement": true
    }
  },
  "submit": {
    "production": {
      "ios": {
        "appleId": "your@email.com",
        "ascAppId": "123456789",
        "appleTeamId": "XXXXXXXXXX"
      },
      "android": {
        "serviceAccountKeyPath": "./google-service-account.json"
      }
    }
  }
}
```

### Build Production Apps

```bash
# Build iOS
eas build --platform ios --profile production

# Build Android
eas build --platform android --profile production

# Or both at once
eas build --platform all --profile production
```

### Wait for Builds

Builds typically take:
- iOS: 15-30 minutes
- Android: 10-20 minutes

Check status at [expo.dev](https://expo.dev)

## Step 7: Submit to Stores

### Automatic Submission

```bash
# Submit iOS build to App Store Connect
eas submit --platform ios --latest

# Submit Android build to Google Play
eas submit --platform android --latest
```

### Manual iOS Submission

1. Download `.ipa` from EAS dashboard
2. Use Transporter app to upload
3. In App Store Connect, select the build
4. Fill in version information
5. Submit for review

### Manual Android Submission

1. Download `.aab` from EAS dashboard
2. In Google Play Console, go to Production
3. Create new release
4. Upload the `.aab` file
5. Add release notes
6. Submit for review

## Step 8: Review Guidelines

### iOS Common Rejections

1. **Incomplete metadata** - Fill in all fields
2. **Broken links** - Test privacy policy/terms links
3. **Login required** - Provide demo account or note it's not needed
4. **IAP issues** - Test purchases in sandbox
5. **Crashes** - Test on real devices

### Android Common Rejections

1. **Target API level** - Must be current (API 34+)
2. **Permissions** - Only request what you need
3. **Content policy** - No misleading content
4. **Data safety** - Must be accurate

### Demo Account

If your app requires login, provide:
- Test email: `reviewer@dailywin.app`
- Test password: `AppReview2024!`

Note: Create this account in your Supabase project.

## Step 9: Review Timeline

| Store | Typical Time | Range |
|-------|--------------|-------|
| App Store | 24-48 hours | 1-7 days |
| Google Play | 1-3 days | 1-14 days |

### While Waiting

- Set up your landing page
- Prepare launch marketing
- Test the web version
- Plan first update based on feedback

---

## Checkpoint

Before submitting, verify:

- [ ] App icon looks good at all sizes
- [ ] 4+ screenshots uploaded for each device size
- [ ] Description is complete and compelling
- [ ] Keywords are relevant (iOS)
- [ ] Privacy policy is live and linked
- [ ] Terms of service is live and linked
- [ ] App runs without crashes
- [ ] All IAP products are created (even if not functional yet)

---

## Common Issues

### "Missing Compliance" (iOS)

For the export compliance question:
- If you only use HTTPS: Select "No" for custom encryption
- Add `ITSAppUsesNonExemptEncryption: false` to `ios.infoPlist` in app.json

### Build Signing Errors

```bash
# Reset credentials
eas credentials
```

### Upload Stuck

- Check your internet connection
- Try again with `--wait` flag
- Use Transporter app as fallback

---

## Next Steps

While waiting for review, continue to [06-payments.md](./06-payments.md) to implement subscriptions.
