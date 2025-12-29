# 01 - Audio Recording

> Day 2 of Week 4: Implement cross-platform audio recording

## Overview

We'll implement:
- Recording permissions
- Start/stop/pause recording
- Recording visualization
- Audio file handling

---

## Step 1: Install Dependencies

```bash
npx expo install expo-av expo-file-system
```

Add to `app.json`:

```json
{
  "expo": {
    "plugins": [
      [
        "expo-av",
        {
          "microphonePermission": "Allow QuickNote to record audio for your voice notes."
        }
      ]
    ]
  }
}
```

## Step 2: Create Recording Hook

Create `hooks/useRecording.ts`:

```typescript
import { useState, useRef, useEffect } from 'react';
import { Audio } from 'expo-av';
import * as FileSystem from 'expo-file-system';

type RecordingState = 'idle' | 'recording' | 'paused' | 'stopped';

export function useRecording() {
  const [state, setState] = useState<RecordingState>('idle');
  const [duration, setDuration] = useState(0);
  const [metering, setMetering] = useState(-160); // dB level for visualization
  const recordingRef = useRef<Audio.Recording | null>(null);
  const intervalRef = useRef<NodeJS.Timeout | null>(null);

  useEffect(() => {
    return () => {
      // Cleanup on unmount
      if (recordingRef.current) {
        recordingRef.current.stopAndUnloadAsync();
      }
      if (intervalRef.current) {
        clearInterval(intervalRef.current);
      }
    };
  }, []);

  const requestPermissions = async (): Promise<boolean> => {
    const { status } = await Audio.requestPermissionsAsync();
    if (status !== 'granted') {
      console.error('Microphone permission not granted');
      return false;
    }

    await Audio.setAudioModeAsync({
      allowsRecordingIOS: true,
      playsInSilentModeIOS: true,
    });

    return true;
  };

  const startRecording = async () => {
    const hasPermission = await requestPermissions();
    if (!hasPermission) return;

    try {
      const recording = new Audio.Recording();
      await recording.prepareToRecordAsync({
        android: {
          extension: '.m4a',
          outputFormat: Audio.AndroidOutputFormat.MPEG_4,
          audioEncoder: Audio.AndroidAudioEncoder.AAC,
          sampleRate: 44100,
          numberOfChannels: 1,
          bitRate: 128000,
        },
        ios: {
          extension: '.m4a',
          outputFormat: Audio.IOSOutputFormat.MPEG4AAC,
          audioQuality: Audio.IOSAudioQuality.HIGH,
          sampleRate: 44100,
          numberOfChannels: 1,
          bitRate: 128000,
        },
        web: {
          mimeType: 'audio/webm',
          bitsPerSecond: 128000,
        },
      });

      // Enable metering for visualization
      recording.setOnRecordingStatusUpdate((status) => {
        if (status.isRecording && status.metering !== undefined) {
          setMetering(status.metering);
        }
      });

      await recording.startAsync();
      recordingRef.current = recording;
      setState('recording');

      // Start duration timer
      intervalRef.current = setInterval(() => {
        setDuration((d) => d + 1);
      }, 1000);
    } catch (error) {
      console.error('Failed to start recording:', error);
    }
  };

  const pauseRecording = async () => {
    if (!recordingRef.current || state !== 'recording') return;

    try {
      await recordingRef.current.pauseAsync();
      setState('paused');
      if (intervalRef.current) {
        clearInterval(intervalRef.current);
      }
    } catch (error) {
      console.error('Failed to pause recording:', error);
    }
  };

  const resumeRecording = async () => {
    if (!recordingRef.current || state !== 'paused') return;

    try {
      await recordingRef.current.startAsync();
      setState('recording');
      intervalRef.current = setInterval(() => {
        setDuration((d) => d + 1);
      }, 1000);
    } catch (error) {
      console.error('Failed to resume recording:', error);
    }
  };

  const stopRecording = async (): Promise<string | null> => {
    if (!recordingRef.current) return null;

    try {
      if (intervalRef.current) {
        clearInterval(intervalRef.current);
      }

      await recordingRef.current.stopAndUnloadAsync();
      const uri = recordingRef.current.getURI();

      setState('stopped');
      recordingRef.current = null;

      return uri;
    } catch (error) {
      console.error('Failed to stop recording:', error);
      return null;
    }
  };

  const cancelRecording = async () => {
    if (!recordingRef.current) return;

    try {
      if (intervalRef.current) {
        clearInterval(intervalRef.current);
      }

      await recordingRef.current.stopAndUnloadAsync();
      const uri = recordingRef.current.getURI();

      // Delete the file
      if (uri) {
        await FileSystem.deleteAsync(uri, { idempotent: true });
      }

      setState('idle');
      setDuration(0);
      recordingRef.current = null;
    } catch (error) {
      console.error('Failed to cancel recording:', error);
    }
  };

  const reset = () => {
    setState('idle');
    setDuration(0);
    setMetering(-160);
  };

  return {
    state,
    duration,
    metering,
    startRecording,
    pauseRecording,
    resumeRecording,
    stopRecording,
    cancelRecording,
    reset,
  };
}
```

## Step 3: Recording UI Component

Create `components/RecordButton.tsx`:

```tsx
import { TouchableOpacity, View, Text, StyleSheet } from 'react-native';
import Animated, {
  useAnimatedStyle,
  withRepeat,
  withTiming,
  useSharedValue,
} from 'react-native-reanimated';
import { Ionicons } from '@expo/vector-icons';
import { useEffect } from 'react';

type Props = {
  state: 'idle' | 'recording' | 'paused' | 'stopped';
  onPress: () => void;
  size?: number;
};

export function RecordButton({ state, onPress, size = 80 }: Props) {
  const scale = useSharedValue(1);
  const isRecording = state === 'recording';

  useEffect(() => {
    if (isRecording) {
      scale.value = withRepeat(
        withTiming(1.2, { duration: 800 }),
        -1,
        true
      );
    } else {
      scale.value = withTiming(1);
    }
  }, [isRecording]);

  const animatedStyle = useAnimatedStyle(() => ({
    transform: [{ scale: scale.value }],
  }));

  return (
    <TouchableOpacity onPress={onPress} activeOpacity={0.8}>
      <View style={[styles.outer, { width: size, height: size, borderRadius: size / 2 }]}>
        <Animated.View
          style={[
            styles.inner,
            {
              width: size * 0.8,
              height: size * 0.8,
              borderRadius: isRecording ? 8 : size * 0.4,
              backgroundColor: isRecording ? '#EF4444' : '#EF4444',
            },
            animatedStyle,
          ]}
        />
      </View>
    </TouchableOpacity>
  );
}

const styles = StyleSheet.create({
  outer: {
    backgroundColor: '#FEE2E2',
    justifyContent: 'center',
    alignItems: 'center',
  },
  inner: {
    backgroundColor: '#EF4444',
  },
});
```

## Step 4: Audio Level Visualizer

Create `components/AudioWaveform.tsx`:

```tsx
import { View, StyleSheet } from 'react-native';
import Animated, {
  useAnimatedStyle,
  withSpring,
} from 'react-native-reanimated';

type Props = {
  metering: number; // -160 to 0 dB
  barCount?: number;
};

export function AudioWaveform({ metering, barCount = 20 }: Props) {
  // Normalize metering to 0-1 range
  const normalized = Math.max(0, (metering + 160) / 160);

  return (
    <View style={styles.container}>
      {Array.from({ length: barCount }).map((_, i) => {
        const barHeight = getBarHeight(i, barCount, normalized);
        return <Bar key={i} height={barHeight} />;
      })}
    </View>
  );
}

function getBarHeight(index: number, total: number, level: number): number {
  // Create a wave pattern centered in the middle
  const center = total / 2;
  const distance = Math.abs(index - center) / center;
  const baseHeight = 0.2 + (1 - distance) * 0.8;
  return baseHeight * level;
}

function Bar({ height }: { height: number }) {
  const animatedStyle = useAnimatedStyle(() => ({
    height: withSpring(4 + height * 40, {
      damping: 15,
      stiffness: 150,
    }),
  }));

  return <Animated.View style={[styles.bar, animatedStyle]} />;
}

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    height: 60,
    gap: 3,
  },
  bar: {
    width: 4,
    backgroundColor: '#EF4444',
    borderRadius: 2,
  },
});
```

## Step 5: Recording Screen

Create `app/(app)/(tabs)/record.tsx`:

```tsx
import { View, Text, TouchableOpacity, StyleSheet, Alert } from 'react-native';
import { router } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { useRecording } from '@/hooks/useRecording';
import { RecordButton } from '@/components/RecordButton';
import { AudioWaveform } from '@/components/AudioWaveform';
import { formatDuration } from '@/lib/utils';

export default function RecordScreen() {
  const {
    state,
    duration,
    metering,
    startRecording,
    pauseRecording,
    resumeRecording,
    stopRecording,
    cancelRecording,
    reset,
  } = useRecording();

  const handleMainButton = async () => {
    switch (state) {
      case 'idle':
        await startRecording();
        break;
      case 'recording':
        await pauseRecording();
        break;
      case 'paused':
        await resumeRecording();
        break;
    }
  };

  const handleStop = async () => {
    const uri = await stopRecording();
    if (uri) {
      // Navigate to save/process screen or directly upload
      // For now, we'll handle this in the next chapter
      Alert.alert('Recording saved', `Duration: ${formatDuration(duration)}`);
      reset();
    }
  };

  const handleCancel = () => {
    Alert.alert(
      'Cancel Recording',
      'Are you sure you want to discard this recording?',
      [
        { text: 'Keep Recording', style: 'cancel' },
        {
          text: 'Discard',
          style: 'destructive',
          onPress: () => {
            cancelRecording();
          },
        },
      ]
    );
  };

  const isActive = state === 'recording' || state === 'paused';

  return (
    <View style={styles.container}>
      <View style={styles.header}>
        {isActive && (
          <TouchableOpacity onPress={handleCancel} style={styles.cancelButton}>
            <Ionicons name="close" size={24} color="#6B7280" />
          </TouchableOpacity>
        )}
      </View>

      <View style={styles.content}>
        {isActive ? (
          <>
            <AudioWaveform metering={metering} />
            <Text style={styles.duration}>{formatDuration(duration)}</Text>
            <Text style={styles.stateText}>
              {state === 'recording' ? 'Recording...' : 'Paused'}
            </Text>
          </>
        ) : (
          <>
            <Ionicons name="mic" size={64} color="#D1D5DB" />
            <Text style={styles.prompt}>Tap to start recording</Text>
          </>
        )}
      </View>

      <View style={styles.controls}>
        {isActive && (
          <TouchableOpacity onPress={handleStop} style={styles.stopButton}>
            <Ionicons name="checkmark" size={28} color="#fff" />
          </TouchableOpacity>
        )}

        <RecordButton state={state} onPress={handleMainButton} />

        {isActive && <View style={{ width: 56 }} />}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#fff',
  },
  header: {
    height: 60,
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 16,
  },
  cancelButton: {
    padding: 8,
  },
  content: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    paddingHorizontal: 24,
  },
  duration: {
    fontSize: 48,
    fontWeight: '300',
    color: '#1F2937',
    marginTop: 24,
    fontVariant: ['tabular-nums'],
  },
  stateText: {
    fontSize: 16,
    color: '#6B7280',
    marginTop: 8,
  },
  prompt: {
    fontSize: 16,
    color: '#9CA3AF',
    marginTop: 16,
  },
  controls: {
    flexDirection: 'row',
    justifyContent: 'center',
    alignItems: 'center',
    paddingBottom: 48,
    gap: 32,
  },
  stopButton: {
    width: 56,
    height: 56,
    borderRadius: 28,
    backgroundColor: '#10B981',
    justifyContent: 'center',
    alignItems: 'center',
  },
});
```

## Step 6: Utility Functions

Create `lib/utils.ts`:

```typescript
export function formatDuration(seconds: number): string {
  const mins = Math.floor(seconds / 60);
  const secs = seconds % 60;
  return `${mins}:${secs.toString().padStart(2, '0')}`;
}

export function formatFileSize(bytes: number): string {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}
```

## Step 7: Audio Playback Hook

Create `hooks/useAudioPlayer.ts`:

```typescript
import { useState, useRef, useEffect } from 'react';
import { Audio, AVPlaybackStatus } from 'expo-av';

export function useAudioPlayer(uri: string | null) {
  const [isPlaying, setIsPlaying] = useState(false);
  const [position, setPosition] = useState(0);
  const [duration, setDuration] = useState(0);
  const [isLoading, setIsLoading] = useState(false);
  const soundRef = useRef<Audio.Sound | null>(null);

  useEffect(() => {
    return () => {
      if (soundRef.current) {
        soundRef.current.unloadAsync();
      }
    };
  }, []);

  useEffect(() => {
    if (uri) {
      loadAudio();
    }
    return () => {
      if (soundRef.current) {
        soundRef.current.unloadAsync();
        soundRef.current = null;
      }
    };
  }, [uri]);

  const loadAudio = async () => {
    if (!uri) return;

    setIsLoading(true);
    try {
      const { sound } = await Audio.Sound.createAsync(
        { uri },
        { shouldPlay: false },
        onPlaybackStatusUpdate
      );
      soundRef.current = sound;
    } catch (error) {
      console.error('Error loading audio:', error);
    } finally {
      setIsLoading(false);
    }
  };

  const onPlaybackStatusUpdate = (status: AVPlaybackStatus) => {
    if (!status.isLoaded) return;

    setPosition(status.positionMillis);
    setDuration(status.durationMillis || 0);
    setIsPlaying(status.isPlaying);

    if (status.didJustFinish) {
      setIsPlaying(false);
      setPosition(0);
      soundRef.current?.setPositionAsync(0);
    }
  };

  const play = async () => {
    if (!soundRef.current) return;
    await soundRef.current.playAsync();
  };

  const pause = async () => {
    if (!soundRef.current) return;
    await soundRef.current.pauseAsync();
  };

  const togglePlayback = async () => {
    if (isPlaying) {
      await pause();
    } else {
      await play();
    }
  };

  const seek = async (positionMs: number) => {
    if (!soundRef.current) return;
    await soundRef.current.setPositionAsync(positionMs);
  };

  return {
    isPlaying,
    isLoading,
    position,
    duration,
    progress: duration > 0 ? position / duration : 0,
    play,
    pause,
    togglePlayback,
    seek,
  };
}
```

---

## Checkpoint

Before moving on, verify:

- [ ] Microphone permission requested on first record
- [ ] Recording starts/pauses/resumes correctly
- [ ] Duration timer is accurate
- [ ] Waveform animates with audio level
- [ ] Can cancel and discard recordings
- [ ] Works on iOS, Android, and web

---

## Common Issues

### "Permission denied" on iOS Simulator

The iOS Simulator doesn't have a microphone. Test on a real device.

### Recording fails on web

Ensure you're using HTTPS (required for microphone access on web).

### Audio quality issues

Adjust `sampleRate` and `bitRate` in recording options:
- Voice: 22050Hz, 64kbps
- Music: 44100Hz, 128kbps

---

## Next Steps

Continue to [02-file-storage.md](./02-file-storage.md) to upload recordings to Supabase Storage.
