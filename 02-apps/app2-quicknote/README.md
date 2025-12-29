# App 2: QuickNote - Voice Notes with AI Transcription

Your second app. Introduces file storage, Edge Functions, and external API integration.

## Overview

| Attribute | Value |
|-----------|-------|
| **Timeline** | Weeks 4-5 |
| **Complexity** | Intermediate |
| **Revenue Model** | Freemium (5 notes/mo free, unlimited = $4.99/mo) |
| **Platforms** | Web, iOS, Android |

## The Product

QuickNote lets users record voice memos that are automatically transcribed and summarized using AI.

**Core Features:**
- One-tap voice recording
- Automatic transcription (Whisper API)
- AI-powered summaries (GPT-4)
- Organized note library
- Search across all notes

**Why This App:**
- Solves a real problem (quick capture)
- Introduces file storage patterns
- Edge Functions for API integration
- Clear premium value (more notes, faster processing)

---

## Tech Stack Additions

| Component | Technology | Why |
|-----------|------------|-----|
| Audio Recording | expo-av | Cross-platform audio |
| File Storage | Supabase Storage | Audio files up to 50MB |
| Transcription | OpenAI Whisper | Best accuracy/price |
| Summarization | OpenAI GPT-4 | Quality summaries |
| Processing | Supabase Edge Functions | Serverless, no cold starts |

---

## Database Schema

```sql
-- Notes table
create table notes (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users(id) on delete cascade not null,
  title text,
  audio_url text,
  audio_duration integer, -- seconds
  transcript text,
  summary text,
  status text default 'recording', -- recording, processing, ready, error
  error_message text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- Indexes
create index idx_notes_user on notes(user_id);
create index idx_notes_status on notes(status);
create index idx_notes_created on notes(created_at desc);

-- Full-text search
alter table notes add column fts tsvector
  generated always as (
    to_tsvector('english', coalesce(title, '') || ' ' || coalesce(transcript, ''))
  ) stored;

create index idx_notes_fts on notes using gin(fts);

-- RLS
alter table notes enable row level security;

create policy "Users manage own notes"
  on notes for all
  using (auth.uid() = user_id);

-- Storage bucket
insert into storage.buckets (id, name, public)
values ('audio', 'audio', false);

create policy "Users upload own audio"
  on storage.objects for insert
  with check (
    bucket_id = 'audio' and
    auth.uid()::text = (storage.foldername(name))[1]
  );

create policy "Users read own audio"
  on storage.objects for select
  using (
    bucket_id = 'audio' and
    auth.uid()::text = (storage.foldername(name))[1]
  );
```

---

## Screen Map

```
(auth)
├── login.tsx
├── signup.tsx
└── forgot-password.tsx

(app)
├── (tabs)
│   ├── index.tsx          # Notes list with search
│   ├── record.tsx         # Recording screen (main CTA)
│   └── settings.tsx       # Account, subscription
├── note/
│   └── [id].tsx           # Note detail (transcript, audio playback)
└── paywall.tsx
```

---

## Week-by-Week Guide

### Week 4: Foundation + Audio

| Day | Focus | Deliverable |
|-----|-------|-------------|
| 1 | Project setup | Clone DailyWin patterns, new database |
| 2 | Audio recording | Record, pause, resume, save |
| 3 | File storage | Upload to Supabase Storage |
| 4 | Edge Functions | Basic function deployed |
| 5 | Transcription | Whisper integration working |

**Milestone:** Can record audio and see transcript

→ [01-audio-recording.md](./01-audio-recording.md)
→ [02-file-storage.md](./02-file-storage.md)
→ [03-edge-functions.md](./03-edge-functions.md)

### Week 5: AI + Launch

| Day | Focus | Deliverable |
|-----|-------|-------------|
| 1 | Summarization | GPT-4 summaries working |
| 2 | Polish | Loading states, error handling |
| 3 | Stripe | Web payments (mobile reuse RevenueCat) |
| 4 | Submit | Production builds to stores |
| 5 | Launch | App live, marketing push |

**Milestone:** Second app live with AI features

→ [04-external-apis.md](./04-external-apis.md)
→ [05-stripe-integration.md](./05-stripe-integration.md)

---

## Revenue Model

### Subscription Tiers

| Tier | Price | Limits |
|------|-------|--------|
| Free | $0 | 5 notes/month |
| Pro | $4.99/mo or $29.99/yr | Unlimited notes, priority processing |

### Usage Tracking

```sql
-- Track monthly usage
create table usage (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users(id) on delete cascade not null,
  month date not null, -- First of month
  notes_count integer default 0,

  unique(user_id, month)
);

-- Increment function
create or replace function increment_usage(p_user_id uuid)
returns void as $$
begin
  insert into usage (user_id, month, notes_count)
  values (p_user_id, date_trunc('month', now()), 1)
  on conflict (user_id, month)
  do update set notes_count = usage.notes_count + 1;
end;
$$ language plpgsql security definer;
```

---

## File Structure

```
quicknote/
├── app/
│   ├── _layout.tsx
│   ├── (auth)/
│   │   └── ...
│   ├── (app)/
│   │   ├── _layout.tsx
│   │   ├── (tabs)/
│   │   │   ├── _layout.tsx
│   │   │   ├── index.tsx       # Notes list
│   │   │   ├── record.tsx      # Recording
│   │   │   └── settings.tsx
│   │   ├── note/
│   │   │   └── [id].tsx
│   │   └── paywall.tsx
├── components/
│   ├── NoteCard.tsx
│   ├── RecordButton.tsx
│   ├── AudioPlayer.tsx
│   └── TranscriptView.tsx
├── contexts/
│   ├── AuthContext.tsx
│   └── SubscriptionContext.tsx
├── hooks/
│   ├── useNotes.ts
│   ├── useRecording.ts
│   └── useAudioPlayer.ts
├── lib/
│   ├── supabase.ts
│   └── audio.ts
├── supabase/
│   └── functions/
│       ├── transcribe/
│       │   └── index.ts
│       └── summarize/
│           └── index.ts
└── types/
    └── supabase.ts
```

---

## Key Learnings

After completing QuickNote, you'll understand:

1. **File Storage** - Upload, download, signed URLs
2. **Edge Functions** - Serverless backend logic
3. **External APIs** - Integrating third-party services
4. **Background Processing** - Handling long-running tasks
5. **Error Handling** - Graceful degradation

---

## API Costs Estimate

| Service | Free Tier | Paid |
|---------|-----------|------|
| OpenAI Whisper | - | ~$0.006/min |
| OpenAI GPT-4 | - | ~$0.03/1K tokens |
| Supabase Storage | 1GB | $0.021/GB |

**Per Note Cost:** ~$0.02-0.05 (1 min audio + summary)

With Pro at $4.99/month, break-even at ~100 notes/user.

---

## Guides

1. [Audio Recording](./01-audio-recording.md)
2. [File Storage](./02-file-storage.md)
3. [Edge Functions](./03-edge-functions.md)
4. [External APIs](./04-external-apis.md)
5. [Stripe Integration](./05-stripe-integration.md)

Start with [01-audio-recording.md](./01-audio-recording.md).
