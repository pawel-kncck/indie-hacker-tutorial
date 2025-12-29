# Deployment Pipeline

How to deploy your app to web, iOS, and Android. Follow the "deploy first" philosophy.

## Overview

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   Your Code     │────▶│    Git Push     │────▶│   Auto Deploy   │
└─────────────────┘     └─────────────────┘     └─────────────────┘
                                                        │
                              ┌─────────────────────────┼─────────────────────────┐
                              ▼                         ▼                         ▼
                        ┌──────────┐              ┌──────────┐              ┌──────────┐
                        │  Vercel  │              │ EAS iOS  │              │EAS Android│
                        │   Web    │              │  Build   │              │  Build   │
                        └──────────┘              └──────────┘              └──────────┘
                              │                         │                         │
                              ▼                         ▼                         ▼
                        ┌──────────┐              ┌──────────┐              ┌──────────┐
                        │  Live    │              │App Store │              │Play Store│
                        │ Website  │              │ Connect  │              │ Console  │
                        └──────────┘              └──────────┘              └──────────┘
```

---

## Part 1: Web Deployment (Vercel)

### Initial Setup

1. **Push your code to GitHub**
   ```bash
   git init
   git add .
   git commit -m "Initial commit"
   gh repo create my-app --public --push
   # Or create repo on github.com and push manually
   ```

2. **Connect to Vercel**
   - Go to https://vercel.com/new
   - Import your GitHub repository
   - Vercel auto-detects Expo and configures build

3. **Set Environment Variables**
   - In Vercel dashboard: Settings → Environment Variables
   - Add your Supabase keys:
     ```
     EXPO_PUBLIC_SUPABASE_URL=https://xxx.supabase.co
     EXPO_PUBLIC_SUPABASE_ANON_KEY=eyJhbGci...
     ```

4. **Deploy**
   - Happens automatically on push to `main`
   - Or trigger manually: `vercel --prod`

### Custom Domain

1. **Buy domain on Cloudflare**
   - Go to https://dash.cloudflare.com
   - Registrar → Register Domain
   - Search and purchase (e.g., dailywin.app)

2. **Connect to Vercel**
   - Vercel dashboard: Settings → Domains
   - Add your domain
   - Vercel shows DNS records to add

3. **Configure Cloudflare DNS**
   - Add CNAME record: `@` → `cname.vercel-dns.com`
   - Or A records if Vercel provides them
   - Enable "Proxy" for DDoS protection

4. **Verify**
   - Takes a few minutes for DNS propagation
   - Vercel auto-provisions SSL certificate

### Deployment Workflow

After initial setup, deployment is automatic:

```bash
# Make changes
git add .
git commit -m "Add feature X"
git push

# Vercel automatically deploys
# Preview URL for PRs, production for main branch
```

---

## Part 2: Mobile Deployment (EAS)

### Initial Setup

1. **Configure EAS**
   ```bash
   cd my-app
   eas init
   ```
   This creates `eas.json` with build profiles.

2. **Configure app.json**
   ```json
   {
     "expo": {
       "name": "DailyWin",
       "slug": "dailywin",
       "version": "1.0.0",
       "ios": {
         "bundleIdentifier": "com.yourstudio.dailywin",
         "buildNumber": "1"
       },
       "android": {
         "package": "com.yourstudio.dailywin",
         "versionCode": 1
       }
     }
   }
   ```

3. **Set up credentials**
   
   EAS can manage credentials automatically (recommended):
   ```bash
   eas credentials
   ```
   
   Or configure manually in eas.json.

### Build Profiles

`eas.json`:

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
      "distribution": "internal"
    },
    "production": {}
  },
  "submit": {
    "production": {}
  }
}
```

| Profile | Purpose | Distribution |
|---------|---------|--------------|
| `development` | Dev builds with dev tools | Internal (TestFlight/internal track) |
| `preview` | Test builds for stakeholders | Internal |
| `production` | Store releases | App Store / Play Store |

### Development Builds

For testing on physical devices:

```bash
# Build for both platforms
eas build --profile development --platform all

# Or just one platform
eas build --profile development --platform ios
eas build --profile development --platform android
```

After build completes:
- iOS: Install via TestFlight (or scan QR for ad-hoc)
- Android: Download APK directly

### Production Builds

```bash
# Build production versions
eas build --profile production --platform all
```

This creates:
- iOS: `.ipa` file signed for App Store
- Android: `.aab` (Android App Bundle) for Play Store

### Submitting to Stores

```bash
# Submit to both stores
eas submit --platform all

# Or individually
eas submit --platform ios
eas submit --platform android
```

EAS Submit handles:
- Uploading to App Store Connect / Play Console
- You still need to complete metadata in store dashboards

---

## Part 3: Store Configuration

### App Store Connect (iOS)

1. **Create App**
   - Go to https://appstoreconnect.apple.com
   - My Apps → + → New App
   - Fill in: name, primary language, bundle ID, SKU

2. **App Information**
   - Privacy Policy URL (required)
   - Category
   - Age rating questionnaire

3. **Prepare for Submission**
   - Screenshots (required sizes below)
   - App description, keywords
   - Support URL
   - Version info

4. **Submit for Review**
   - After EAS Submit uploads the build
   - Select build, add release notes
   - Submit for review

**Required Screenshots:**

| Device | Size |
|--------|------|
| iPhone 6.7" | 1290 × 2796 |
| iPhone 6.5" | 1284 × 2778 |
| iPhone 5.5" | 1242 × 2208 |
| iPad Pro 12.9" | 2048 × 2732 |

### Google Play Console (Android)

1. **Create App**
   - Go to https://play.google.com/console
   - All apps → Create app
   - Fill in details, agree to policies

2. **Dashboard Checklist**
   - App access (does it require login?)
   - Ads declaration
   - Content rating questionnaire
   - Target audience
   - Privacy policy

3. **Store Listing**
   - Title, descriptions
   - Graphics (icon, feature graphic, screenshots)
   - Category

4. **Release**
   - Production → Create new release
   - Upload AAB (or let EAS Submit do it)
   - Add release notes
   - Review and roll out

**Required Graphics:**

| Asset | Size |
|-------|------|
| App icon | 512 × 512 |
| Feature graphic | 1024 × 500 |
| Phone screenshots | Min 320px, max 3840px |
| Tablet screenshots | 7" and 10" |

---

## Part 4: OTA Updates

Update JavaScript without app store review.

### When to Use OTA Updates

✅ **Use for:**
- Bug fixes in JS code
- UI changes
- New screens (if not requiring new native modules)
- Content updates

❌ **Don't use for:**
- Changes to native modules
- New Expo SDK features
- app.json changes (icon, splash, etc.)

### Publish an Update

```bash
# Create and publish update
eas update --branch production --message "Fix login bug"
```

Users get the update next time they open the app.

### Configure Update Behavior

In `app.json`:

```json
{
  "expo": {
    "updates": {
      "url": "https://u.expo.dev/your-project-id",
      "fallbackToCacheTimeout": 0
    },
    "runtimeVersion": {
      "policy": "sdkVersion"
    }
  }
}
```

### Update Strategies

```javascript
import * as Updates from 'expo-updates';

// Check for updates on app start
useEffect(() => {
  async function checkUpdates() {
    const update = await Updates.checkForUpdateAsync();
    if (update.isAvailable) {
      await Updates.fetchUpdateAsync();
      // Optionally restart to apply
      await Updates.reloadAsync();
    }
  }
  checkUpdates();
}, []);
```

---

## Part 5: Environment Management

### Environment Variables per Build

`eas.json`:

```json
{
  "build": {
    "development": {
      "env": {
        "EXPO_PUBLIC_API_URL": "https://dev-api.myapp.com"
      }
    },
    "production": {
      "env": {
        "EXPO_PUBLIC_API_URL": "https://api.myapp.com"
      }
    }
  }
}
```

### Secrets (Not in Code)

```bash
# Set a secret in EAS
eas secret:create --name STRIPE_SECRET_KEY --value sk_live_xxx --scope project

# Use in eas.json
{
  "build": {
    "production": {
      "env": {
        "STRIPE_SECRET_KEY": "@STRIPE_SECRET_KEY"
      }
    }
  }
}
```

---

## Version Management

### Version vs Build Number

| Field | Purpose | When to Update |
|-------|---------|----------------|
| `version` | User-facing (1.0.0) | New features, major fixes |
| `buildNumber` / `versionCode` | Store tracking | Every submission |

### Auto-increment Build Number

`eas.json`:

```json
{
  "build": {
    "production": {
      "autoIncrement": true
    }
  }
}
```

Or use `app.config.js` for dynamic versioning:

```javascript
export default {
  expo: {
    version: "1.0.0",
    ios: {
      buildNumber: process.env.BUILD_NUMBER || "1",
    },
    android: {
      versionCode: parseInt(process.env.BUILD_NUMBER || "1"),
    },
  },
};
```

---

## CI/CD with GitHub Actions

Automate builds on push:

`.github/workflows/eas-build.yml`:

```yaml
name: EAS Build

on:
  push:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - uses: actions/setup-node@v3
        with:
          node-version: 18
          
      - name: Setup EAS
        uses: expo/expo-github-action@v8
        with:
          eas-version: latest
          token: ${{ secrets.EXPO_TOKEN }}
          
      - name: Install dependencies
        run: npm ci
        
      - name: Build and submit
        run: eas build --platform all --non-interactive --auto-submit
```

Create `EXPO_TOKEN` in Expo dashboard and add to GitHub secrets.

---

## Quick Reference

### Daily Development
```bash
npx expo start          # Start dev server
git push                # Auto-deploys web to Vercel
```

### Testing on Device
```bash
eas build --profile development --platform ios
# Install via TestFlight
```

### Releasing to Stores
```bash
# Bump version in app.json
eas build --profile production --platform all
eas submit --platform all
# Complete in App Store Connect / Play Console
```

### Hot Fix (OTA)
```bash
eas update --branch production --message "Fix critical bug"
```

---

## Next Steps

1. Deploy your first web build to Vercel
2. Create a development build with EAS
3. Start [App 1: DailyWin](../02-apps/app1-dailywin/README.md)
