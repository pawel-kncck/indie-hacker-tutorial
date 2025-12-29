# Accounts Checklist

Complete all accounts before starting development. Budget 2-4 hours total.

## Required Accounts

### 1. Apple Developer Account
**Cost**: $99/year  
**Time**: 10 min setup + up to 48 hours approval  
**URL**: https://developer.apple.com/programs/

**Steps**:
1. Sign in with your Apple ID (or create one)
2. Enroll in the Apple Developer Program
3. Choose Individual or Organization:
   - **Individual**: Your legal name is public on App Store
   - **Organization**: Business name is public (requires D-U-N-S number)
4. Pay the $99 fee
5. Wait for approval (usually 24-48 hours)

**Pro Tip**: Start with Individual to ship fast. You can migrate to Organization later.

**What You'll Need Later**:
- App Store Connect access (automatic with developer account)
- Certificates and provisioning profiles (EAS handles this)

---

### 2. Google Play Developer Account
**Cost**: $25 one-time  
**Time**: 10 min setup + up to 48 hours verification  
**URL**: https://play.google.com/console/signup

**Steps**:
1. Sign in with Google account
2. Accept the developer agreement
3. Pay the $25 registration fee
4. Complete identity verification (required since 2023)
5. Set up your developer profile (public name, email)

**Privacy Tip**: Use a studio/brand name as your developer name, and a dedicated email (not your personal one). This is allowed and recommended.

**What You'll Need Later**:
- Service account for automated uploads (EAS setup)
- Google Play Console access for releases

---

### 3. Expo Account
**Cost**: Free (paid tiers available)  
**Time**: 5 min  
**URL**: https://expo.dev/signup

**Steps**:
1. Go to expo.dev
2. Click "Sign Up"
3. Use your studio email
4. Choose a username (visible in URLs like expo.dev/@username)

**After Signup**:
```bash
# Install EAS CLI
npm install -g eas-cli

# Login from terminal
eas login

# Verify
eas whoami
```

---

### 4. Supabase Account
**Cost**: Free tier (generous limits)  
**Time**: 5 min  
**URL**: https://supabase.com

**Steps**:
1. Click "Start your project"
2. Sign up with GitHub (recommended) or email
3. You'll create specific projects later for each app

**Free Tier Includes**:
- 2 projects
- 500 MB database per project
- 1 GB file storage
- 50,000 monthly active users
- Unlimited API requests

---

### 5. Vercel Account
**Cost**: Free tier  
**Time**: 5 min  
**URL**: https://vercel.com/signup

**Steps**:
1. Sign up with GitHub (recommended for auto-deploy)
2. Authorize Vercel to access your repositories
3. You'll connect specific repos later

**Free Tier Includes**:
- 100 GB bandwidth/month
- Unlimited deployments
- Custom domains with SSL
- Preview deployments for PRs

---

### 6. Cloudflare Account
**Cost**: Free (domains cost extra)  
**Time**: 5 min  
**URL**: https://dash.cloudflare.com/sign-up

**Steps**:
1. Create account with email
2. You'll add domains later

**What's Free**:
- DNS hosting
- SSL certificates
- DDoS protection
- Email routing (forward to your main inbox)

---

### 7. Stripe Account
**Cost**: Free (2.9% + $0.30 per transaction)  
**Time**: 15 min  
**URL**: https://dashboard.stripe.com/register

**Steps**:
1. Create account
2. Verify email
3. You can use test mode immediately
4. Complete identity verification when ready to go live

**What You'll Need**:
- Publishable key (for frontend)
- Secret key (for backend/Edge Functions)
- Webhook signing secret (for events)

**Note**: Full verification requires business details and bank account, but you can develop in test mode without this.

---

### 8. RevenueCat Account
**Cost**: Free up to $2,500 MTR  
**Time**: 10 min  
**URL**: https://app.revenuecat.com/signup

**Steps**:
1. Create account
2. Create a new project for your first app
3. Connect App Store Connect and Google Play Console (later)

**What You'll Configure**:
- Products (subscriptions, one-time purchases)
- Entitlements (what premium access unlocks)
- Offerings (which products to show users)

---

### 9. GitHub Account (if you don't have one)
**Cost**: Free  
**Time**: 5 min  
**URL**: https://github.com/signup

**Why Needed**:
- Vercel auto-deploys from GitHub
- Code backup and version control
- EAS can trigger builds on push

---

## Optional but Recommended

### OpenAI Account (for App 2)
**Cost**: Pay-per-use (~$0.006/min for Whisper, ~$0.002/1K tokens for GPT-4o-mini)  
**URL**: https://platform.openai.com/signup

You'll need this for the voice transcription app. Create it when you reach Week 4.

### Sentry Account (for error tracking)
**Cost**: Free tier (5K errors/month)  
**URL**: https://sentry.io/signup

Good for production monitoring. Add when you're ready to launch.

### Google Cloud Console (for App 3)
**Cost**: Free tier covers most usage  
**URL**: https://console.cloud.google.com

Required for Google Calendar API OAuth. Create when you reach Week 6.

---

## Account Summary Table

| Account | Cost | Status |
|---------|------|--------|
| Apple Developer | $99/year | ☐ |
| Google Play Developer | $25 one-time | ☐ |
| Expo | Free | ☐ |
| Supabase | Free | ☐ |
| Vercel | Free | ☐ |
| Cloudflare | Free | ☐ |
| Stripe | Free | ☐ |
| RevenueCat | Free | ☐ |
| GitHub | Free | ☐ |

**Total Initial Cost**: $124 (covers your first year)

---

## Credentials to Save

Create a secure note (1Password, Bitwarden, etc.) with:

```
APPLE DEVELOPER
- Apple ID: 
- Team ID: (found in Membership details)

GOOGLE PLAY
- Developer Account ID:
- Service Account JSON: (save file securely)

EXPO
- Username:
- Access Token: (if created)

SUPABASE (per project)
- Project URL:
- Anon Key:
- Service Role Key:

VERCEL
- (uses GitHub OAuth)

CLOUDFLARE
- Account ID:
- API Token: (if created)

STRIPE
- Publishable Key (test):
- Secret Key (test):
- Publishable Key (live):
- Secret Key (live):
- Webhook Secret:

REVENUECAT
- API Key (public):
- API Key (secret):
```

You'll fill these in as you set up each service. Never commit these to git.
