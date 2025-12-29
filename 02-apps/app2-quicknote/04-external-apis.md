# 04 - External APIs

> Day 1-2 of Week 5: Advanced API integration patterns

## Overview

We'll cover:
- API key management
- Rate limiting
- Cost tracking
- Error handling patterns
- Caching strategies

---

## Step 1: Secure API Key Management

### Environment Variables

Store API keys in Supabase Edge Functions secrets:

```bash
# Set secrets
supabase secrets set OPENAI_API_KEY=sk-xxx
supabase secrets set OPENAI_ORG_ID=org-xxx

# List secrets
supabase secrets list
```

### Never Expose Keys Client-Side

All API calls go through Edge Functions:

```
Client → Edge Function → External API
                ↓
          Response → Client
```

## Step 2: Rate Limiting

### Implement Token Bucket

Create `supabase/functions/_shared/rate-limiter.ts`:

```typescript
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

type RateLimitResult = {
  allowed: boolean;
  remaining: number;
  resetAt: Date;
};

export async function checkRateLimit(
  userId: string,
  limit: number = 10,
  windowMs: number = 60000
): Promise<RateLimitResult> {
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  );

  const now = Date.now();
  const windowStart = new Date(now - windowMs).toISOString();

  // Count recent requests
  const { count } = await supabase
    .from('api_requests')
    .select('*', { count: 'exact', head: true })
    .eq('user_id', userId)
    .gte('created_at', windowStart);

  const remaining = Math.max(0, limit - (count || 0));
  const allowed = remaining > 0;

  if (allowed) {
    // Log this request
    await supabase.from('api_requests').insert({
      user_id: userId,
      endpoint: 'transcribe',
      created_at: new Date().toISOString(),
    });
  }

  return {
    allowed,
    remaining,
    resetAt: new Date(now + windowMs),
  };
}
```

### Rate Limit Table

```sql
create table api_requests (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users(id) on delete cascade,
  endpoint text not null,
  created_at timestamptz default now()
);

create index idx_api_requests_user_time on api_requests(user_id, created_at desc);

-- Cleanup old records daily
create or replace function cleanup_old_requests()
returns void as $$
begin
  delete from api_requests where created_at < now() - interval '1 day';
end;
$$ language plpgsql;
```

## Step 3: Cost Tracking

### Track API Usage

```sql
create table api_usage (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users(id) on delete cascade,
  service text not null, -- 'openai_whisper', 'openai_gpt4'
  tokens_used integer,
  cost_usd numeric(10, 6),
  metadata jsonb,
  created_at timestamptz default now()
);

create index idx_api_usage_user_month on api_usage(user_id, created_at);
```

### Log Usage in Functions

```typescript
async function logUsage(
  supabase: any,
  userId: string,
  service: string,
  tokens: number,
  cost: number,
  metadata?: Record<string, any>
) {
  await supabase.from('api_usage').insert({
    user_id: userId,
    service,
    tokens_used: tokens,
    cost_usd: cost,
    metadata,
  });
}

// In transcribe function:
const audioDurationMinutes = note.audio_duration / 60;
const whisperCost = audioDurationMinutes * 0.006; // $0.006/min

await logUsage(
  supabase,
  note.user_id,
  'openai_whisper',
  0,
  whisperCost,
  { duration_seconds: note.audio_duration }
);
```

### Monthly Usage Dashboard

```typescript
export async function getMonthlyUsage(userId: string) {
  const supabase = createClient(/*...*/);

  const startOfMonth = new Date();
  startOfMonth.setDate(1);
  startOfMonth.setHours(0, 0, 0, 0);

  const { data } = await supabase
    .from('api_usage')
    .select('service, tokens_used, cost_usd')
    .eq('user_id', userId)
    .gte('created_at', startOfMonth.toISOString());

  const usage = {
    whisper: { count: 0, cost: 0 },
    gpt4: { count: 0, cost: 0, tokens: 0 },
    total: 0,
  };

  for (const row of data || []) {
    if (row.service === 'openai_whisper') {
      usage.whisper.count++;
      usage.whisper.cost += parseFloat(row.cost_usd);
    } else if (row.service === 'openai_gpt4') {
      usage.gpt4.count++;
      usage.gpt4.cost += parseFloat(row.cost_usd);
      usage.gpt4.tokens += row.tokens_used;
    }
    usage.total += parseFloat(row.cost_usd);
  }

  return usage;
}
```

## Step 4: Error Handling Patterns

### Retry with Exponential Backoff

```typescript
interface RetryOptions {
  maxRetries: number;
  baseDelayMs: number;
  maxDelayMs: number;
}

async function withRetry<T>(
  fn: () => Promise<T>,
  options: RetryOptions = { maxRetries: 3, baseDelayMs: 1000, maxDelayMs: 10000 }
): Promise<T> {
  let lastError: Error | null = null;

  for (let attempt = 0; attempt < options.maxRetries; attempt++) {
    try {
      return await fn();
    } catch (error) {
      lastError = error as Error;

      // Don't retry on client errors (4xx)
      if (error.status >= 400 && error.status < 500) {
        throw error;
      }

      const delay = Math.min(
        options.baseDelayMs * Math.pow(2, attempt),
        options.maxDelayMs
      );

      console.log(`Attempt ${attempt + 1} failed, retrying in ${delay}ms`);
      await new Promise((resolve) => setTimeout(resolve, delay));
    }
  }

  throw lastError;
}
```

### Circuit Breaker

```typescript
class CircuitBreaker {
  private failures = 0;
  private lastFailure: number = 0;
  private state: 'closed' | 'open' | 'half-open' = 'closed';

  constructor(
    private threshold: number = 5,
    private resetTimeMs: number = 30000
  ) {}

  async execute<T>(fn: () => Promise<T>): Promise<T> {
    if (this.state === 'open') {
      if (Date.now() - this.lastFailure > this.resetTimeMs) {
        this.state = 'half-open';
      } else {
        throw new Error('Circuit breaker is open');
      }
    }

    try {
      const result = await fn();
      this.onSuccess();
      return result;
    } catch (error) {
      this.onFailure();
      throw error;
    }
  }

  private onSuccess() {
    this.failures = 0;
    this.state = 'closed';
  }

  private onFailure() {
    this.failures++;
    this.lastFailure = Date.now();

    if (this.failures >= this.threshold) {
      this.state = 'open';
    }
  }
}

// Usage
const openaiCircuit = new CircuitBreaker(5, 30000);

const result = await openaiCircuit.execute(async () => {
  return await callOpenAI(params);
});
```

## Step 5: Caching

### Cache Responses

```sql
create table api_cache (
  id uuid default gen_random_uuid() primary key,
  cache_key text unique not null,
  response jsonb not null,
  expires_at timestamptz not null,
  created_at timestamptz default now()
);

create index idx_cache_key on api_cache(cache_key);
create index idx_cache_expires on api_cache(expires_at);
```

### Cache Helper

```typescript
async function withCache<T>(
  key: string,
  fn: () => Promise<T>,
  ttlSeconds: number = 3600
): Promise<T> {
  const supabase = createClient(/*...*/);

  // Check cache
  const { data: cached } = await supabase
    .from('api_cache')
    .select('response')
    .eq('cache_key', key)
    .gt('expires_at', new Date().toISOString())
    .single();

  if (cached) {
    return cached.response as T;
  }

  // Call function
  const result = await fn();

  // Store in cache
  await supabase
    .from('api_cache')
    .upsert({
      cache_key: key,
      response: result,
      expires_at: new Date(Date.now() + ttlSeconds * 1000).toISOString(),
    });

  return result;
}

// Usage
const summary = await withCache(
  `summary:${noteId}`,
  () => generateSummary(transcript),
  86400 // 24 hours
);
```

## Step 6: Streaming Responses

For real-time transcription feedback:

```typescript
serve(async (req) => {
  const encoder = new TextEncoder();

  const stream = new ReadableStream({
    async start(controller) {
      // Send progress updates
      controller.enqueue(
        encoder.encode(`data: {"status": "uploading"}\n\n`)
      );

      // Process audio
      const transcript = await transcribeAudio(audioBlob);

      controller.enqueue(
        encoder.encode(`data: {"status": "transcribed", "text": "${transcript}"}\n\n`)
      );

      // Generate summary
      const summary = await generateSummary(transcript);

      controller.enqueue(
        encoder.encode(`data: {"status": "complete", "summary": "${summary}"}\n\n`)
      );

      controller.close();
    },
  });

  return new Response(stream, {
    headers: {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache',
      'Connection': 'keep-alive',
    },
  });
});
```

## Step 7: Client-Side Handling

```typescript
// In your React component
const processNote = async (noteId: string) => {
  const response = await fetch(
    `${SUPABASE_URL}/functions/v1/process-stream`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${session.access_token}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ noteId }),
    }
  );

  const reader = response.body?.getReader();
  const decoder = new TextDecoder();

  while (true) {
    const { done, value } = await reader!.read();
    if (done) break;

    const text = decoder.decode(value);
    const lines = text.split('\n\n');

    for (const line of lines) {
      if (line.startsWith('data: ')) {
        const data = JSON.parse(line.slice(6));
        setStatus(data.status);
        if (data.text) setTranscript(data.text);
        if (data.summary) setSummary(data.summary);
      }
    }
  }
};
```

---

## Checkpoint

Before moving on, verify:

- [ ] API keys are stored securely in secrets
- [ ] Rate limiting prevents abuse
- [ ] Usage is tracked for cost monitoring
- [ ] Errors are handled gracefully with retries
- [ ] Caching reduces duplicate API calls

---

## Next Steps

Continue to [05-stripe-integration.md](./05-stripe-integration.md) for web payment integration.
