import { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { BookOpen, CheckCircle, Circle, Volume2, Bookmark, ChevronLeft, ChevronRight, Square } from 'lucide-react';
import { Word } from '@/data/oxfordVocabulary';
import { cn } from '@/lib/utils';
import type { PhoneticAccent } from '@/pages/Index';

interface WordCardProps {
  word: Word;
  isLearned: boolean;
  isBookmarked: boolean;
  isCurrentWord: boolean;
  isSpeaking?: boolean;
  phoneticAccent?: PhoneticAccent;
  onToggleLearned: () => void;
  onToggleBookmark: () => void;
  onPlayWord?: () => void;
  onStop?: () => void;
  onPlayExample?: (example: string) => void;
  onPrevious?: () => void;
  onNext?: () => void;
  currentIndex: number;
  totalWords: number;
}

export function WordCard({
  word,
  isLearned,
  isBookmarked,
  isCurrentWord,
  isSpeaking = false,
  phoneticAccent = 'us',
  onToggleLearned,
  onToggleBookmark,
  onPlayWord,
  onStop,
  onPlayExample,
  onPrevious,
  onNext,
  currentIndex,
  totalWords
}: WordCardProps) {
  const [exampleIndex, setExampleIndex] = useState(0);
  const textTransition = { duration: 0.15, ease: "easeOut" as const };
  const examples = word.examples || [];
  const example = examples[exampleIndex] || '';
  const phonetic = phoneticAccent === 'uk' ? word.phonetics.uk : word.phonetics.us;

  // Reset example index when word changes
  useEffect(() => {
    setExampleIndex(0);
  }, [word.id]);

  const handlePrevExample = () => {
    setExampleIndex(prev => (prev - 1 + examples.length) % examples.length);
  };

  const handleNextExample = () => {
    setExampleIndex(prev => (prev + 1) % examples.length);
  };

  return (
    <div className={cn(
      'relative rounded-2xl p-5 transition-all duration-300 md:p-8',
      'border-2 shadow-medium',
      isCurrentWord ? 'border-oxford-gold/30 bg-card shadow-gold' : 'border-border bg-card',
      isLearned && 'bg-gradient-card'
    )}>
      {/* Combined status badge */}
      {isBookmarked && isLearned && (
        <div className="absolute -top-2 -right-2 flex items-center gap-1 rounded-full bg-gradient-gold px-2 py-1 text-xs font-medium text-accent-foreground shadow-gold">
          <Bookmark className="h-3 w-3 fill-current" />
          <CheckCircle className="h-3 w-3" />
        </div>
      )}
      
      {/* Word count indicator */}
      <div className="mb-4 flex items-center justify-between">
        <span className="text-xs font-medium uppercase tracking-wider text-muted-foreground">
          Word {currentIndex + 1} of {totalWords}
        </span>
        <motion.button
          whileTap={{ scale: 0.9 }}
          onClick={onToggleBookmark}
          className="rounded-full p-1 hover:bg-muted transition-colors"
        >
          <Bookmark className={cn(
            'h-5 w-5 transition-colors',
            isBookmarked ? 'fill-oxford-gold text-oxford-gold' : 'text-muted-foreground hover:text-oxford-gold'
          )} />
        </motion.button>
      </div>
      
      <div className="space-y-4 md:space-y-6">
        {/* Word and phonetic */}
        <div className="text-center">
          <div className="flex items-center justify-center gap-4">
            <motion.button
              whileTap={{ scale: 0.9 }}
              onClick={onPrevious}
              className="rounded-full p-2 text-muted-foreground hover:bg-muted hover:text-foreground transition-colors"
            >
              <ChevronLeft className="h-6 w-6" />
            </motion.button>
            
            <AnimatePresence mode="wait">
              <motion.h2 
                key={word.id}
                initial={{ opacity: 0, y: 8 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0, y: -8 }}
                transition={textTransition}
                className="font-display text-4xl font-bold text-foreground md:text-5xl"
              >
                {word.word}
              </motion.h2>
            </AnimatePresence>
            
            <motion.button
              whileTap={{ scale: 0.9 }}
              onClick={onNext}
              className="rounded-full p-2 text-muted-foreground hover:bg-muted hover:text-foreground transition-colors"
            >
              <ChevronRight className="h-6 w-6" />
            </motion.button>
          </div>
          <div className="mt-2 flex items-center justify-center gap-2">
            <AnimatePresence mode="wait">
              <motion.p 
                key={word.id + "-phonetic-" + phoneticAccent}
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                exit={{ opacity: 0 }}
                transition={textTransition}
                className="font-mono text-base text-muted-foreground md:text-lg"
              >
                <span className="text-xs text-oxford-gold/70 mr-1">{phoneticAccent.toUpperCase()}</span>
                /{phonetic}/
              </motion.p>
            </AnimatePresence>
            {onPlayWord && (
              <motion.button
                whileTap={{ scale: 0.9 }}
                onClick={onPlayWord}
                className="rounded-full p-1.5 text-oxford-gold/70 hover:bg-oxford-gold/10 hover:text-oxford-gold"
              >
                <Volume2 className="h-4 w-4" />
              </motion.button>
            )}
          </div>
        </div>
        
        {/* Type (word class) */}
        <div className="rounded-xl bg-oxford-gold/10 p-4">
          <AnimatePresence mode="wait">
            <motion.p 
              key={word.id + "-type"}
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              transition={textTransition}
              className="flex items-start gap-2 text-sm text-foreground md:text-base"
            >
              <BookOpen className="mt-0.5 h-4 w-4 flex-shrink-0 text-oxford-gold md:h-5 md:w-5" />
              <span className="italic">{word.type}</span>
            </motion.p>
          </AnimatePresence>
        </div>
        
        {/* Example with navigation */}
        {examples.length > 0 && (
          <div className="space-y-2">
            <div className="flex items-center justify-center gap-2">
              {examples.length > 1 && (
                <motion.button
                  whileTap={{ scale: 0.9 }}
                  onClick={handlePrevExample}
                  className="rounded-full p-1 text-muted-foreground hover:bg-muted hover:text-foreground transition-colors"
                >
                  <ChevronLeft className="h-4 w-4" />
                </motion.button>
              )}
              <span className="text-xs text-muted-foreground">
                Example {exampleIndex + 1} of {examples.length}
              </span>
              {examples.length > 1 && (
                <motion.button
                  whileTap={{ scale: 0.9 }}
                  onClick={handleNextExample}
                  className="rounded-full p-1 text-muted-foreground hover:bg-muted hover:text-foreground transition-colors"
                >
                  <ChevronRight className="h-4 w-4" />
                </motion.button>
              )}
            </div>
            <AnimatePresence mode="wait">
              <motion.p 
                key={word.id + "-example-" + exampleIndex}
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                exit={{ opacity: 0 }}
                transition={textTransition}
                className="text-center text-sm italic text-muted-foreground md:text-base"
              >
                <span className="text-oxford-gold">"</span>
                {example.split(new RegExp(`(${word.word})`, 'gi')).map((part, i) => (
                  <span key={i}>
                    {part.toLowerCase() === word.word.toLowerCase() ? (
                      <span className="font-semibold text-foreground underline decoration-oxford-gold decoration-2 underline-offset-4">
                        {part}
                      </span>
                    ) : (
                      part
                    )}
                  </span>
                ))}
                <span className="text-oxford-gold">"</span>
              </motion.p>
            </AnimatePresence>
          </div>
        )}
        
        {/* Action buttons */}
        <div className="flex items-center justify-center gap-3">
          {onPlayWord && (
            <motion.button
              whileHover={{ scale: 1.02 }}
              whileTap={{ scale: 0.98 }}
              onClick={isSpeaking ? onStop : onPlayWord}
              className={cn(
                "flex items-center gap-2 rounded-full border-2 px-4 py-2.5 text-sm font-medium transition-colors",
                isSpeaking
                  ? "border-destructive bg-destructive/10 text-destructive hover:bg-destructive/20"
                  : "border-border bg-card text-foreground hover:border-oxford-gold/30"
              )}
            >
              {isSpeaking ? (
                <>
                  <Square className="h-4 w-4" />
                  <span>Stop</span>
                </>
              ) : (
                <>
                  <Volume2 className="h-4 w-4" />
                  <span>Listen</span>
                </>
              )}
            </motion.button>
          )}
          
          {onPlayExample && example && (
            <motion.button
              whileHover={{ scale: 1.02 }}
              whileTap={{ scale: 0.98 }}
              onClick={() => onPlayExample(example)}
              className="flex items-center gap-2 rounded-full border-2 border-border bg-card px-4 py-2.5 text-sm font-medium text-foreground transition-colors hover:border-oxford-gold/30"
            >
              <BookOpen className="h-4 w-4 text-oxford-gold" />
              <span>Example</span>
            </motion.button>
          )}
        </div>
        
        {/* Mark as Learned button */}
        <motion.button
          whileHover={{ scale: 1.02 }}
          whileTap={{ scale: 0.98 }}
          onClick={onToggleLearned}
          className={cn(
            'flex w-full items-center justify-center gap-2 rounded-full py-3.5 text-sm font-semibold transition-all md:text-base',
            'bg-gradient-gold text-accent-foreground shadow-gold'
          )}
        >
          <CheckCircle className="h-5 w-5" />
          <span>{isLearned ? 'Learned!' : 'Mark as Learned'}</span>
        </motion.button>
      </div>
    </div>
  );
}
