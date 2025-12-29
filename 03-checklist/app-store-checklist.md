# App Store Submission Checklist

A comprehensive checklist for submitting your app to the Apple App Store and Google Play Store.

## Before You Start

- [ ] Developer accounts active (Apple: $99/yr, Google: $25 one-time)
- [ ] App runs without crashes on all target platforms
- [ ] All features work as expected
- [ ] No placeholder content or lorem ipsum text

---

## App Assets

### App Icon

| Platform | Size | Requirements |
|----------|------|--------------|
| iOS | 1024x1024 | PNG, no alpha, no rounded corners |
| Android | 512x512 | PNG, 32-bit with alpha |

- [ ] Icon is simple and recognizable at small sizes
- [ ] No text in the icon (unreadable when small)
- [ ] Brand colors are used consistently
- [ ] Icon tested at 29x29 and 60x60 sizes

### Screenshots

**iOS Required Sizes:**
- [ ] 6.7" (iPhone 14 Pro Max): 1290 x 2796
- [ ] 6.5" (iPhone 11 Pro Max): 1284 x 2778
- [ ] 5.5" (iPhone 8 Plus): 1242 x 2208
- [ ] iPad Pro 12.9": 2048 x 2732

**Android Required:**
- [ ] Phone: Min 1080 x 1920, Max 3840 x 2160
- [ ] 7" Tablet: 1080 x 1920
- [ ] 10" Tablet: 1920 x 1200

**Screenshot Content:**
- [ ] 4-8 screenshots per device size
- [ ] Hero screenshot shows main value proposition
- [ ] Each screenshot highlights a key feature
- [ ] Captions added explaining benefits
- [ ] No placeholder or test data
- [ ] Consistent style across all screenshots

### App Preview Video (Optional but Recommended)

- [ ] 15-30 seconds long
- [ ] Shows app in action
- [ ] No hands or device frames (for iOS)
- [ ] Matches required dimensions

---

## Store Listing

### App Name

- [ ] Unique and memorable
- [ ] 30 characters max (iOS) / 50 characters max (Android)
- [ ] No keyword stuffing
- [ ] Not trademarked by others

### Subtitle (iOS) / Short Description (Android)

- [ ] 30 characters (iOS) / 80 characters (Android)
- [ ] Compelling value proposition
- [ ] Keywords included naturally

### Description

- [ ] 4000 characters max
- [ ] First 1-3 lines are compelling (shown before "Read More")
- [ ] Key features listed clearly
- [ ] Benefits over features emphasized
- [ ] Call to action included
- [ ] Subscription details (if applicable)
- [ ] No competitor mentions
- [ ] No guaranteed results claims

### Keywords (iOS Only)

- [ ] 100 characters max
- [ ] Comma-separated, no spaces after commas
- [ ] Relevant keywords only
- [ ] No trademarked terms
- [ ] No duplicate words from title

### Category

- [ ] Primary category selected
- [ ] Secondary category selected (if applicable)
- [ ] Categories match app function

---

## Legal Requirements

### Privacy Policy

- [ ] Privacy policy URL is live
- [ ] Accessible from app
- [ ] Covers all data collection
- [ ] GDPR compliant (if serving EU)
- [ ] CCPA compliant (if serving California)
- [ ] Mentions third-party services (analytics, ads, etc.)

### Terms of Service

- [ ] Terms URL is live
- [ ] Covers user conduct
- [ ] Covers payment/subscription terms
- [ ] Covers intellectual property
- [ ] Covers limitation of liability

### App Privacy (iOS)

- [ ] Privacy questionnaire completed
- [ ] All data types declared:
  - [ ] Contact info
  - [ ] Health & fitness
  - [ ] Financial info
  - [ ] Location
  - [ ] Sensitive info
  - [ ] Contacts
  - [ ] User content
  - [ ] Browsing history
  - [ ] Search history
  - [ ] Identifiers
  - [ ] Usage data
  - [ ] Diagnostics

### Data Safety (Android)

- [ ] Data safety form completed
- [ ] Data collection disclosed
- [ ] Data sharing disclosed
- [ ] Security practices described

---

## In-App Purchases (If Applicable)

### Products Created

- [ ] All subscription tiers created
- [ ] Product IDs match between stores and RevenueCat
- [ ] Pricing set correctly
- [ ] Free trial configured (if offering)
- [ ] Subscription group created (iOS)

### Subscription Disclosure

- [ ] Subscription terms in app description
- [ ] Price and billing period clear
- [ ] Cancellation policy explained
- [ ] Links to manage subscription

### Testing

- [ ] Sandbox testing completed (iOS)
- [ ] License testing completed (Android)
- [ ] Purchase flow works
- [ ] Restore purchases works

---

## Technical Requirements

### iOS Specific

- [ ] Supports latest iOS version
- [ ] Supports iPhone and iPad (if universal)
- [ ] No private API usage
- [ ] No hot code loading (OTA JS updates are OK for Expo)
- [ ] Export compliance answered
- [ ] IDFA usage declared (if applicable)

### Android Specific

- [ ] Targets current API level (34+)
- [ ] 64-bit support included
- [ ] Permissions justified
- [ ] Content rating completed
- [ ] Target audience declared

### Both Platforms

- [ ] App loads within 5 seconds
- [ ] No crash on launch
- [ ] Works offline (graceful degradation)
- [ ] Error messages are user-friendly
- [ ] No broken links

---

## Build and Submit

### EAS Configuration

- [ ] `eas.json` configured correctly
- [ ] Production profile set up
- [ ] Credentials configured
- [ ] Version and build number updated

### iOS Build

```bash
eas build --platform ios --profile production
```

- [ ] Build succeeds
- [ ] No code signing errors
- [ ] Bundle identifier matches App Store Connect

### Android Build

```bash
eas build --platform android --profile production
```

- [ ] Build succeeds
- [ ] AAB format (not APK)
- [ ] Package name matches Play Console

### Submission

```bash
eas submit --platform ios
eas submit --platform android
```

- [ ] Submitted successfully
- [ ] Build selected in store console
- [ ] All metadata saved

---

## Pre-Review Checks

### iOS Review Guidelines

- [ ] No crashes
- [ ] Complete features (no "coming soon")
- [ ] No placeholder content
- [ ] Age rating appropriate
- [ ] In-app purchases work
- [ ] Demo account provided (if login required)
- [ ] App review notes added

### Android Review Guidelines

- [ ] No crashes
- [ ] Complete features
- [ ] Data safety accurate
- [ ] Content rating appropriate
- [ ] All store listing fields complete

---

## Review Process

### Expected Timeline

| Store | First Review | Updates |
|-------|--------------|---------|
| App Store | 24-48 hours | 24 hours |
| Play Store | 1-3 days | 1-3 days |

### If Rejected

- [ ] Read rejection reason carefully
- [ ] Fix the specific issue mentioned
- [ ] Reply to review if clarification needed
- [ ] Resubmit with detailed notes
- [ ] Escalate to App Review Board if unfair (iOS)

---

## Post-Approval

- [ ] Verify app appears in store search
- [ ] Test download on real device
- [ ] Test in-app purchases in production
- [ ] Set up crash monitoring
- [ ] Plan first update based on feedback

---

## Quick Reference

### Apple Developer Links

- [App Store Connect](https://appstoreconnect.apple.com)
- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)

### Google Play Links

- [Play Console](https://play.google.com/console)
- [Developer Policy Center](https://play.google.com/about/developer-content-policy/)
- [Material Design Guidelines](https://material.io/design)
