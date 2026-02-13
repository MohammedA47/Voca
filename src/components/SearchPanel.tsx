import { useState, useMemo, useEffect } from 'react';
import { motion } from 'framer-motion';
import { Search, X, CheckCircle2, Clock, Trash2 } from 'lucide-react';
import { Input } from '@/components/ui/input';
import { ScrollArea } from '@/components/ui/scroll-area';
import { Word, Level } from '@/data/oxfordVocabulary';
import { cn } from '@/lib/utils';

const RECENT_SEARCHES_KEY = 'oxford-vocab-recent-searches';
const MAX_RECENT_SEARCHES = 10;

interface SearchPanelProps {
  words: Word[];
  allWords: Word[];
  onWordSelect: (word: Word, index: number) => void;
  isLearned: (level: Level, wordId: string) => boolean;
  onClose?: () => void;
  variant?: 'mobile' | 'desktop';
  initialQuery?: string;
}

function getRecentSearches(): string[] {
  try {
    const stored = localStorage.getItem(RECENT_SEARCHES_KEY);
    return stored ? JSON.parse(stored) : [];
  } catch {
    return [];
  }
}

function saveRecentSearch(query: string) {
  if (!query.trim()) return;
  const recent = getRecentSearches();
  const filtered = recent.filter((s) => s.toLowerCase() !== query.toLowerCase());
  const updated = [query.trim(), ...filtered].slice(0, MAX_RECENT_SEARCHES);
  localStorage.setItem(RECENT_SEARCHES_KEY, JSON.stringify(updated));
}

function removeRecentSearch(query: string) {
  const recent = getRecentSearches();
  const updated = recent.filter((s) => s.toLowerCase() !== query.toLowerCase());
  localStorage.setItem(RECENT_SEARCHES_KEY, JSON.stringify(updated));
  return updated;
}

function clearRecentSearches() {
  localStorage.removeItem(RECENT_SEARCHES_KEY);
}

export function SearchPanel({
  words,
  allWords,
  onWordSelect,
  isLearned,
  onClose,
  variant = 'mobile',
  initialQuery = '',
}: SearchPanelProps) {
  const [query, setQuery] = useState(initialQuery);
  const [recentSearches, setRecentSearches] = useState<string[]>([]);

  // Sync with external query changes
  useEffect(() => {
    if (initialQuery) {
      setQuery(initialQuery);
    }
  }, [initialQuery]);

  useEffect(() => {
    setRecentSearches(getRecentSearches());
  }, []);

  const filteredWords = useMemo(() => {
    if (!query.trim()) return allWords;
    const lowerQuery = query.toLowerCase();
    return allWords.filter(
      (word) =>
        word.word.toLowerCase().includes(lowerQuery) ||
        word.type.toLowerCase().includes(lowerQuery)
    );
  }, [query, allWords]);

  const handleWordClick = (word: Word) => {
    saveRecentSearch(query);
    const index = words.findIndex((w) => w.id === word.id && w.level === word.level);
    onWordSelect(word, index >= 0 ? index : 0);
    onClose?.();
  };

  const handleRecentClick = (searchTerm: string) => {
    setQuery(searchTerm);
  };

  const handleClearRecent = () => {
    clearRecentSearches();
    setRecentSearches([]);
  };

  const handleRemoveRecent = (e: React.MouseEvent, term: string) => {
    e.stopPropagation();
    const updated = removeRecentSearch(term);
    setRecentSearches(updated);
  };

  const showRecentSearches = !query.trim() && recentSearches.length > 0;

  if (variant === 'desktop') {
    return (
      <motion.div
        initial={{ opacity: 0, y: -10 }}
        animate={{ opacity: 1, y: 0 }}
        exit={{ opacity: 0, y: -10 }}
        className="rounded-2xl border-2 border-border bg-card p-4 shadow-soft md:p-5"
      >
        <div className="mb-4 flex items-center justify-between">
          <h3 className="font-display text-lg font-semibold text-foreground">
            Search Words
          </h3>
          {onClose && (
            <button
              onClick={onClose}
              className="rounded-full p-1.5 text-muted-foreground transition-colors hover:bg-muted hover:text-foreground"
            >
              <X className="h-4 w-4" />
            </button>
          )}
        </div>

        <div className="relative mb-4">
          <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
          <Input
            type="text"
            placeholder="Search by word or type..."
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            className="pl-10"
          />
        </div>

        <ScrollArea className="h-64">
          <div className="space-y-1 pr-4">
            {showRecentSearches ? (
              <div>
                <div className="mb-2 flex items-center justify-between">
                  <p className="flex items-center gap-1.5 text-xs font-medium text-muted-foreground">
                    <Clock className="h-3 w-3" />
                    Recent searches
                  </p>
                  <button
                    onClick={handleClearRecent}
                    className="flex items-center gap-1 text-xs text-muted-foreground hover:text-foreground"
                  >
                    <Trash2 className="h-3 w-3" />
                    Clear
                  </button>
                </div>
                <div className="flex flex-wrap gap-2">
                  {recentSearches.map((term, i) => (
                    <div
                      key={i}
                      className="group flex items-center gap-1 rounded-full border border-border bg-muted/50 pl-3 pr-1 py-1 text-sm text-foreground transition-colors hover:border-oxford-gold hover:bg-oxford-gold/10"
                    >
                      <button onClick={() => handleRecentClick(term)}>
                        {term}
                      </button>
                      <button
                        onClick={(e) => handleRemoveRecent(e, term)}
                        className="rounded-full p-0.5 text-muted-foreground opacity-0 transition-opacity hover:bg-muted hover:text-foreground group-hover:opacity-100"
                      >
                        <X className="h-3 w-3" />
                      </button>
                    </div>
                  ))}
                </div>
              </div>
            ) : filteredWords.length === 0 ? (
              <p className="py-4 text-center text-sm text-muted-foreground">
                No words found for "{query}"
              </p>
            ) : (
              filteredWords.map((word) => (
                <button
                  key={`${word.level}-${word.id}`}
                  onClick={() => handleWordClick(word)}
                  className="flex w-full items-center justify-between rounded-lg p-3 text-left transition-colors hover:bg-muted"
                >
                  <div className="flex-1">
                    <div className="flex items-center gap-2">
                      <span className="font-medium text-foreground">{word.word}</span>
                      <span className="rounded bg-oxford-gold/20 px-1.5 py-0.5 text-xs font-medium text-oxford-gold">
                        {word.level}
                      </span>
                    </div>
                    <p className="mt-0.5 line-clamp-1 text-xs text-muted-foreground italic">
                      {word.type}
                    </p>
                  </div>
                  {isLearned(word.level, word.id) && (
                    <CheckCircle2 className="ml-2 h-4 w-4 flex-shrink-0 text-oxford-gold" />
                  )}
                </button>
              ))
            )}
          </div>
        </ScrollArea>
      </motion.div>
    );
  }

  // Mobile variant - full screen
  return (
    <motion.div
      initial={{ opacity: 0, y: '100%' }}
      animate={{ opacity: 1, y: 0 }}
      exit={{ opacity: 0, y: '100%' }}
      transition={{ duration: 0.3, ease: 'easeOut' }}
      className="fixed inset-0 z-50 flex flex-col bg-background"
    >
      {/* Header */}
      <div className="flex items-center gap-3 border-b border-border p-4">
        <button
          onClick={onClose}
          className="rounded-full p-2 text-muted-foreground transition-colors hover:bg-muted"
        >
          <X className="h-5 w-5" />
        </button>
        <div className="relative flex-1">
          <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
          <Input
            type="text"
            placeholder="Search words..."
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            className="pl-10"
            autoFocus
          />
        </div>
      </div>

      {/* Results */}
      <ScrollArea className="flex-1">
        <div className="p-4 pb-24">
          {showRecentSearches ? (
            <div>
              <div className="mb-3 flex items-center justify-between">
                <p className="flex items-center gap-1.5 text-xs font-medium text-muted-foreground">
                  <Clock className="h-3 w-3" />
                  Recent searches
                </p>
                <button
                  onClick={handleClearRecent}
                  className="flex items-center gap-1 text-xs text-muted-foreground hover:text-foreground"
                >
                  <Trash2 className="h-3 w-3" />
                  Clear
                </button>
              </div>
              <div className="flex flex-wrap gap-2">
                {recentSearches.map((term, i) => (
                  <div
                    key={i}
                    className="flex items-center gap-1 rounded-full border border-border bg-muted/50 pl-3 pr-1.5 py-1.5 text-sm text-foreground transition-colors hover:border-oxford-gold hover:bg-oxford-gold/10"
                  >
                    <button onClick={() => handleRecentClick(term)}>
                      {term}
                    </button>
                    <button
                      onClick={(e) => handleRemoveRecent(e, term)}
                      className="rounded-full p-0.5 text-muted-foreground hover:bg-muted hover:text-foreground"
                    >
                      <X className="h-3.5 w-3.5" />
                    </button>
                  </div>
                ))}
              </div>
            </div>
          ) : query.trim() === '' ? (
            <div className="py-8 text-center">
              <Search className="mx-auto mb-3 h-12 w-12 text-muted-foreground/50" />
              <p className="text-sm text-muted-foreground">
                Search for words by name or type
              </p>
            </div>
          ) : filteredWords.length === 0 ? (
            <div className="py-8 text-center">
              <p className="text-sm text-muted-foreground">
                No words found for "{query}"
              </p>
            </div>
          ) : (
            <div className="space-y-2">
              <p className="mb-3 text-xs font-medium text-muted-foreground">
                {filteredWords.length} result{filteredWords.length !== 1 ? 's' : ''}
              </p>
              {filteredWords.map((word) => (
                <motion.button
                  key={`${word.level}-${word.id}`}
                  whileTap={{ scale: 0.98 }}
                  onClick={() => handleWordClick(word)}
                  className={cn(
                    'flex w-full items-center justify-between rounded-xl border-2 border-border bg-card p-4 text-left transition-colors',
                    isLearned(word.level, word.id) && 'border-oxford-gold/30 bg-oxford-gold/5'
                  )}
                >
                  <div className="flex-1">
                    <div className="flex items-center gap-2">
                      <span className="font-display font-semibold text-foreground">
                        {word.word}
                      </span>
                      <span className="rounded bg-oxford-gold/20 px-1.5 py-0.5 text-xs font-medium text-oxford-gold">
                        {word.level}
                      </span>
                    </div>
                    <p className="mt-1 text-xs text-muted-foreground">/{word.phonetics.us}/</p>
                    <p className="mt-2 line-clamp-2 text-sm text-muted-foreground italic">
                      {word.type}
                    </p>
                  </div>
                  {isLearned(word.level, word.id) && (
                    <CheckCircle2 className="ml-3 h-5 w-5 flex-shrink-0 text-oxford-gold" />
                  )}
                </motion.button>
              ))}
            </div>
          )}
        </div>
      </ScrollArea>
    </motion.div>
  );
}
