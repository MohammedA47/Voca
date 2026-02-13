import { useState, useEffect, useCallback } from 'react';
import { Level } from '@/data/oxfordVocabulary';
import { supabase } from '@/integrations/supabase/client';
import { useAuth } from './useAuth';

const STORAGE_KEY = 'oxford-vocabulary-bookmarks';

export interface Bookmarks {
  bookmarkedWords: Record<Level, string[]>;
}

const defaultBookmarks: Bookmarks = {
  bookmarkedWords: {
    A1: [],
    A2: [],
    B1: [],
    B2: [],
    C1: [],
    C2: [],
  },
};

export function useBookmarks() {
  const [bookmarks, setBookmarks] = useState<Bookmarks>(defaultBookmarks);
  const [loading, setLoading] = useState(true);
  const { user } = useAuth();

  // Load bookmarks from DB or localStorage
  useEffect(() => {
    const loadBookmarks = async () => {
      if (user) {
        // Load from database
        const { data, error } = await supabase
          .from('user_bookmarks')
          .select('level, word_id')
          .eq('user_id', user.id);

        if (!error && data) {
          const newBookmarks: Bookmarks = { bookmarkedWords: { A1: [], A2: [], B1: [], B2: [], C1: [], C2: [] } };
          data.forEach((item) => {
            const level = item.level as Level;
            if (newBookmarks.bookmarkedWords[level]) {
              newBookmarks.bookmarkedWords[level].push(item.word_id);
            }
          });
          setBookmarks(newBookmarks);
        }
      } else {
        // Load from localStorage for guests
        const stored = localStorage.getItem(STORAGE_KEY);
        if (stored) {
          try {
            const parsed = JSON.parse(stored);
            // Ensure all levels exist (migration from old format)
            const merged: Bookmarks = {
              bookmarkedWords: {
                A1: parsed.bookmarkedWords?.A1 || [],
                A2: parsed.bookmarkedWords?.A2 || [],
                B1: parsed.bookmarkedWords?.B1 || [],
                B2: parsed.bookmarkedWords?.B2 || [],
                C1: parsed.bookmarkedWords?.C1 || [],
                C2: parsed.bookmarkedWords?.C2 || [],
              },
            };
            setBookmarks(merged);
          } catch {
            setBookmarks(defaultBookmarks);
          }
        }
      }
      setLoading(false);
    };

    loadBookmarks();
  }, [user]);

  const saveLocalBookmarks = (newBookmarks: Bookmarks) => {
    setBookmarks(newBookmarks);
    localStorage.setItem(STORAGE_KEY, JSON.stringify(newBookmarks));
  };

  const addBookmark = useCallback(async (level: Level, wordId: string) => {
    if (user) {
      // Save to database
      const { error } = await supabase
        .from('user_bookmarks')
        .insert({ user_id: user.id, level, word_id: wordId });

      if (!error) {
        setBookmarks(prev => ({
          ...prev,
          bookmarkedWords: {
            ...prev.bookmarkedWords,
            [level]: [...prev.bookmarkedWords[level], wordId],
          },
        }));
      }
    } else {
      // Save to localStorage
      const newBookmarks = {
        ...bookmarks,
        bookmarkedWords: {
          ...bookmarks.bookmarkedWords,
          [level]: [...bookmarks.bookmarkedWords[level], wordId],
        },
      };
      saveLocalBookmarks(newBookmarks);
    }
  }, [user, bookmarks]);

  const removeBookmark = useCallback(async (level: Level, wordId: string) => {
    if (user) {
      // Delete from database
      const { error } = await supabase
        .from('user_bookmarks')
        .delete()
        .eq('user_id', user.id)
        .eq('level', level)
        .eq('word_id', wordId);

      if (!error) {
        setBookmarks(prev => ({
          ...prev,
          bookmarkedWords: {
            ...prev.bookmarkedWords,
            [level]: prev.bookmarkedWords[level].filter((id) => id !== wordId),
          },
        }));
      }
    } else {
      // Remove from localStorage
      const newBookmarks = {
        ...bookmarks,
        bookmarkedWords: {
          ...bookmarks.bookmarkedWords,
          [level]: bookmarks.bookmarkedWords[level].filter((id) => id !== wordId),
        },
      };
      saveLocalBookmarks(newBookmarks);
    }
  }, [user, bookmarks]);

  const isBookmarked = useCallback((level: Level, wordId: string) => {
    return bookmarks.bookmarkedWords[level]?.includes(wordId) ?? false;
  }, [bookmarks]);

  const getBookmarkedWords = useCallback(() => {
    return bookmarks.bookmarkedWords;
  }, [bookmarks]);

  return {
    bookmarks,
    loading,
    addBookmark,
    removeBookmark,
    isBookmarked,
    getBookmarkedWords,
  };
}
