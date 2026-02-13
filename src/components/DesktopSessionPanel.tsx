import { useState } from 'react';
import { motion } from 'framer-motion';
import { ChevronLeft, ChevronRight, Clock, Settings, List, Repeat, Globe } from 'lucide-react';
import { Word, Level } from '@/data/oxfordVocabulary';
import { cn } from '@/lib/utils';
import { Popover, PopoverContent, PopoverTrigger } from '@/components/ui/popover';
import { Slider } from '@/components/ui/slider';
import { Switch } from '@/components/ui/switch';
import { Gauge, Shuffle } from 'lucide-react';
import { AllWordsPanel } from './AllWordsPanel';
import type { PhoneticAccent } from '@/pages/Index';

interface DesktopSessionPanelProps {
  words: Word[];
  level: Level;
  currentIndex: number;
  onWordSelect: (index: number) => void;
  onPrevious: () => void;
  onNext: () => void;
  isLearned: (wordId: string) => boolean;
  isBookmarked: (wordId: string) => boolean;
  // Settings props
  isLooping: boolean;
  speed: number;
  isRandomSpeed: boolean;
  loopGap: number;
  phoneticAccent: PhoneticAccent;
  onToggleLoop: () => void;
  onSpeedChange: (speed: number) => void;
  onRandomSpeedToggle: () => void;
  onLoopGapChange: (gap: number) => void;
  onPhoneticAccentChange: (accent: PhoneticAccent) => void;
}

export function DesktopSessionPanel({
  words,
  level,
  currentIndex,
  onWordSelect,
  onPrevious,
  onNext,
  isLearned,
  isBookmarked,
  isLooping,
  speed,
  isRandomSpeed,
  loopGap,
  phoneticAccent,
  onToggleLoop,
  onSpeedChange,
  onRandomSpeedToggle,
  onLoopGapChange,
  onPhoneticAccentChange,
}: DesktopSessionPanelProps) {
  const [showAllWords, setShowAllWords] = useState(false);
  // Get session words (current + next few)
  const sessionSize = 3;
  const sessionWords = words.slice(currentIndex, currentIndex + sessionSize);
  
  // Get upcoming words
  const upcomingStart = currentIndex + sessionSize;
  const upcomingWords = words.slice(upcomingStart, upcomingStart + 12);
  
  return (
    <div className="space-y-4">
      {/* Session Controls */}
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        className="rounded-2xl border-2 border-border bg-card p-5 shadow-soft"
      >
        <h3 className="mb-4 text-xs font-semibold uppercase tracking-wider text-muted-foreground">
          Session Controls
        </h3>
        
        {/* Previous / Next buttons */}
        <div className="flex gap-3">
          <motion.button
            whileHover={{ scale: 1.02 }}
            whileTap={{ scale: 0.98 }}
            onClick={onPrevious}
            className="flex flex-1 items-center justify-center gap-2 rounded-xl bg-muted px-4 py-3 text-sm font-medium text-foreground transition-colors hover:bg-muted/80"
          >
            <ChevronLeft className="h-4 w-4" />
            <span>Previous</span>
          </motion.button>
          
          <motion.button
            whileHover={{ scale: 1.02 }}
            whileTap={{ scale: 0.98 }}
            onClick={onNext}
            className="flex flex-1 items-center justify-center gap-2 rounded-xl bg-muted px-4 py-3 text-sm font-medium text-foreground transition-colors hover:bg-muted/80"
          >
            <span>Next</span>
            <ChevronRight className="h-4 w-4" />
          </motion.button>
        </div>
        
        {/* Timer and Settings row */}
        <div className="mt-4 flex items-center justify-between">
          <div className="flex items-center gap-2 text-xs text-muted-foreground">
            <Clock className="h-3.5 w-3.5" />
            <span>Session active</span>
          </div>
          
          <Popover>
            <PopoverTrigger asChild>
              <motion.button
                whileHover={{ scale: 1.05 }}
                whileTap={{ scale: 0.95 }}
                className="flex items-center gap-1.5 text-xs text-muted-foreground hover:text-foreground transition-colors"
              >
                <Settings className="h-3.5 w-3.5" />
                <span>Settings</span>
              </motion.button>
            </PopoverTrigger>
            <PopoverContent className="w-72 p-4" align="end">
              <div className="space-y-4">
                <h4 className="font-display text-sm font-semibold text-foreground">Playback Settings</h4>
                
                {/* Speed control */}
                <div className="space-y-2">
                  <div className="flex items-center justify-between">
                    <div className="flex items-center gap-1.5">
                      <Gauge className="h-3.5 w-3.5 text-accent" />
                      <span className="text-xs font-medium">Speed</span>
                    </div>
                    <span className="font-mono text-xs font-semibold text-foreground">
                      {isRandomSpeed ? 'Random' : `${speed.toFixed(1)}x`}
                    </span>
                  </div>
                  
                  <Slider
                    value={[speed]}
                    min={0.5}
                    max={1.5}
                    step={0.1}
                    onValueChange={([value]) => onSpeedChange(value)}
                    disabled={isRandomSpeed}
                    className={cn(isRandomSpeed && 'opacity-50')}
                  />
                </div>
                
                {/* Random speed toggle */}
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-1.5">
                    <Shuffle className="h-3.5 w-3.5 text-accent" />
                    <span className="text-xs font-medium">Random Speed</span>
                  </div>
                  <Switch
                    checked={isRandomSpeed}
                    onCheckedChange={onRandomSpeedToggle}
                  />
                </div>
                
                {/* Loop toggle */}
                <div className="flex items-center justify-between border-t border-border pt-3">
                  <div className="flex items-center gap-1.5">
                    <Repeat className="h-3.5 w-3.5 text-accent" />
                    <span className="text-xs font-medium">Loop Mode</span>
                  </div>
                  <Switch
                    checked={isLooping}
                    onCheckedChange={onToggleLoop}
                  />
                </div>
                
                {/* Loop gap control */}
                <div className="space-y-2">
                  <div className="flex items-center justify-between">
                    <div className="flex items-center gap-1.5">
                      <Clock className="h-3.5 w-3.5 text-accent" />
                      <span className="text-xs font-medium">Repeat Gap</span>
                    </div>
                    <span className="font-mono text-xs font-semibold text-foreground">
                      {loopGap.toFixed(1)}s
                    </span>
                  </div>
                  
                  <Slider
                    value={[loopGap]}
                    min={0.5}
                    max={5}
                    step={0.5}
                    onValueChange={([value]) => onLoopGapChange(value)}
                    disabled={!isLooping}
                    className={cn(!isLooping && 'opacity-50')}
                  />
                </div>

                {/* Phonetic Accent toggle */}
                <div className="flex items-center justify-between border-t border-border pt-3">
                  <div className="flex items-center gap-1.5">
                    <Globe className="h-3.5 w-3.5 text-accent" />
                    <span className="text-xs font-medium">Phonetics</span>
                  </div>
                  <div className="flex gap-1">
                    {[
                      { id: 'us', label: '🇺🇸' },
                      { id: 'uk', label: '🇬🇧' },
                    ].map((option) => (
                      <button
                        key={option.id}
                        onClick={() => onPhoneticAccentChange(option.id as PhoneticAccent)}
                        className={cn(
                          'rounded-md px-2 py-1 text-sm transition-all',
                          phoneticAccent === option.id
                            ? 'bg-accent text-accent-foreground'
                            : 'bg-muted text-muted-foreground hover:text-foreground'
                        )}
                      >
                        {option.label}
                      </button>
                    ))}
                  </div>
                </div>
              </div>
            </PopoverContent>
          </Popover>
        </div>
      </motion.div>
      
      {/* Current Session + Upcoming */}
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ delay: 0.1 }}
        className="rounded-2xl border-2 border-border bg-card p-5 shadow-soft"
      >
        {/* Current Session */}
        <div className="mb-4 flex items-center justify-between">
          <h3 className="text-xs font-semibold uppercase tracking-wider text-muted-foreground">
            Current Session
          </h3>
          <span className="rounded-full bg-accent/20 px-2 py-0.5 text-[10px] font-medium text-accent">
            Active
          </span>
        </div>
        
        <div className="mb-5 flex flex-wrap gap-2">
          {sessionWords.map((word, idx) => {
            const actualIndex = currentIndex + idx;
            const isCurrent = actualIndex === currentIndex;
            
            return (
              <motion.button
                key={word.id}
                whileHover={{ scale: 1.05 }}
                whileTap={{ scale: 0.95 }}
                onClick={() => onWordSelect(actualIndex)}
                className={cn(
                  'rounded-full px-3 py-1.5 text-sm font-medium transition-all',
                  isCurrent
                    ? 'bg-gradient-gold text-accent-foreground shadow-gold'
                    : isLearned(word.id)
                    ? 'bg-accent/20 text-accent'
                    : 'bg-muted text-foreground'
                )}
              >
                {word.word}
              </motion.button>
            );
          })}
        </div>
        
        {/* Upcoming */}
        {upcomingWords.length > 0 && (
          <>
            <div className="mb-3 flex items-center justify-between">
              <h4 className="text-xs font-semibold uppercase tracking-wider text-muted-foreground">
                Upcoming
              </h4>
              <span className="text-[10px] text-muted-foreground">
                Queue: {words.length - currentIndex - sessionSize}
              </span>
            </div>
            
            <div className="flex flex-wrap gap-2">
              {upcomingWords.map((word, idx) => {
                const actualIndex = upcomingStart + idx;
                
                return (
                  <motion.button
                    key={word.id}
                    whileHover={{ scale: 1.05 }}
                    whileTap={{ scale: 0.95 }}
                    onClick={() => onWordSelect(actualIndex)}
                    className={cn(
                      'rounded-full px-3 py-1.5 text-xs font-medium transition-all',
                      isLearned(word.id)
                        ? 'bg-accent/20 text-accent'
                        : 'bg-muted text-muted-foreground hover:text-foreground'
                    )}
                  >
                    {word.word}
                  </motion.button>
                );
              })}
            </div>
          </>
        )}

        {/* Show All Words Button */}
        <motion.button
          whileHover={{ scale: 1.02 }}
          whileTap={{ scale: 0.98 }}
          onClick={() => setShowAllWords(true)}
          className="mt-4 w-full flex items-center justify-center gap-2 rounded-xl border border-border bg-muted/50 px-4 py-2.5 text-xs font-medium text-muted-foreground hover:bg-muted hover:text-foreground transition-colors"
        >
          <List className="h-3.5 w-3.5" />
          <span>Show all words</span>
        </motion.button>
      </motion.div>

      {/* All Words Panel */}
      <AllWordsPanel
        isOpen={showAllWords}
        onClose={() => setShowAllWords(false)}
        words={words}
        level={level}
        currentIndex={currentIndex}
        onWordSelect={onWordSelect}
        isLearned={isLearned}
        isBookmarked={isBookmarked}
      />
    </div>
  );
}
