# 02 - File Storage

> Day 3 of Week 4: Upload audio files to Supabase Storage

## Overview

We'll implement:
- Supabase Storage bucket setup
- File upload from device
- Signed URLs for playback
- Upload progress tracking

---

## Step 1: Configure Storage Bucket

In Supabase Dashboard, go to **Storage** and create a bucket:

1. Click **New Bucket**
2. Name: `audio`
3. Public bucket: **No** (we'll use signed URLs)

Or via SQL:

```sql
insert into storage.buckets (id, name, public)
values ('audio', 'audio', false);
```

## Step 2: Storage Policies

Create RLS policies for the audio bucket:

```sql
-- Allow authenticated users to upload to their own folder
create policy "Users upload own audio"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'audio' and
  auth.uid()::text = (storage.foldername(name))[1]
);

-- Allow users to read their own audio files
create policy "Users read own audio"
on storage.objects for select
to authenticated
using (
  bucket_id = 'audio' and
  auth.uid()::text = (storage.foldername(name))[1]
);

-- Allow users to delete their own audio files
create policy "Users delete own audio"
on storage.objects for delete
to authenticated
using (
  bucket_id = 'audio' and
  auth.uid()::text = (storage.foldername(name))[1]
);
```

## Step 3: Create Upload Function

Create `lib/storage.ts`:

```typescript
import { supabase } from './supabase';
import * as FileSystem from 'expo-file-system';
import { Platform } from 'react-native';
import { decode } from 'base64-arraybuffer';

type UploadProgress = {
  loaded: number;
  total: number;
};

type UploadResult = {
  path: string;
  url: string;
};

export async function uploadAudio(
  localUri: string,
  userId: string,
  onProgress?: (progress: UploadProgress) => void
): Promise<UploadResult> {
  // Generate unique filename
  const timestamp = Date.now();
  const extension = getExtension(localUri);
  const fileName = `${timestamp}.${extension}`;
  const storagePath = `${userId}/${fileName}`;

  if (Platform.OS === 'web') {
    return uploadWeb(localUri, storagePath, onProgress);
  } else {
    return uploadNative(localUri, storagePath, onProgress);
  }
}

async function uploadNative(
  localUri: string,
  storagePath: string,
  onProgress?: (progress: UploadProgress) => void
): Promise<UploadResult> {
  // Get file info for progress tracking
  const fileInfo = await FileSystem.getInfoAsync(localUri);
  const fileSize = fileInfo.exists ? fileInfo.size || 0 : 0;

  // IMPORTANT: Avoid base64 encoding for large files to prevent OOM crashes
  // Base64 increases memory usage by ~33% (50MB file = 67MB base64 string + original = 117MB minimum)
  // Instead, use FormData with file URI directly on native platforms

  // For files over 5MB, use chunked upload or streaming approach
  const LARGE_FILE_THRESHOLD = 5 * 1024 * 1024; // 5MB

  if (fileSize > LARGE_FILE_THRESHOLD) {
    // Use FormData approach which handles file streaming internally
    // This avoids loading the entire file into memory as base64
    const formData = new FormData();
    formData.append('file', {
      uri: localUri,
      name: storagePath.split('/').pop() || 'audio.m4a',
      type: getContentType(storagePath),
    } as any);

    // Use fetch with FormData for memory-efficient upload
    const { data: { session } } = await supabase.auth.getSession();
    const response = await fetch(
      `${supabase.supabaseUrl}/storage/v1/object/audio/${storagePath}`,
      {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${session?.access_token}`,
        },
        body: formData,
      }
    );

    if (!response.ok) {
      const error = await response.text();
      throw new Error(`Upload failed: ${error}`);
    }
  } else {
    // For smaller files, base64 approach is fine
    const base64 = await FileSystem.readAsStringAsync(localUri, {
      encoding: FileSystem.EncodingType.Base64,
    });

    // Convert to ArrayBuffer
    const arrayBuffer = decode(base64);

    // Upload to Supabase
    const { data, error } = await supabase.storage
      .from('audio')
      .upload(storagePath, arrayBuffer, {
        contentType: getContentType(storagePath),
        upsert: false,
      });

    if (error) throw error;
  }

  // Get signed URL
  const { data: urlData } = await supabase.storage
    .from('audio')
    .createSignedUrl(storagePath, 60 * 60 * 24 * 7); // 7 days

  // Report completion
  if (onProgress) {
    onProgress({ loaded: fileSize, total: fileSize });
  }

  return {
    path: storagePath,
    url: urlData?.signedUrl || '',
  };
}

async function uploadWeb(
  localUri: string,
  storagePath: string,
  onProgress?: (progress: UploadProgress) => void
): Promise<UploadResult> {
  // Fetch blob from local URI
  const response = await fetch(localUri);
  const blob = await response.blob();

  // Upload to Supabase
  const { data, error } = await supabase.storage
    .from('audio')
    .upload(storagePath, blob, {
      contentType: blob.type,
      upsert: false,
    });

  if (error) throw error;

  // Get signed URL
  const { data: urlData } = await supabase.storage
    .from('audio')
    .createSignedUrl(storagePath, 60 * 60 * 24 * 7);

  if (onProgress) {
    onProgress({ loaded: blob.size, total: blob.size });
  }

  return {
    path: storagePath,
    url: urlData?.signedUrl || '',
  };
}

export async function getAudioUrl(storagePath: string): Promise<string | null> {
  const { data, error } = await supabase.storage
    .from('audio')
    .createSignedUrl(storagePath, 60 * 60); // 1 hour

  if (error) {
    console.error('Error getting signed URL:', error);
    return null;
  }

  return data.signedUrl;
}

export async function deleteAudio(storagePath: string): Promise<void> {
  const { error } = await supabase.storage
    .from('audio')
    .remove([storagePath]);

  if (error) throw error;
}

function getExtension(uri: string): string {
  const match = uri.match(/\.(\w+)$/);
  return match ? match[1] : 'm4a';
}

function getContentType(path: string): string {
  const ext = getExtension(path).toLowerCase();
  const types: Record<string, string> = {
    m4a: 'audio/mp4',
    mp3: 'audio/mpeg',
    wav: 'audio/wav',
    webm: 'audio/webm',
    ogg: 'audio/ogg',
  };
  return types[ext] || 'audio/mpeg';
}
```

## Step 4: Create Notes Table

Update your database with the notes table:

```sql
create table notes (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users(id) on delete cascade not null,
  title text,
  audio_path text, -- Storage path
  audio_duration integer, -- Duration in seconds
  transcript text,
  summary text,
  status text default 'uploading' check (status in ('uploading', 'processing', 'ready', 'error')),
  error_message text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- Indexes
create index idx_notes_user on notes(user_id);
create index idx_notes_status on notes(status);
create index idx_notes_created on notes(created_at desc);

-- RLS
alter table notes enable row level security;

create policy "Users manage own notes"
on notes for all
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

-- Auto-update updated_at
create or replace function update_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger notes_updated_at
before update on notes
for each row
execute function update_updated_at();
```

## Step 5: Notes Hook

Create `hooks/useNotes.ts`:

```typescript
import { useState, useEffect, useCallback } from 'react';
import { supabase } from '@/lib/supabase';
import { useAuth } from '@/contexts/AuthContext';
import { uploadAudio, deleteAudio, getAudioUrl } from '@/lib/storage';

export type Note = {
  id: string;
  user_id: string;
  title: string | null;
  audio_path: string | null;
  audio_duration: number | null;
  transcript: string | null;
  summary: string | null;
  status: 'uploading' | 'processing' | 'ready' | 'error';
  error_message: string | null;
  created_at: string;
  updated_at: string;
};

const PAGE_SIZE = 20; // Limit to prevent performance issues with large datasets

export function useNotes() {
  const { user } = useAuth();
  const [notes, setNotes] = useState<Note[]>([]);
  const [loading, setLoading] = useState(true);
  const [loadingMore, setLoadingMore] = useState(false);
  const [hasMore, setHasMore] = useState(true);

  const fetchNotes = useCallback(async (reset = true) => {
    if (!user) return;

    try {
      if (reset) {
        setLoading(true);
      } else {
        setLoadingMore(true);
      }

      // Use range() for pagination - prevents OOM with large datasets
      const from = reset ? 0 : notes.length;
      const to = from + PAGE_SIZE - 1;

      const { data, error } = await supabase
        .from('notes')
        .select('*')
        .eq('user_id', user.id)
        .order('created_at', { ascending: false })
        .range(from, to); // Pagination with range()

      if (error) throw error;

      // Check if there are more notes to load
      setHasMore((data?.length || 0) === PAGE_SIZE);

      if (reset) {
        setNotes(data || []);
      } else {
        setNotes((prev) => [...prev, ...(data || [])]);
      }
    } catch (error) {
      console.error('Error fetching notes:', error);
    } finally {
      setLoading(false);
      setLoadingMore(false);
    }
  }, [user, notes.length]);

  // Load more notes when user scrolls to the bottom
  const loadMore = useCallback(() => {
    if (!loadingMore && hasMore) {
      fetchNotes(false);
    }
  }, [fetchNotes, loadingMore, hasMore]);

  useEffect(() => {
    fetchNotes();

    // Subscribe to changes
    const channel = supabase
      .channel('notes_changes')
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'notes',
          filter: `user_id=eq.${user?.id}`,
        },
        (payload) => {
          if (payload.eventType === 'INSERT') {
            setNotes((prev) => [payload.new as Note, ...prev]);
          } else if (payload.eventType === 'UPDATE') {
            setNotes((prev) =>
              prev.map((n) =>
                n.id === payload.new.id ? (payload.new as Note) : n
              )
            );
          } else if (payload.eventType === 'DELETE') {
            setNotes((prev) =>
              prev.filter((n) => n.id !== payload.old.id)
            );
          }
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [fetchNotes, user]);

  const createNote = async (
    localUri: string,
    duration: number,
    onProgress?: (progress: { loaded: number; total: number }) => void
  ): Promise<Note> => {
    if (!user) throw new Error('Not authenticated');

    // Create note record first
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
      // Upload audio file
      const { path } = await uploadAudio(localUri, user.id, onProgress);

      // Update note with audio path
      const { data: updatedNote, error: updateError } = await supabase
        .from('notes')
        .update({
          audio_path: path,
          status: 'processing',
        })
        .eq('id', note.id)
        .select()
        .single();

      if (updateError) throw updateError;

      // Trigger transcription (we'll implement this in Edge Functions)
      await supabase.functions.invoke('transcribe', {
        body: { noteId: note.id },
      });

      return updatedNote;
    } catch (error) {
      // Mark note as error
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

  const deleteNote = async (noteId: string) => {
    const note = notes.find((n) => n.id === noteId);
    if (!note) return;

    // Delete audio file if exists
    if (note.audio_path) {
      try {
        await deleteAudio(note.audio_path);
      } catch (error) {
        console.error('Error deleting audio:', error);
      }
    }

    // Delete note record
    const { error } = await supabase
      .from('notes')
      .delete()
      .eq('id', noteId);

    if (error) throw error;
  };

  const getPlaybackUrl = async (audioPath: string): Promise<string | null> => {
    return getAudioUrl(audioPath);
  };

  return {
    notes,
    loading,
    loadingMore,
    hasMore,
    createNote,
    deleteNote,
    getPlaybackUrl,
    refetch: () => fetchNotes(true),
    loadMore, // Call when user scrolls to bottom
  };
}
```

## Step 6: Update Recording Screen

Update `app/(app)/(tabs)/record.tsx` to save notes:

```tsx
import { useNotes } from '@/hooks/useNotes';

export default function RecordScreen() {
  // ... existing code ...
  const { createNote } = useNotes();
  const [uploading, setUploading] = useState(false);
  const [uploadProgress, setUploadProgress] = useState(0);

  const handleStop = async () => {
    const uri = await stopRecording();
    if (!uri) return;

    setUploading(true);
    try {
      await createNote(uri, duration, (progress) => {
        setUploadProgress(progress.loaded / progress.total);
      });
      reset();
      router.push('/(app)/(tabs)'); // Go to notes list
    } catch (error) {
      Alert.alert('Error', 'Failed to save note. Please try again.');
    } finally {
      setUploading(false);
      setUploadProgress(0);
    }
  };

  // Show upload progress
  if (uploading) {
    return (
      <View style={styles.container}>
        <View style={styles.content}>
          <ActivityIndicator size="large" color="#3B82F6" />
          <Text style={styles.uploadText}>
            Uploading... {Math.round(uploadProgress * 100)}%
          </Text>
        </View>
      </View>
    );
  }

  // ... rest of component
}
```

## Step 7: Notes List Screen

Create `app/(app)/(tabs)/index.tsx`:

```tsx
import { View, Text, FlatList, TouchableOpacity, StyleSheet } from 'react-native';
import { router } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { useNotes, Note } from '@/hooks/useNotes';
import { formatDuration } from '@/lib/utils';

export default function NotesListScreen() {
  const { notes, loading, loadingMore, hasMore, loadMore } = useNotes();

  if (loading) {
    return (
      <View style={styles.center}>
        <Text>Loading...</Text>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <FlatList
        data={notes}
        keyExtractor={(item) => item.id}
        contentContainerStyle={styles.list}
        ListEmptyComponent={<EmptyState />}
        renderItem={({ item }) => (
          <NoteCard
            note={item}
            onPress={() => router.push(`/note/${item.id}`)}
          />
        )}
        // Pagination - load more when user reaches the end
        onEndReached={loadMore}
        onEndReachedThreshold={0.5} // Trigger when 50% from bottom
        ListFooterComponent={
          loadingMore ? (
            <View style={styles.loadingMore}>
              <ActivityIndicator size="small" color="#3B82F6" />
              <Text style={styles.loadingMoreText}>Loading more notes...</Text>
            </View>
          ) : !hasMore && notes.length > 0 ? (
            <Text style={styles.endOfList}>No more notes</Text>
          ) : null
        }
      />
    </View>
  );
}

function NoteCard({ note, onPress }: { note: Note; onPress: () => void }) {
  const statusColors = {
    uploading: '#F59E0B',
    processing: '#3B82F6',
    ready: '#10B981',
    error: '#EF4444',
  };

  return (
    <TouchableOpacity style={styles.card} onPress={onPress}>
      <View style={styles.cardContent}>
        <Text style={styles.title} numberOfLines={1}>
          {note.title || 'Untitled Note'}
        </Text>
        <Text style={styles.duration}>
          {note.audio_duration ? formatDuration(note.audio_duration) : '--:--'}
        </Text>
        {note.summary && (
          <Text style={styles.summary} numberOfLines={2}>
            {note.summary}
          </Text>
        )}
      </View>
      <View style={styles.cardRight}>
        <View
          style={[
            styles.statusDot,
            { backgroundColor: statusColors[note.status] },
          ]}
        />
        <Text style={styles.date}>
          {new Date(note.created_at).toLocaleDateString()}
        </Text>
      </View>
    </TouchableOpacity>
  );
}

function EmptyState() {
  return (
    <View style={styles.empty}>
      <Ionicons name="mic-outline" size={64} color="#D1D5DB" />
      <Text style={styles.emptyTitle}>No notes yet</Text>
      <Text style={styles.emptySubtitle}>
        Record your first voice note to get started
      </Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#F9FAFB' },
  center: { flex: 1, justifyContent: 'center', alignItems: 'center' },
  list: { padding: 16, paddingBottom: 100 },
  loadingMore: { flexDirection: 'row', justifyContent: 'center', alignItems: 'center', padding: 16, gap: 8 },
  loadingMoreText: { color: '#6B7280', fontSize: 14 },
  endOfList: { textAlign: 'center', color: '#9CA3AF', fontSize: 14, padding: 16 },
  card: {
    backgroundColor: '#fff',
    borderRadius: 12,
    padding: 16,
    marginBottom: 12,
    flexDirection: 'row',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.05,
    shadowRadius: 2,
    elevation: 1,
  },
  cardContent: { flex: 1 },
  title: { fontSize: 16, fontWeight: '600', color: '#1F2937' },
  duration: { fontSize: 12, color: '#6B7280', marginTop: 4 },
  summary: { fontSize: 14, color: '#6B7280', marginTop: 8 },
  cardRight: { alignItems: 'flex-end' },
  statusDot: { width: 8, height: 8, borderRadius: 4 },
  date: { fontSize: 12, color: '#9CA3AF', marginTop: 4 },
  empty: { alignItems: 'center', paddingVertical: 60 },
  emptyTitle: { fontSize: 18, fontWeight: '600', color: '#6B7280', marginTop: 16 },
  emptySubtitle: { fontSize: 14, color: '#9CA3AF', marginTop: 8 },
});
```

---

## Checkpoint

Before moving on, verify:

- [ ] Audio files upload successfully
- [ ] Note record created in database
- [ ] Status updates work (uploading → processing)
- [ ] Notes list shows all notes
- [ ] Can delete notes (and files are removed)
- [ ] Realtime updates work

---

## Next Steps

Continue to [03-edge-functions.md](./03-edge-functions.md) to process audio with Edge Functions.
