# 03 - Edge Functions

> Day 4-5 of Week 4: Create serverless functions for audio processing

## Overview

We'll implement:
- Supabase Edge Functions setup
- Audio transcription with Whisper
- Background processing pattern
- Error handling and retries

---

## Step 1: Set Up Supabase CLI

```bash
# Install Supabase CLI
npm install -g supabase

# Login
supabase login

# Link to your project
supabase link --project-ref YOUR_PROJECT_REF
```

## Step 2: Create Transcription Function

```bash
# Create function directory
supabase functions new transcribe
```

Edit `supabase/functions/transcribe/index.ts`:

```typescript
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { noteId } = await req.json();
    if (!noteId) {
      throw new Error('noteId is required');
    }

    // Initialize Supabase client with service role
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    );

    // Get note details
    const { data: note, error: noteError } = await supabase
      .from('notes')
      .select('*')
      .eq('id', noteId)
      .single();

    if (noteError || !note) {
      throw new Error('Note not found');
    }

    if (!note.audio_path) {
      throw new Error('No audio file associated with note');
    }

    // Download audio from storage
    const { data: audioData, error: downloadError } = await supabase
      .storage
      .from('audio')
      .download(note.audio_path);

    if (downloadError || !audioData) {
      throw new Error('Failed to download audio file');
    }

    // Call OpenAI Whisper API
    // ⚠️ SECURITY WARNING: API keys must NEVER be exposed to the client!
    // - Always call external APIs from Edge Functions (server-side)
    // - Store API keys in Supabase Secrets, not in client code
    // - Never include API keys in your React Native / Expo app bundle
    // - The OPENAI_API_KEY is stored securely using `supabase secrets set`
    const openaiApiKey = Deno.env.get('OPENAI_API_KEY');
    if (!openaiApiKey) {
      throw new Error('OPENAI_API_KEY is not configured. Set it using: supabase secrets set OPENAI_API_KEY=sk-xxx');
    }

    const formData = new FormData();
    formData.append('file', audioData, 'audio.m4a');
    formData.append('model', 'whisper-1');
    formData.append('response_format', 'text');

    const whisperResponse = await fetch(
      'https://api.openai.com/v1/audio/transcriptions',
      {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${openaiApiKey}`,
        },
        body: formData,
      }
    );

    if (!whisperResponse.ok) {
      const error = await whisperResponse.text();
      throw new Error(`Whisper API error: ${error}`);
    }

    const transcript = await whisperResponse.text();

    // Update note with transcript
    const { error: updateError } = await supabase
      .from('notes')
      .update({
        transcript,
        status: 'processing', // Still processing for summary
      })
      .eq('id', noteId);

    if (updateError) {
      throw updateError;
    }

    // Trigger summarization
    await fetch(`${Deno.env.get('SUPABASE_URL')}/functions/v1/summarize`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${Deno.env.get('SUPABASE_ANON_KEY')}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ noteId }),
    });

    return new Response(
      JSON.stringify({ success: true, transcript }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  } catch (error) {
    console.error('Transcription error:', error);

    // Try to update note status to error
    try {
      const { noteId } = await req.json();
      const supabase = createClient(
        Deno.env.get('SUPABASE_URL')!,
        Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
      );

      await supabase
        .from('notes')
        .update({
          status: 'error',
          error_message: error.message,
        })
        .eq('id', noteId);
    } catch (e) {
      console.error('Failed to update error status:', e);
    }

    return new Response(
      JSON.stringify({ error: error.message }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  }
});
```

## Step 3: Create Summarization Function

```bash
supabase functions new summarize
```

Edit `supabase/functions/summarize/index.ts`:

```typescript
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { noteId } = await req.json();
    if (!noteId) {
      throw new Error('noteId is required');
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    );

    // Get note with transcript
    const { data: note, error: noteError } = await supabase
      .from('notes')
      .select('*')
      .eq('id', noteId)
      .single();

    if (noteError || !note) {
      throw new Error('Note not found');
    }

    if (!note.transcript) {
      throw new Error('No transcript available');
    }

    // Generate summary with GPT-4
    // ⚠️ SECURITY: API key is accessed server-side only via Supabase Secrets
    const openaiApiKey = Deno.env.get('OPENAI_API_KEY');
    if (!openaiApiKey) {
      throw new Error('OPENAI_API_KEY is not configured');
    }

    const gptResponse = await fetch(
      'https://api.openai.com/v1/chat/completions',
      {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${openaiApiKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          model: 'gpt-4o-mini',
          messages: [
            {
              role: 'system',
              content: `You are a helpful assistant that summarizes voice notes.
                Create a concise summary (2-3 sentences max) and suggest a short title (3-5 words).
                Respond in JSON format: { "title": "...", "summary": "..." }`,
            },
            {
              role: 'user',
              content: note.transcript,
            },
          ],
          temperature: 0.7,
          max_tokens: 200,
        }),
      }
    );

    if (!gptResponse.ok) {
      const error = await gptResponse.text();
      throw new Error(`GPT API error: ${error}`);
    }

    const gptData = await gptResponse.json();
    const content = gptData.choices[0].message.content;

    // Parse JSON response
    let parsed;
    try {
      parsed = JSON.parse(content);
    } catch {
      parsed = { title: 'Voice Note', summary: content };
    }

    // Update note with summary
    const { error: updateError } = await supabase
      .from('notes')
      .update({
        title: parsed.title,
        summary: parsed.summary,
        status: 'ready',
      })
      .eq('id', noteId);

    if (updateError) {
      throw updateError;
    }

    return new Response(
      JSON.stringify({ success: true, ...parsed }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  } catch (error) {
    console.error('Summarization error:', error);

    try {
      const { noteId } = await req.json();
      const supabase = createClient(
        Deno.env.get('SUPABASE_URL')!,
        Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
      );

      // Still mark as ready since we have transcript
      await supabase
        .from('notes')
        .update({
          title: 'Voice Note',
          status: 'ready',
        })
        .eq('id', noteId);
    } catch (e) {
      console.error('Failed to update status:', e);
    }

    return new Response(
      JSON.stringify({ error: error.message }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  }
});
```

## Step 4: Set Environment Variables

In Supabase Dashboard, go to **Edge Functions** → **Secrets**:

```
OPENAI_API_KEY=sk-xxxxx
```

Or via CLI:

```bash
supabase secrets set OPENAI_API_KEY=sk-xxxxx
```

> **API Keys in Edge Functions (2025 Update):**
>
> Supabase now uses a new key system:
> - **Secret key** (`sb_secret_...`): Use this in Edge Functions instead of `service_role`
> - The `SUPABASE_SERVICE_ROLE_KEY` environment variable is automatically set in Edge Functions
>
> For new projects, you'll see `sb_secret_...` format keys. These work the same way as
> the legacy `service_role` key but with improved security features like instant revocation.
>
> **Important:** Secret keys cannot be verified as JWTs. If you're using `verify_jwt=true`
> in your function config, you'll need to handle authentication manually for requests
> using secret keys.

## Step 5: Deploy Functions

```bash
# Deploy all functions
supabase functions deploy

# Or deploy individually
supabase functions deploy transcribe
supabase functions deploy summarize
```

## Step 6: Update Client to Call Functions

Update the note creation flow in `hooks/useNotes.ts`:

```typescript
const createNote = async (
  localUri: string,
  duration: number,
  onProgress?: (progress: { loaded: number; total: number }) => void
): Promise<Note> => {
  if (!user) throw new Error('Not authenticated');

  // Create note record
  const { data: note, error: createError } = await supabase
    .from('notes')
    .insert({
      user_id: user.id,
      audio_duration: duration,
      status: 'uploading',
    })
    .select()
    .single();

  if (createError) throw createError;

  try {
    // Upload audio
    const { path } = await uploadAudio(localUri, user.id, onProgress);

    // Update note with path
    await supabase
      .from('notes')
      .update({ audio_path: path, status: 'processing' })
      .eq('id', note.id);

    // Invoke transcription function with comprehensive error handling
    try {
      const { data, error: fnError } = await supabase.functions.invoke('transcribe', {
        body: { noteId: note.id },
      });

      if (fnError) {
        console.error('Transcription function error:', fnError);
        // Update note status to error so it doesn't get stuck in 'processing'
        await supabase
          .from('notes')
          .update({
            status: 'error',
            error_message: `Transcription failed: ${fnError.message}`,
          })
          .eq('id', note.id);
      }
    } catch (fnError) {
      // Network error or function timeout - mark as error
      console.error('Failed to invoke transcription function:', fnError);
      await supabase
        .from('notes')
        .update({
          status: 'error',
          error_message: fnError instanceof Error
            ? `Transcription service unavailable: ${fnError.message}`
            : 'Transcription service unavailable',
        })
        .eq('id', note.id);
    }

    return { ...note, audio_path: path, status: 'processing' };
  } catch (error) {
    await supabase
      .from('notes')
      .update({
        status: 'error',
        error_message: error instanceof Error ? error.message : 'Upload failed',
      })
      .eq('id', note.id);

    throw error;
  }
};
```

## Step 7: Handle Long-Running Tasks

For audio files longer than 30 seconds (Edge Function timeout), use a queue:

```sql
-- Create processing queue table
create table processing_queue (
  id uuid default gen_random_uuid() primary key,
  note_id uuid references notes(id) on delete cascade,
  job_type text not null,
  status text default 'pending',
  attempts integer default 0,
  last_error text,
  created_at timestamptz default now(),
  started_at timestamptz,
  completed_at timestamptz
);

-- Index for processing
create index idx_queue_pending on processing_queue(status, created_at)
  where status = 'pending';
```

Create a cron job to process the queue (using pg_cron or external service):

```sql
-- Enable pg_cron extension
create extension if not exists pg_cron;

-- Schedule job every minute
select cron.schedule(
  'process-queue',
  '* * * * *',
  $$
  select net.http_post(
    url := 'https://YOUR_PROJECT.supabase.co/functions/v1/process-queue',
    headers := '{"Authorization": "Bearer YOUR_SERVICE_ROLE_KEY"}'::jsonb
  );
  $$
);
```

## Step 8: Testing Locally

```bash
# Start local Supabase
supabase start

# Serve functions locally
supabase functions serve --env-file .env.local

# Test with curl
curl -X POST http://localhost:54321/functions/v1/transcribe \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"noteId": "xxx"}'
```

---

## Checkpoint

Before moving on, verify:

- [ ] Functions deploy successfully
- [ ] Transcription works for short audio (<30s)
- [ ] Summary is generated after transcription
- [ ] Note status updates through the pipeline
- [ ] Errors are captured and displayed

---

## Common Issues

### "Function timeout"

Edge Functions have 150s timeout (free) or 400s (Pro). For longer audio:
- Split audio into chunks
- Use background job queue
- Process asynchronously

### "CORS error"

Ensure corsHeaders are returned in response.

### "OpenAI rate limit"

Implement retry with exponential backoff:

```typescript
async function withRetry<T>(fn: () => Promise<T>, retries = 3): Promise<T> {
  for (let i = 0; i < retries; i++) {
    try {
      return await fn();
    } catch (error) {
      if (i === retries - 1) throw error;
      await new Promise((r) => setTimeout(r, Math.pow(2, i) * 1000));
    }
  }
  throw new Error('Max retries reached');
}
```

---

## Next Steps

Continue to [04-external-apis.md](./04-external-apis.md) for advanced API integration patterns.
