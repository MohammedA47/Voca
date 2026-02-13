import { useState, useCallback, useRef, useEffect } from 'react';
import { toast } from 'sonner';
import { supabase } from '@/integrations/supabase/client';

interface UseSpeechOptions {
  onWordChange?: () => void;
}

type PhoneticAccent = 'us' | 'uk';

// Voice IDs for different accents
const VOICE_IDS = {
  uk: 'JBFqnCBsd6RMkjVDRZzb', // George - British male
  us: 'cjVigY5qzO86Huf0OWal', // Eric - American male
};

interface CachedAudio {
  word: string;
  accent: PhoneticAccent;
  blob: Blob;
}

export function useSpeech(options: UseSpeechOptions = {}) {
  const [isSpeaking, setIsSpeaking] = useState(false);
  const [isLoopingActive, setIsLoopingActive] = useState(false);
  const [speed, setSpeed] = useState(1);
  const [isRandomSpeed, setIsRandomSpeed] = useState(false);
  const [isLooping, setIsLooping] = useState(false);
  const [loopGap, setLoopGap] = useState(1.5); // seconds between repeats
  const audioRef = useRef<HTMLAudioElement | null>(null);
  const loopingRef = useRef(false);
  const currentWordRef = useRef<string>('');
  const abortControllerRef = useRef<AbortController | null>(null);
  const audioCache = useRef<CachedAudio | null>(null);
  const loopTimeoutRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => {
    loopingRef.current = isLooping;
  }, [isLooping]);

  const getRandomSpeed = useCallback(() => {
    return 0.7 + Math.random() * 0.5;
  }, []);

  const getPlaybackRate = useCallback(() => {
    return isRandomSpeed ? getRandomSpeed() : speed;
  }, [isRandomSpeed, getRandomSpeed, speed]);

  const playAudioBlob = useCallback((blob: Blob, playbackRate: number, onEnd?: () => void) => {
    const audioUrl = URL.createObjectURL(blob);
    const audio = new Audio(audioUrl);
    audioRef.current = audio;
    
    // Use playbackRate instead of regenerating audio at different speeds
    audio.playbackRate = playbackRate;

    audio.onended = () => {
      setIsSpeaking(false);
      URL.revokeObjectURL(audioUrl);
      if (loopingRef.current) {
        loopTimeoutRef.current = setTimeout(() => {
          if (loopingRef.current) {
            onEnd?.();
          } else {
            setIsLoopingActive(false);
          }
        }, loopGap * 1000);
      } else {
        setIsLoopingActive(false);
      }
    };

    audio.onerror = () => {
      setIsSpeaking(false);
      URL.revokeObjectURL(audioUrl);
      toast.error("Failed to play audio");
    };

    audio.play();
  }, [loopGap]);

  const speak = useCallback(async (text: string, accent: PhoneticAccent = 'uk', onEnd?: () => void) => {
    // Cancel any pending loop timeout
    if (loopTimeoutRef.current) {
      clearTimeout(loopTimeoutRef.current);
      loopTimeoutRef.current = null;
    }
    
    // Cancel any ongoing request
    if (abortControllerRef.current) {
      abortControllerRef.current.abort();
    }
    
    // Stop any current audio
    if (audioRef.current) {
      audioRef.current.pause();
      audioRef.current = null;
    }

    // Get playback rate for this play (speed adjustment happens at playback, not generation)
    const playbackRate = getPlaybackRate();
    currentWordRef.current = text;
    setIsSpeaking(true);
    if (loopingRef.current) {
      setIsLoopingActive(true);
    }

    // Check cache - cache by word AND accent
    if (audioCache.current && audioCache.current.word === text && audioCache.current.accent === accent) {
      playAudioBlob(audioCache.current.blob, playbackRate, onEnd);
      return;
    }

    const voiceId = VOICE_IDS[accent];

    try {
      abortControllerRef.current = new AbortController();

      // Always generate at 1.0 speed - we'll adjust with playbackRate
      // Get current session token if user is logged in
      const { data: { session } } = await supabase.auth.getSession();
      const headers: Record<string, string> = {
        "Content-Type": "application/json",
        apikey: import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY,
      };
      if (session?.access_token) {
        headers['Authorization'] = `Bearer ${session.access_token}`;
      }

      const response = await fetch(
        `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/elevenlabs-tts`,
        {
          method: "POST",
          headers,
          body: JSON.stringify({ text, speed: 1.0, voiceId }),
          signal: abortControllerRef.current.signal,
        }
      );

      if (!response.ok) {
        if (response.status === 429) {
          const err = await response.json().catch(() => ({}));
          const hint = (err as any)?.hint;
          const msg = hint
            ? 'You have reached the usage limit. Sign in for more!'
            : 'Usage limit reached. Please try again in a few minutes.';
          toast.error(msg, { duration: 5000 });
          setIsSpeaking(false);
          return;
        }

        let errorMessage = `TTS request failed: ${response.status}`;
        try {
          const err = await response.json();
          if (err && typeof err === 'object') {
            const anyErr = err as any;
            if (typeof anyErr.error === 'string') {
              errorMessage = anyErr.error;
            }
            const maybeMessage = anyErr?.details?.detail?.message;
            if (typeof maybeMessage === 'string' && maybeMessage.trim()) {
              errorMessage = maybeMessage;
            }
          }
        } catch {
          // ignore parse errors
        }

        throw new Error(errorMessage);
      }

      const audioBlob = await response.blob();
      
      // Cache the audio by word and accent
      audioCache.current = {
        word: text,
        accent,
        blob: audioBlob,
      };

      playAudioBlob(audioBlob, playbackRate, onEnd);
    } catch (error) {
      if (error instanceof Error && error.name === 'AbortError') {
        return;
      }
      console.error("Speech error:", error);
      setIsSpeaking(false);
      const msg = error instanceof Error ? error.message : "Failed to generate speech.";
      toast.error(msg || "Failed to generate speech.");
    }
  }, [getPlaybackRate, playAudioBlob]);

  const stop = useCallback(() => {
    // Stop active looping playback without disabling the loop setting
    setIsLoopingActive(false);
    
    if (loopTimeoutRef.current) {
      clearTimeout(loopTimeoutRef.current);
      loopTimeoutRef.current = null;
    }
    
    if (abortControllerRef.current) {
      abortControllerRef.current.abort();
    }
    
    if (audioRef.current) {
      audioRef.current.pause();
      audioRef.current = null;
    }
    
    setIsSpeaking(false);
  }, []);

  const toggleLoop = useCallback(() => {
    setIsLooping((prev) => !prev);
  }, []);

  const clearCache = useCallback(() => {
    audioCache.current = null;
  }, []);

  return {
    speak,
    stop,
    isSpeaking,
    isLoopingActive,
    speed,
    setSpeed,
    isRandomSpeed,
    setIsRandomSpeed,
    isLooping,
    toggleLoop,
    loopGap,
    setLoopGap,
    clearCache,
  };
}
