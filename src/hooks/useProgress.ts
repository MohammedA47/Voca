import { useState, useEffect, useCallback } from 'react';
import { Level } from '@/data/oxfordVocabulary';
import { supabase } from '@/integrations/supabase/client';
import { useAuth } from './useAuth';

const STORAGE_KEY = 'oxford-vocabulary-progress';

export interface Progress {
  learnedWords: Record<Level, string[]>;
}

const defaultProgress: Progress = {
  learnedWords: {
    A1: [],
    A2: [],
    B1: [],
    B2: [],
    C1: [],
    C2: [],
  },
};

export function useProgress() {
  const [progress, setProgress] = useState<Progress>(defaultProgress);
  const [loading, setLoading] = useState(true);
  const { user } = useAuth();

  // Load progress from DB or localStorage
  useEffect(() => {
    const loadProgress = async () => {
      if (user) {
        // Load from database
        const { data, error } = await supabase
          .from('user_progress')
          .select('level, word_id')
          .eq('user_id', user.id);

        if (!error && data) {
          const newProgress: Progress = { learnedWords: { A1: [], A2: [], B1: [], B2: [], C1: [], C2: [] } };
          data.forEach((item) => {
            const level = item.level as Level;
            if (newProgress.learnedWords[level]) {
              newProgress.learnedWords[level].push(item.word_id);
            }
          });
          setProgress(newProgress);
        }
      } else {
        // Load from localStorage for guests
        const stored = localStorage.getItem(STORAGE_KEY);
        if (stored) {
          try {
            const parsed = JSON.parse(stored);
            // Ensure all levels exist (migration from old format)
            const merged: Progress = {
              learnedWords: {
                A1: parsed.learnedWords?.A1 || [],
                A2: parsed.learnedWords?.A2 || [],
                B1: parsed.learnedWords?.B1 || [],
                B2: parsed.learnedWords?.B2 || [],
                C1: parsed.learnedWords?.C1 || [],
                C2: parsed.learnedWords?.C2 || [],
              },
            };
            setProgress(merged);
          } catch {
            setProgress(defaultProgress);
          }
        }
      }
      setLoading(false);
    };

    loadProgress();
  }, [user]);

  const saveLocalProgress = (newProgress: Progress) => {
    setProgress(newProgress);
    localStorage.setItem(STORAGE_KEY, JSON.stringify(newProgress));
  };

  const markAsLearned = useCallback(async (level: Level, wordId: string) => {
    if (user) {
      // Save to database
      const { error } = await supabase
        .from('user_progress')
        .insert({ user_id: user.id, level, word_id: wordId });

      if (!error) {
        setProgress(prev => ({
          ...prev,
          learnedWords: {
            ...prev.learnedWords,
            [level]: [...prev.learnedWords[level], wordId],
          },
        }));
      }
    } else {
      // Save to localStorage
      const newProgress = {
        ...progress,
        learnedWords: {
          ...progress.learnedWords,
          [level]: [...progress.learnedWords[level], wordId],
        },
      };
      saveLocalProgress(newProgress);
    }
  }, [user, progress]);

  const unmarkAsLearned = useCallback(async (level: Level, wordId: string) => {
    if (user) {
      // Delete from database
      const { error } = await supabase
        .from('user_progress')
        .delete()
        .eq('user_id', user.id)
        .eq('level', level)
        .eq('word_id', wordId);

      if (!error) {
        setProgress(prev => ({
          ...prev,
          learnedWords: {
            ...prev.learnedWords,
            [level]: prev.learnedWords[level].filter((id) => id !== wordId),
          },
        }));
      }
    } else {
      // Remove from localStorage
      const newProgress = {
        ...progress,
        learnedWords: {
          ...progress.learnedWords,
          [level]: progress.learnedWords[level].filter((id) => id !== wordId),
        },
      };
      saveLocalProgress(newProgress);
    }
  }, [user, progress]);

  const isLearned = useCallback((level: Level, wordId: string) => {
    return progress.learnedWords[level]?.includes(wordId) ?? false;
  }, [progress]);

  const getProgressForLevel = useCallback((level: Level, totalWords: number) => {
    const learned = progress.learnedWords[level]?.length ?? 0;
    return Math.round((learned / totalWords) * 100);
  }, [progress]);

  const resetProgress = useCallback(async () => {
    if (user) {
      // Delete all progress from database
      await supabase
        .from('user_progress')
        .delete()
        .eq('user_id', user.id);
    }
    setProgress(defaultProgress);
    localStorage.removeItem(STORAGE_KEY);
  }, [user]);

  return {
    progress,
    loading,
    markAsLearned,
    unmarkAsLearned,
    isLearned,
    getProgressForLevel,
    resetProgress,
  };
}
