# Cost Breakdown

Everything you'll spend to launch three apps, from zero users to first revenue.

## Upfront Costs (Required)

| Item | Cost | Frequency | Notes |
|------|------|-----------|-------|
| Apple Developer Account | $99 | Yearly | Required to publish on App Store |
| Google Play Developer | $25 | One-time | Required to publish on Play Store |
| **Total Upfront** | **$124** | | |

That's it. Everything else has free tiers.

---

## Domain Costs (Per App)

| TLD | Typical Price | Notes |
|-----|--------------|-------|
| .com | $10-12/year | Good names taken, but cheapest |
| .app | $14-16/year | Modern, requires HTTPS (good) |
| .io | $35-50/year | Developer favorite, expensive |
| .co | $10-12/year | Short, startup-y |

**Recommended**: Buy `.app` domains on Cloudflare for ~$14/year each.

**3 apps × $14 = $42/year for domains**

---

## Service Free Tiers

### Expo / EAS
| Feature | Free Tier | Paid |
|---------|-----------|------|
| EAS Build | 30 builds/month | $99/mo for 100+ |
| EAS Submit | Unlimited | - |
| EAS Update | 10,000 updates/month | - |

**When to upgrade**: Only if you're pushing more than 30 builds/month (rare during learning).

### Supabase
| Feature | Free Tier | When You Hit Limits |
|---------|-----------|---------------------|
| Database | 500 MB | Upgrade at $25/mo |
| File Storage | 1 GB | Upgrade at $25/mo |
| Bandwidth | 2 GB/month | Upgrade at $25/mo |
| Edge Functions | 500K invocations | Upgrade at $25/mo |
| Auth | 50K MAU | Upgrade at $25/mo |

**When to upgrade**: Likely around 1000+ daily active users.

### Vercel
| Feature | Free Tier | Paid |
|---------|-----------|------|
| Bandwidth | 100 GB/month | $20/mo for 1TB |
| Deployments | Unlimited | - |
| Custom Domains | Unlimited | - |
| Preview Deploys | Unlimited | - |

**When to upgrade**: Rarely needed for indie apps.

### Stripe
| Feature | Free Tier | Paid |
|---------|-----------|------|
| Development/Testing | Free | - |
| Live Transactions | 2.9% + $0.30 per transaction | - |

No monthly fees. You only pay when you make money.

### RevenueCat
| Revenue | Free Tier | Paid |
|---------|-----------|------|
| Up to $2,500 MTR | $0 | - |
| Above $2,500 MTR | 1% of MTR | - |

MTR = Monthly Tracked Revenue (what flows through RevenueCat).

**When to upgrade**: When you're making $2,500+/month. Nice problem to have.

### Cloudflare
| Feature | Free Tier | Paid |
|---------|-----------|------|
| DNS | Unlimited | - |
| SSL | Unlimited | - |
| Email Routing | 200/day forward | - |
| DDoS Protection | Included | - |

Everything you need is free except domain registration.

---

## Optional Costs

### External APIs (App 2 - QuickNote)

**OpenAI Whisper** (audio transcription):
- $0.006 per minute of audio
- 100 transcriptions × 2 min avg = $1.20/month

**OpenAI GPT-4o-mini** (text processing):
- $0.15 per 1M input tokens
- ~$0.001 per note processing
- 100 notes/month = $0.10/month

**Estimated App 2 API cost**: ~$2-5/month during development

### Error Tracking (Sentry)
| Feature | Free Tier | Paid |
|---------|-----------|------|
| Errors | 5,000/month | $26/mo for 50K |
| Performance | 10K transactions | - |

Free tier is plenty for early stage.

### Analytics (PostHog, Mixpanel, etc.)
| Feature | Free Tier |
|---------|-----------|
| PostHog | 1M events/month |
| Mixpanel | 20M events/month |
| Amplitude | 10M events/month |

All have generous free tiers.

---

## Year 1 Total Cost Estimate

### Minimum (Free Tiers + Required)
| Item | Cost |
|------|------|
| Apple Developer | $99 |
| Google Play Developer | $25 |
| 3 Domains (.app) | $42 |
| **Total** | **$166** |

### Realistic (Some API Usage)
| Item | Cost |
|------|------|
| Minimum above | $166 |
| OpenAI API (App 2) | ~$50 |
| **Total** | **~$216** |

### If Apps Take Off
| Item | Monthly |
|------|---------|
| Supabase Pro | $25 |
| RevenueCat (if >$2.5K MTR) | 1% of revenue |
| Sentry (if needed) | $26 |

You'd only pay these after you have significant users/revenue.

---

## Cost Optimization Tips

1. **Use EAS builds wisely**: Development builds last until you change native dependencies. Don't rebuild for JS-only changes (use EAS Update).

2. **Supabase project per app**: Don't cram everything into one project. Separate databases are cleaner and you get 500MB each.

3. **Cloudflare for everything**: Free DNS, free SSL, cheap domains. No reason to use anything else for indie apps.

4. **RevenueCat's free tier is generous**: $2,500/month in revenue before you pay anything. Focus on getting there first.

5. **OpenAI API caching**: Cache transcription results. Don't re-transcribe the same audio.

---

## Break-Even Analysis

**Fixed costs**: ~$166/year = $14/month

**To break even with a $2.99/month subscription**:
- Apple takes 30% (first year) or 15% (after year 1)
- You get ~$2.09 per subscriber
- Need ~7 subscribers to break even

**To cover costs + $100/month profit**:
- Need ~55 subscribers at $2.99/month

These are very achievable numbers.

---

## When to Upgrade Services

| Trigger | Action |
|---------|--------|
| >500MB database | Upgrade Supabase |
| >30 EAS builds/month | Consider EAS subscription |
| >$2,500 MTR | RevenueCat starts charging 1% |
| Production errors increasing | Add Sentry paid tier |
| Need team collaboration | Upgrade Vercel/Supabase teams |

**Rule of thumb**: Upgrade only when free tier limits are actually blocking you, not in anticipation.

---

## Payment Timeline

| When | What | Cost |
|------|------|------|
| Week 0 | Apple Developer | $99 |
| Week 0 | Google Play Developer | $25 |
| Week 1 | First domain | $14 |
| Week 4 | OpenAI API | ~$10 |
| Week 4 | Second domain | $14 |
| Week 6 | Third domain | $14 |

**Total through curriculum**: ~$176

Everything else is post-launch and scales with revenue.
