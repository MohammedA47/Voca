import { useState, useEffect, useRef, useCallback, useMemo } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { X, Search, Check, Filter } from 'lucide-react';
import { Word, Level } from '@/data/oxfordVocabulary';
import { ScrollArea } from '@/components/ui/scroll-area';
import { Badge } from '@/components/ui/badge';
import { cn } from '@/lib/utils';

interface AllWordsPanelProps {
  isOpen: boolean;
  onClose: () => void;
  words: Word[];
  level: Level;
  currentIndex: number;
  onWordSelect: (index: number) => void;
  isLearned: (wordId: string) => boolean;
  isBookmarked: (wordId: string) => boolean;
}

export function AllWordsPanel({
  isOpen,
  onClose,
  words,
  level,
  currentIndex,
  onWordSelect,
  isLearned,
  isBookmarked,
}: AllWordsPanelProps) {
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedTypes, setSelectedTypes] = useState<string[]>([]);
  const [highlightedIndex, setHighlightedIndex] = useState<number>(0);
  const itemRefs = useRef<(HTMLButtonElement | null)[]>([]);

  // Extract unique word types from the words list
  const wordTypes = useMemo(() => {
    const types = new Set<string>();
    words.forEach(word => {
      // Handle multiple types (e.g., "noun, verb")
      word.type.split(',').forEach(t => types.add(t.trim().toLowerCase()));
    });
    return Array.from(types).sort();
  }, [words]);

  const filteredWords = useMemo(() => {
    return words.filter(word => {
      const matchesSearch = 
        word.word.toLowerCase().includes(searchQuery.toLowerCase()) ||
        word.type.toLowerCase().includes(searchQuery.toLowerCase());
      
      const matchesType = selectedTypes.length === 0 || 
        selectedTypes.some(type => 
          word.type.toLowerCase().includes(type.toLowerCase())
        );
      
      return matchesSearch && matchesType;
    });
  }, [words, searchQuery, selectedTypes]);

  const learnedCount = words.filter(w => isLearned(w.id)).length;

  const toggleType = (type: string) => {
    setSelectedTypes(prev => 
      prev.includes(type) 
        ? prev.filter(t => t !== type)
        : [...prev, type]
    );
  };

  const clearFilters = () => {
    setSelectedTypes([]);
    setSearchQuery('');
  };

  // Reset highlighted index when search/filter changes or panel opens
  useEffect(() => {
    if (isOpen) {
      const currentInFiltered = filteredWords.findIndex(
        w => words.findIndex(ow => ow.id === w.id) === currentIndex
      );
      setHighlightedIndex(currentInFiltered >= 0 ? currentInFiltered : 0);
    }
  }, [isOpen, searchQuery, selectedTypes, filteredWords, words, currentIndex]);

  // Scroll highlighted item into view
  useEffect(() => {
    if (itemRefs.current[highlightedIndex]) {
      itemRefs.current[highlightedIndex]?.scrollIntoView({
        behavior: 'smooth',
        block: 'nearest',
      });
    }
  }, [highlightedIndex]);

  const handleWordClick = (index: number) => {
    onWordSelect(index);
    onClose();
  };

  const handleKeyDown = useCallback((e: KeyboardEvent) => {
    if (!isOpen || filteredWords.length === 0) return;

    switch (e.key) {
      case 'ArrowDown':
        e.preventDefault();
        setHighlightedIndex(prev => 
          prev < filteredWords.length - 1 ? prev + 1 : 0
        );
        break;
      case 'ArrowUp':
        e.preventDefault();
        setHighlightedIndex(prev => 
          prev > 0 ? prev - 1 : filteredWords.length - 1
        );
        break;
      case 'Enter':
        e.preventDefault();
        if (highlightedIndex >= 0 && highlightedIndex < filteredWords.length) {
          const word = filteredWords[highlightedIndex];
          const originalIndex = words.findIndex(w => w.id === word.id);
          handleWordClick(originalIndex);
        }
        break;
      case 'Escape':
        e.preventDefault();
        onClose();
        break;
    }
  }, [isOpen, filteredWords, highlightedIndex, words, onClose]);

  useEffect(() => {
    document.addEventListener('keydown', handleKeyDown);
    return () => document.removeEventListener('keydown', handleKeyDown);
  }, [handleKeyDown]);

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
            className="fixed inset-0 z-50 bg-black/60 backdrop-blur-sm"
          />

          {/* Panel */}
          <motion.div
            initial={{ x: '100%' }}
            animate={{ x: 0 }}
            exit={{ x: '100%' }}
            transition={{ type: 'spring', damping: 25, stiffness: 200 }}
            className="fixed right-0 top-0 z-50 h-full w-full max-w-md border-l border-border bg-card shadow-2xl"
          >
            {/* Header */}
            <div className="border-b border-border p-4">
              <div className="flex items-center justify-between">
                <div>
                  <h2 className="font-display text-lg font-bold text-foreground">
                    All Words
                  </h2>
                  <p className="text-sm text-muted-foreground">
                    {level} Level • {words.length} words • {learnedCount} learned
                  </p>
                </div>
                <motion.button
                  whileHover={{ scale: 1.1 }}
                  whileTap={{ scale: 0.9 }}
                  onClick={onClose}
                  className="rounded-full p-2 hover:bg-muted transition-colors"
                >
                  <X className="h-5 w-5" />
                </motion.button>
              </div>

              {/* Search */}
              <div className="mt-4 relative">
                <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
                <input
                  type="text"
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  placeholder="Search words..."
                  className="w-full rounded-xl border border-border bg-muted/50 py-2.5 pl-10 pr-4 text-sm text-foreground placeholder:text-muted-foreground focus:border-accent focus:outline-none focus:ring-1 focus:ring-accent"
                />
              </div>

              {/* Type Filter */}
              <div className="mt-3">
                <div className="flex items-center justify-between mb-2">
                  <div className="flex items-center gap-1.5 text-xs text-muted-foreground">
                    <Filter className="h-3 w-3" />
                    <span>Filter by type</span>
                  </div>
                  {selectedTypes.length > 0 && (
                    <button
                      onClick={clearFilters}
                      className="text-xs text-accent hover:underline"
                    >
                      Clear
                    </button>
                  )}
                </div>
                <div className="flex flex-wrap gap-1.5">
                  {wordTypes.slice(0, 12).map((type) => (
                    <Badge
                      key={type}
                      variant={selectedTypes.includes(type) ? 'default' : 'outline'}
                      className={cn(
                        'cursor-pointer text-xs capitalize transition-all',
                        selectedTypes.includes(type)
                          ? 'bg-accent text-accent-foreground hover:bg-accent/90'
                          : 'hover:bg-muted'
                      )}
                      onClick={() => toggleType(type)}
                    >
                      {type}
                    </Badge>
                  ))}
                </div>
              </div>
            </div>

            {/* Word List */}
            <ScrollArea className="h-[calc(100%-220px)]">
              <div className="p-4 space-y-1">
                {filteredWords.map((word, idx) => {
                  const originalIndex = words.findIndex(w => w.id === word.id);
                  const isCurrent = originalIndex === currentIndex;
                  const learned = isLearned(word.id);
                  const bookmarked = isBookmarked(word.id);

                  const isHighlighted = idx === highlightedIndex;

                  return (
                    <motion.button
                      key={word.id}
                      ref={(el) => { itemRefs.current[idx] = el; }}
                      whileTap={{ scale: 0.99 }}
                      onClick={() => handleWordClick(originalIndex)}
                      onMouseEnter={() => setHighlightedIndex(idx)}
                      className={cn(
                        'w-full rounded-xl p-3 text-left transition-all',
                        isCurrent
                          ? 'bg-gradient-gold text-accent-foreground shadow-gold'
                          : isHighlighted
                          ? 'bg-muted ring-2 ring-accent/50'
                          : 'hover:bg-muted'
                      )}
                    >
                      <div className="flex items-center justify-between">
                        <div className="flex items-center gap-3">
                          <span className={cn(
                            'text-xs font-mono w-8',
                            isCurrent ? 'text-accent-foreground/70' : 'text-muted-foreground'
                          )}>
                            {originalIndex + 1}
                          </span>
                          <div>
                            <span className={cn(
                              'font-medium',
                              isCurrent ? 'text-accent-foreground' : 'text-foreground'
                            )}>
                              {word.word}
                            </span>
                            <p className={cn(
                              'text-xs line-clamp-1 italic',
                              isCurrent ? 'text-accent-foreground/70' : 'text-muted-foreground'
                            )}>
                              {word.type}
                            </p>
                          </div>
                        </div>
                        <div className="flex items-center gap-2">
                          {bookmarked && (
                            <span className={cn(
                              'text-[10px] px-1.5 py-0.5 rounded-full',
                              isCurrent ? 'bg-accent-foreground/20' : 'bg-accent/20 text-accent'
                            )}>
                              Saved
                            </span>
                          )}
                          {learned && (
                            <div className={cn(
                              'rounded-full p-1',
                              isCurrent ? 'bg-accent-foreground/20' : 'bg-accent/20'
                            )}>
                              <Check className={cn(
                                'h-3 w-3',
                                isCurrent ? 'text-accent-foreground' : 'text-accent'
                              )} />
                            </div>
                          )}
                        </div>
                      </div>
                    </motion.button>
                  );
                })}

                {filteredWords.length === 0 && (
                  <div className="text-center py-12 text-muted-foreground">
                    No words found matching "{searchQuery}"
                  </div>
                )}
              </div>
            </ScrollArea>
          </motion.div>
        </>
      )}
    </AnimatePresence>
  );
}
