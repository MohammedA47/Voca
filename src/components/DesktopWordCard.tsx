import { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Bookmark, CheckCircle, Volume2, ChevronLeft, ChevronRight, Headphones, MessageSquareQuote, Square, Repeat } from 'lucide-react';
import { Word } from '@/data/oxfordVocabulary';
import { cn } from '@/lib/utils';
import type { PhoneticAccent } from '@/pages/Index';

interface DesktopWordCardProps {
  word: Word;
  isLearned: boolean;
  isBookmarked: boolean;
  isSpeaking?: boolean;
  isLooping?: boolean;
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
  learnedCount: number;
  dailyGoal?: number;
}

export function DesktopWordCard({
  word,
  isLearned,
  isBookmarked,
  isSpeaking = false,
  isLooping = false,
  phoneticAccent = 'us',
  onToggleLearned,
  onToggleBookmark,
  onPlayWord,
  onStop,
  onPlayExample,
  onPrevious,
  onNext,
  currentIndex,
  totalWords,
  learnedCount,
  dailyGoal = 20,
}: DesktopWordCardProps) {
  const [exampleIndex, setExampleIndex] = useState(0);
  const textTransition = { duration: 0.15, ease: "easeOut" as const };
  const progressPercent = Math.min((learnedCount / dailyGoal) * 100, 100);
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
    <div className="relative rounded-2xl border-2 border-border bg-card shadow-soft overflow-hidden">
      {/* Progress bar at top */}
      <div className="h-1 bg-muted">
        <motion.div
          className="h-full bg-gradient-gold"
          initial={{ width: 0 }}
          animate={{ width: `${progressPercent}%` }}
          transition={{ duration: 0.5 }}
        />
      </div>
      
      <div className="p-6 md:p-8">
        {/* Daily goal, loop indicator, and bookmark row */}
        <div className="mb-6 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <span className="text-xs font-semibold uppercase tracking-wider text-muted-foreground">
              Daily Goal: {learnedCount}/{dailyGoal}
            </span>
            {isLooping && (
              <motion.div
                initial={{ opacity: 0, scale: 0.8 }}
                animate={{ opacity: 1, scale: 1 }}
                className="flex items-center gap-1.5 rounded-full bg-primary/20 px-2.5 py-1"
              >
                <Repeat className="h-3 w-3 text-primary animate-pulse" />
                <span className="text-[10px] font-semibold uppercase tracking-wider text-primary">
                  Loop
                </span>
              </motion.div>
            )}
          </div>
          <motion.button
            whileTap={{ scale: 0.9 }}
            onClick={onToggleBookmark}
            className="rounded-full p-1 hover:bg-muted transition-colors"
          >
            <Bookmark className={cn(
              'h-5 w-5 transition-colors',
              isBookmarked ? 'fill-primary text-primary' : 'text-muted-foreground hover:text-primary'
            )} />
          </motion.button>
        </div>
        
        {/* Word with navigation arrows */}
        <div className="flex items-center justify-center gap-6">
          <motion.button
            whileTap={{ scale: 0.9 }}
            onClick={onPrevious}
            className="rounded-full p-3 text-muted-foreground hover:bg-muted hover:text-foreground transition-colors"
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
              className="font-display text-5xl font-bold text-foreground md:text-6xl"
            >
              {word.word}
            </motion.h2>
          </AnimatePresence>
          
          <motion.button
            whileTap={{ scale: 0.9 }}
            onClick={onNext}
            className="rounded-full p-3 text-muted-foreground hover:bg-muted hover:text-foreground transition-colors"
          >
            <ChevronRight className="h-6 w-6" />
          </motion.button>
        </div>
        
        {/* Phonetic with speaker */}
        <div className="mt-3 flex items-center justify-center gap-2">
          <AnimatePresence mode="wait">
            <motion.p
              key={word.id + "-phonetic-" + phoneticAccent}
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              transition={textTransition}
              className="font-mono text-lg text-muted-foreground"
            >
              <span className="text-xs text-primary/70 mr-1">{phoneticAccent.toUpperCase()}</span>
              /{phonetic}/
            </motion.p>
          </AnimatePresence>
          {onPlayWord && (
            <motion.button
              whileTap={{ scale: 0.9 }}
              onClick={isSpeaking ? onStop : onPlayWord}
              className={cn(
                "rounded-full p-2 transition-colors",
                isSpeaking 
                  ? "bg-primary/20 text-primary" 
                  : "text-primary/70 hover:bg-primary/10 hover:text-primary"
              )}
            >
              <Volume2 className="h-5 w-5" />
            </motion.button>
          )}
        </div>
        
        {/* Type card */}
        <div className="mt-6 rounded-xl bg-muted/50 p-5">
          <AnimatePresence mode="wait">
            <motion.div
              key={word.id + "-type"}
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              transition={textTransition}
              className="flex items-start gap-3"
            >
              <Bookmark className="mt-0.5 h-5 w-5 flex-shrink-0 text-primary" />
              <p className="text-base text-foreground leading-relaxed italic">
                {word.type}
              </p>
            </motion.div>
          </AnimatePresence>
        </div>
        
        {/* Example sentence with navigation */}
        {examples.length > 0 && (
          <div className="mt-6 space-y-2">
            <div className="flex items-center justify-center gap-2">
              {examples.length > 1 && (
                <motion.button
                  whileTap={{ scale: 0.9 }}
                  onClick={handlePrevExample}
                  className="rounded-full p-1.5 text-muted-foreground hover:bg-muted hover:text-foreground transition-colors"
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
                  className="rounded-full p-1.5 text-muted-foreground hover:bg-muted hover:text-foreground transition-colors"
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
                className="text-center text-lg italic text-muted-foreground"
              >
                <span className="text-primary">"</span>
                {example.split(new RegExp(`(${word.word})`, 'gi')).map((part, i) => (
                  <span key={i}>
                    {part.toLowerCase() === word.word.toLowerCase() ? (
                      <span className="font-semibold text-foreground underline decoration-primary decoration-2 underline-offset-4">
                        {part}
                      </span>
                    ) : (
                      part
                    )}
                  </span>
                ))}
                <span className="text-primary">"</span>
              </motion.p>
            </AnimatePresence>
          </div>
        )}
        
        {/* Action buttons */}
        <div className="mt-8 flex items-center justify-center gap-4">
          {onPlayWord && (
            <motion.button
              whileHover={{ scale: 1.02 }}
              whileTap={{ scale: 0.98 }}
              onClick={isSpeaking ? onStop : onPlayWord}
              className={cn(
                "flex items-center gap-2 rounded-full border-2 px-5 py-3 text-sm font-medium transition-colors",
                isSpeaking
                  ? "border-destructive bg-destructive/10 text-destructive"
                  : "border-border bg-card text-foreground hover:border-primary/30"
              )}
            >
              {isSpeaking ? (
                <>
                  <Square className="h-4 w-4" />
                  <span>Stop</span>
                </>
              ) : (
                <>
                  <Headphones className="h-4 w-4" />
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
              className="flex items-center gap-2 rounded-full border-2 border-border bg-card px-5 py-3 text-sm font-medium text-foreground transition-colors hover:border-primary/30"
            >
              <MessageSquareQuote className="h-4 w-4 text-primary" />
              <span>Example</span>
            </motion.button>
          )}
        </div>
        
        {/* Mark as Learned button */}
        <motion.button
          whileHover={{ scale: 1.01 }}
          whileTap={{ scale: 0.99 }}
          onClick={onToggleLearned}
          className={cn(
            'mt-6 flex w-full items-center justify-center gap-2 rounded-full py-4 text-base font-semibold transition-all',
            'bg-gradient-gold text-accent-foreground shadow-gold'
          )}
        >
          <CheckCircle className="h-5 w-5" />
          <span>{isLearned ? 'Learned!' : 'Mark as Learned'}</span>
        </motion.button>
        
        {/* Keyboard hint */}
        <p className="mt-3 text-center text-xs text-muted-foreground">
          Press <kbd className="rounded bg-muted px-1.5 py-0.5 font-mono text-[10px]">Space</kbd> to mark learned
        </p>
      </div>
    </div>
  );
}
