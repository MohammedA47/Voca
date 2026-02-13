import { useState, useMemo } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { X, Bookmark, Volume2, CheckCircle } from 'lucide-react';
import { Word, oxfordWords, Level } from '@/data/oxfordVocabulary';
import { ScrollArea } from '@/components/ui/scroll-area';
import { cn } from '@/lib/utils';

type FilterType = 'all' | 'learned' | 'not-learned';

interface BookmarksPanelProps {
  isOpen?: boolean;
  isBookmarked: (level: Level, wordId: string) => boolean;
  isLearned: (level: Level, wordId: string) => boolean;
  onWordSelect: (word: Word, index: number) => void;
  onClose: () => void;
  variant?: 'mobile' | 'desktop';
}

export function BookmarksPanel({ isOpen = true, isBookmarked, isLearned, onWordSelect, onClose, variant = 'mobile' }: BookmarksPanelProps) {
  const [filter, setFilter] = useState<FilterType>('all');

  // Get all bookmarked words
  const bookmarkedWords: { word: Word; level: Level; index: number }[] = [];
  
  (Object.keys(oxfordWords) as Level[]).forEach((level) => {
    oxfordWords[level].forEach((word, index) => {
      if (isBookmarked(level, word.id)) {
        bookmarkedWords.push({ word, level, index });
      }
    });
  });

  const filteredWords = useMemo(() => {
    if (filter === 'all') return bookmarkedWords;
    return bookmarkedWords.filter(({ word, level }) => {
      const learned = isLearned(level, word.id);
      return filter === 'learned' ? learned : !learned;
    });
  }, [bookmarkedWords, filter, isLearned]);

  const learnedCount = bookmarkedWords.filter(({ word, level }) => isLearned(level, word.id)).length;
  const notLearnedCount = bookmarkedWords.length - learnedCount;

  const filters: { id: FilterType; label: string; count: number }[] = [
    { id: 'all', label: 'All', count: bookmarkedWords.length },
    { id: 'learned', label: 'Learned', count: learnedCount },
    { id: 'not-learned', label: 'To Learn', count: notLearnedCount },
  ];

  // Desktop variant - slide-in panel like Statistics
  if (variant === 'desktop') {
    return (
      <AnimatePresence>
        {isOpen && (
          <>
            {/* Backdrop */}
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              onClick={onClose}
              className="fixed inset-0 z-40 hidden bg-background/80 backdrop-blur-sm md:block"
            />

            {/* Panel */}
            <motion.div
              initial={{ opacity: 0, y: '100%' }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: '100%' }}
              transition={{ duration: 0.3, ease: 'easeOut' }}
              className="fixed inset-0 z-50 flex flex-col overflow-y-auto bg-background md:right-0 md:left-auto md:top-0 md:h-full md:w-full md:max-w-md md:bg-card md:shadow-xl"
            >
              {/* Header */}
              <div className="sticky top-0 z-10 flex items-center justify-between border-b border-border bg-card px-6 py-4">
                <div className="flex items-center gap-3">
                  <div className="flex h-10 w-10 items-center justify-center rounded-full bg-accent/10">
                    <Bookmark className="h-5 w-5 fill-accent text-accent" />
                  </div>
                  <h2 className="text-xl font-bold">Saved Words</h2>
                </div>
                <button
                  onClick={onClose}
                  className="rounded-full p-2 text-muted-foreground transition-colors hover:bg-muted hover:text-foreground"
                >
                  <X className="h-5 w-5" />
                </button>
              </div>

              {/* Stats Summary */}
              <div className="grid grid-cols-3 gap-4 border-b border-border p-6">
                <div className="rounded-xl border border-border bg-gradient-to-br from-accent/10 to-transparent p-4 text-center">
                  <div className="text-2xl font-bold">{bookmarkedWords.length}</div>
                  <div className="text-xs text-muted-foreground">Total Saved</div>
                </div>
                <div className="rounded-xl border border-border bg-gradient-to-br from-green-500/10 to-transparent p-4 text-center">
                  <div className="text-2xl font-bold">{learnedCount}</div>
                  <div className="text-xs text-muted-foreground">Learned</div>
                </div>
                <div className="rounded-xl border border-border bg-gradient-to-br from-orange-500/10 to-transparent p-4 text-center">
                  <div className="text-2xl font-bold">{notLearnedCount}</div>
                  <div className="text-xs text-muted-foreground">To Learn</div>
                </div>
              </div>

              {/* Filter Tabs */}
              {bookmarkedWords.length > 0 && (
                <div className="flex gap-2 border-b border-border px-6 py-3">
                  {filters.map((f) => (
                    <button
                      key={f.id}
                      onClick={() => setFilter(f.id)}
                      className={cn(
                        'flex items-center gap-1.5 rounded-full px-3 py-1.5 text-sm font-medium transition-colors',
                        filter === f.id
                          ? 'bg-accent text-accent-foreground'
                          : 'bg-muted text-muted-foreground hover:bg-muted/80'
                      )}
                    >
                      {f.label}
                      <span className={cn(
                        'rounded-full px-1.5 py-0.5 text-xs',
                        filter === f.id
                          ? 'bg-foreground/20'
                          : 'bg-background'
                      )}>
                        {f.count}
                      </span>
                    </button>
                  ))}
                </div>
              )}

              {/* Content */}
              <div className="flex-1 overflow-y-auto p-6 pb-24">
                {bookmarkedWords.length === 0 ? (
                  <div className="flex flex-col items-center justify-center py-16 text-center">
                    <div className="mb-4 text-4xl">🔖</div>
                    <h3 className="mb-2 text-lg font-semibold">No saved words yet</h3>
                    <p className="text-sm text-muted-foreground">
                      Click the bookmark icon on any word to save it here.
                    </p>
                  </div>
                ) : filteredWords.length === 0 ? (
                  <div className="flex flex-col items-center justify-center py-16 text-center">
                    <p className="text-muted-foreground">
                      No {filter === 'learned' ? 'learned' : 'unlearned'} words
                    </p>
                  </div>
                ) : (
                  <div className="space-y-3">
                    {filteredWords.map(({ word, level, index }) => {
                      const learned = isLearned(level, word.id);
                      return (
                        <motion.button
                          key={word.id}
                          whileHover={{ scale: 1.01 }}
                          whileTap={{ scale: 0.99 }}
                          onClick={() => onWordSelect(word, index)}
                          className="relative flex w-full items-center justify-between rounded-xl border border-border bg-card p-4 text-left transition-colors hover:border-primary/50 hover:bg-muted/30"
                        >
                          {learned && (
                            <div className="absolute -top-1.5 -right-1.5 flex items-center gap-0.5 rounded-full bg-gradient-gold px-1.5 py-0.5 text-[10px] font-medium text-accent-foreground shadow-gold">
                              <CheckCircle className="h-3 w-3" />
                            </div>
                          )}
                          <div className="flex-1">
                            <div className="flex items-center gap-2">
                              <span className="font-display text-lg font-semibold text-foreground">
                                {word.word}
                              </span>
                              <span className="rounded-full bg-accent/20 px-2 py-0.5 text-xs font-medium text-accent">
                                {level}
                              </span>
                            </div>
                            <p className="mt-1 text-sm text-muted-foreground">
                              /{word.phonetics.us}/
                            </p>
                          </div>
                          <Volume2 className="h-5 w-5 text-muted-foreground" />
                        </motion.button>
                      );
                    })}
                  </div>
                )}
              </div>
            </motion.div>
          </>
        )}
      </AnimatePresence>
    );
  }

  // Mobile variant - full screen
  return (
    <motion.div
      initial={{ opacity: 0, y: '100%' }}
      animate={{ opacity: 1, y: 0 }}
      exit={{ opacity: 0, y: '100%' }}
      transition={{ duration: 0.3, ease: 'easeOut' }}
      className="fixed inset-0 z-40 flex flex-col bg-background md:hidden"
    >
      {/* Header */}
      <div className="flex items-center justify-between border-b border-border px-4 py-3">
        <div className="flex items-center gap-2">
          <Bookmark className="h-5 w-5 fill-accent text-accent" />
          <h2 className="font-display text-lg font-semibold text-foreground">
            Saved Words
          </h2>
        </div>
        <button
          onClick={onClose}
          className="rounded-full p-2 text-muted-foreground hover:bg-muted"
        >
          <X className="h-5 w-5" />
        </button>
      </div>

      {/* Filter Tabs */}
      {bookmarkedWords.length > 0 && (
        <div className="flex gap-2 border-b border-border px-4 py-2">
          {filters.map((f) => (
            <button
              key={f.id}
              onClick={() => setFilter(f.id)}
              className={cn(
                'flex items-center gap-1.5 rounded-full px-3 py-1.5 text-sm font-medium transition-colors',
                filter === f.id
                  ? 'bg-accent text-accent-foreground'
                  : 'bg-muted text-muted-foreground hover:bg-muted/80'
              )}
            >
              {f.label}
              <span className={cn(
                'rounded-full px-1.5 py-0.5 text-xs',
                filter === f.id
                  ? 'bg-foreground/20'
                  : 'bg-background'
              )}>
                {f.count}
              </span>
            </button>
          ))}
        </div>
      )}

      {/* Content */}
      <ScrollArea className="flex-1 px-4 py-4 pb-24">
        {bookmarkedWords.length === 0 ? (
          <div className="flex flex-col items-center justify-center py-12 text-center">
            <Bookmark className="mb-4 h-12 w-12 text-muted-foreground/30" />
            <p className="text-muted-foreground">No saved words yet</p>
            <p className="mt-1 text-sm text-muted-foreground/70">
              Tap the bookmark icon to save words here
            </p>
          </div>
        ) : filteredWords.length === 0 ? (
          <div className="flex flex-col items-center justify-center py-12 text-center">
            <p className="text-muted-foreground">
              No {filter === 'learned' ? 'learned' : 'unlearned'} words
            </p>
          </div>
        ) : (
          <div className="space-y-2">
            <p className="mb-4 text-sm text-muted-foreground">
              {filteredWords.length} word{filteredWords.length !== 1 ? 's' : ''}
            </p>
            {filteredWords.map(({ word, level, index }) => {
              const learned = isLearned(level, word.id);
              return (
                <motion.button
                  key={word.id}
                  whileTap={{ scale: 0.98 }}
                  onClick={() => onWordSelect(word, index)}
                  className="relative flex w-full items-center justify-between rounded-xl border border-border bg-card p-3 text-left transition-colors hover:border-primary/50"
                >
                  {learned && (
                    <div className="absolute -top-1.5 -right-1.5 flex items-center gap-0.5 rounded-full bg-gradient-gold px-1.5 py-0.5 text-[10px] font-medium text-accent-foreground shadow-gold">
                      <CheckCircle className="h-3 w-3" />
                    </div>
                  )}
                  <div className="flex-1">
                    <div className="flex items-center gap-2">
                      <span className="font-display font-semibold text-foreground">
                        {word.word}
                      </span>
                      <span className="rounded-full bg-accent/20 px-2 py-0.5 text-xs font-medium text-accent">
                        {level}
                      </span>
                    </div>
                    <p className="mt-0.5 text-sm text-muted-foreground">
                      /{word.phonetics.us}/
                    </p>
                  </div>
                  <Volume2 className="h-4 w-4 text-muted-foreground" />
                </motion.button>
              );
            })}
          </div>
        )}
      </ScrollArea>
    </motion.div>
  );
}
