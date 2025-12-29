# Local Environment Setup

Your development machine configuration. Works on macOS, Windows, or Linux.

## Required Software

### 1. Node.js (v18 or later)

**Check if installed**:
```bash
node --version  # Should show v18.x.x or higher
```

**Install** (if needed):
- **macOS**: `brew install node` or download from https://nodejs.org
- **Windows**: Download from https://nodejs.org
- **Linux**: Use nvm (see below)

**Recommended**: Use nvm (Node Version Manager) for easy version switching:
```bash
# Install nvm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash

# Install latest LTS
nvm install --lts
nvm use --lts
```

---

### 2. EAS CLI

```bash
npm install -g eas-cli
```

**Verify**:
```bash
eas --version
```

**Login**:
```bash
eas login
```

---

### 3. Git

**Check if installed**:
```bash
git --version
```

**Install** (if needed):
- **macOS**: `xcode-select --install` (installs git with Xcode tools)
- **Windows**: Download from https://git-scm.com
- **Linux**: `sudo apt install git`

**Configure**:
```bash
git config --global user.name "Your Name"
git config --global user.email "your@email.com"
```

---

### 4. VS Code (Recommended Editor)

**Download**: https://code.visualstudio.com

**Essential Extensions**:
- **ES7+ React/Redux/React-Native snippets** - Code snippets
- **Expo Tools** - Expo-specific features
- **Prettier** - Code formatting
- **ESLint** - Linting
- **GitLens** - Git integration
- **Thunder Client** - API testing (alternative to Postman)

**Recommended Settings** (add to settings.json):
```json
{
  "editor.formatOnSave": true,
  "editor.defaultFormatter": "esbenp.prettier-vscode",
  "editor.tabSize": 2,
  "files.trimTrailingWhitespace": true,
  "typescript.preferences.importModuleSpecifier": "relative"
}
```

---

### 5. Expo Go App (for Development Testing)

Install on your physical devices:
- **iOS**: Search "Expo Go" in App Store
- **Android**: Search "Expo Go" in Play Store

This lets you run your development builds on real devices without going through app stores.

---

## Optional but Recommended

### Simulators/Emulators

For testing when you don't have a physical device handy.

**iOS Simulator (macOS only)**:
```bash
# Install Xcode from Mac App Store, then:
xcode-select --install
sudo xcodebuild -license accept

# Open simulator
open -a Simulator
```

**Android Emulator**:
1. Download Android Studio: https://developer.android.com/studio
2. Open Android Studio → More Actions → Virtual Device Manager
3. Create a device (Pixel 6 with latest Android recommended)
4. You can run the emulator without opening Android Studio:
```bash
# Find emulator path (macOS)
~/Library/Android/sdk/emulator/emulator -list-avds
~/Library/Android/sdk/emulator/emulator -avd <avd_name>
```

**Note**: You don't need Xcode or Android Studio for production builds (EAS handles that). These are only for local development testing.

---

### Supabase CLI (for Local Development)

```bash
npm install -g supabase
```

Useful for:
- Running Supabase locally (PostgreSQL, Auth, etc.)
- Database migrations
- Generating TypeScript types from your schema

**Verify**:
```bash
supabase --version
```

---

### Watchman (macOS, for Better File Watching)

```bash
brew install watchman
```

Improves hot reload performance on macOS.

---

## Project Structure Recommendation

```
~/projects/
├── indie-hacker-curriculum/     # This curriculum
├── dailywin/                    # App 1
├── quicknote/                   # App 2
└── synccal/                     # App 3
```

Each app is a separate git repository.

---

## Environment Variables Strategy

**Never commit secrets to git.** Use this pattern:

1. Create `.env` for local development (gitignored)
2. Create `.env.example` with placeholder values (committed)
3. Set production values in Vercel/EAS dashboards

**Example .env**:
```bash
EXPO_PUBLIC_SUPABASE_URL=https://xxx.supabase.co
EXPO_PUBLIC_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIs...
```

**Important**: Expo requires `EXPO_PUBLIC_` prefix for client-accessible variables.

---

## Verify Everything Works

Run this checklist:

```bash
# Node
node --version
# ✅ v18.x.x or higher

# npm
npm --version
# ✅ 9.x.x or higher

# EAS CLI
eas --version
# ✅ eas-cli/x.x.x

# EAS Login
eas whoami
# ✅ Your username

# Git
git --version
# ✅ git version 2.x.x

# Create test project
npx create-expo-app@latest test-app
cd test-app
npx expo start
# ✅ QR code appears, can scan with Expo Go
```

If all checks pass, you're ready to start building.

---

## Troubleshooting Common Setup Issues

### "npm EACCES permission denied"
```bash
# Fix npm permissions
sudo chown -R $(whoami) ~/.npm
```

### "eas: command not found"
```bash
# Ensure global npm bin is in PATH
export PATH="$PATH:$(npm config get prefix)/bin"
# Add to ~/.zshrc or ~/.bashrc to persist
```

### "Cannot find module 'expo'"
```bash
# Clear npm cache and reinstall
npm cache clean --force
rm -rf node_modules
npm install
```

### Expo Go can't connect to dev server
- Ensure phone and computer are on same WiFi network
- Try tunnel mode: `npx expo start --tunnel`
- Check firewall isn't blocking port 19000

---

## Next Steps

Once your environment is set up:
1. Review [cost-breakdown.md](./cost-breakdown.md)
2. Start [01-foundations/expo-essentials.md](../01-foundations/expo-essentials.md)
