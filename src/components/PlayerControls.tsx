import { motion } from 'framer-motion';
import { Volume2, MessageSquareQuote, SkipBack, SkipForward, Repeat, Shuffle, Gauge, Clock, Square, Settings } from 'lucide-react';
import { Slider } from '@/components/ui/slider';
import { Switch } from '@/components/ui/switch';
import { Popover, PopoverContent, PopoverTrigger } from '@/components/ui/popover';
import { cn } from '@/lib/utils';

interface PlayerControlsProps {
  isPlaying: boolean;
  isLooping: boolean;
  speed: number;
  isRandomSpeed: boolean;
  loopGap: number;
  onPlayWord: () => void;
  onPlayExample: () => void;
  onStop: () => void;
  onPrevious: () => void;
  onNext: () => void;
  onToggleLoop: () => void;
  onSpeedChange: (speed: number) => void;
  onRandomSpeedToggle: () => void;
  onLoopGapChange: (gap: number) => void;
  currentIndex: number;
  totalWords: number;
}

export function PlayerControls({
  isPlaying,
  isLooping,
  speed,
  isRandomSpeed,
  loopGap,
  onPlayWord,
  onPlayExample,
  onStop,
  onPrevious,
  onNext,
  onToggleLoop,
  onSpeedChange,
  onRandomSpeedToggle,
  onLoopGapChange,
  currentIndex,
  totalWords,
}: PlayerControlsProps) {
  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      className="rounded-2xl border-2 border-border bg-card p-4 shadow-soft md:p-6"
    >
      {/* Progress indicator */}
      <div className="mb-4 text-center md:mb-6">
        <span className="text-xs font-medium text-muted-foreground md:text-sm">
          Word {currentIndex + 1} of {totalWords}
        </span>
        <div className="mx-auto mt-2 h-1 w-full max-w-xs overflow-hidden rounded-full bg-muted md:h-1.5">
          <motion.div
            className="h-full bg-gradient-gold"
            initial={{ width: 0 }}
            animate={{ width: `${((currentIndex + 1) / totalWords) * 100}%` }}
            transition={{ duration: 0.3 }}
          />
        </div>
      </div>
      
      {/* Play buttons */}
      <div className="flex items-center justify-center gap-3 md:gap-4">
        <motion.button
          whileHover={{ scale: 1.05 }}
          whileTap={{ scale: 0.95 }}
          onClick={isPlaying ? onStop : onPlayWord}
          className={cn(
            'flex items-center gap-2 rounded-full px-4 py-2.5 text-sm font-medium shadow-medium transition-all md:px-5 md:py-3 md:text-base',
            isPlaying
              ? 'bg-destructive text-destructive-foreground'
              : 'bg-gradient-navy text-primary-foreground'
          )}
        >
          {isPlaying ? (
            <>
              <Square className="h-4 w-4 md:h-5 md:w-5" />
              <span>Stop</span>
            </>
          ) : (
            <>
              <Volume2 className="h-4 w-4 md:h-5 md:w-5" />
              <span>Word</span>
            </>
          )}
        </motion.button>
        
        <motion.button
          whileHover={{ scale: 1.05 }}
          whileTap={{ scale: 0.95 }}
          onClick={onPlayExample}
          disabled={isPlaying}
          className={cn(
            'flex items-center gap-2 rounded-full px-4 py-2.5 text-sm font-medium transition-all md:px-5 md:py-3 md:text-base',
            'border-2 border-primary text-primary hover:bg-primary/10',
            isPlaying && 'cursor-not-allowed opacity-50'
          )}
        >
          <MessageSquareQuote className="h-4 w-4 md:h-5 md:w-5" />
          <span>Example</span>
        </motion.button>
      </div>
      
      {/* Navigation */}
      <div className="mt-4 flex items-center justify-center gap-6 md:mt-5 md:gap-8">
        <motion.button
          whileHover={{ scale: 1.05 }}
          whileTap={{ scale: 0.95 }}
          onClick={onPrevious}
          className="flex items-center gap-2 rounded-full bg-muted px-4 py-2 text-sm font-medium text-foreground transition-colors hover:bg-muted/80 md:px-5 md:py-2.5 md:text-base"
        >
          <SkipBack className="h-4 w-4 md:h-5 md:w-5" />
          <span>Previous</span>
        </motion.button>
        
        <motion.button
          whileHover={{ scale: 1.05 }}
          whileTap={{ scale: 0.95 }}
          onClick={onNext}
          className="flex items-center gap-2 rounded-full bg-muted px-4 py-2 text-sm font-medium text-foreground transition-colors hover:bg-muted/80 md:px-5 md:py-2.5 md:text-base"
        >
          <span>Next</span>
          <SkipForward className="h-4 w-4 md:h-5 md:w-5" />
        </motion.button>
      </div>
      
      {/* Loop toggle and Settings */}
      <div className="mt-4 flex items-center justify-center gap-3 md:mt-5">
        <motion.button
          whileHover={{ scale: 1.05 }}
          whileTap={{ scale: 0.95 }}
          onClick={onToggleLoop}
          className={cn(
            'flex items-center gap-2 rounded-full px-3 py-1.5 text-xs font-medium transition-all md:px-4 md:py-2 md:text-sm',
            isLooping
              ? 'bg-accent text-accent-foreground shadow-gold'
              : 'bg-muted text-muted-foreground hover:text-foreground'
          )}
        >
          <Repeat className={cn('h-3.5 w-3.5 md:h-4 md:w-4', isLooping && 'animate-spin')} style={{ animationDuration: '3s' }} />
          <span>{isLooping ? 'Loop On' : 'Loop Off'}</span>
        </motion.button>
        
        {/* Settings Popover */}
        <Popover>
          <PopoverTrigger asChild>
            <motion.button
              whileHover={{ scale: 1.05 }}
              whileTap={{ scale: 0.95 }}
              className="flex items-center gap-2 rounded-full bg-muted px-3 py-1.5 text-xs font-medium text-muted-foreground transition-all hover:text-foreground md:px-4 md:py-2 md:text-sm"
            >
              <Settings className="h-3.5 w-3.5 md:h-4 md:w-4" />
              <span>Settings</span>
            </motion.button>
          </PopoverTrigger>
          <PopoverContent className="w-72 p-4" align="center">
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
              
              {/* Loop gap control */}
              <div className="space-y-2 border-t border-border pt-3">
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
                />
              </div>
            </div>
          </PopoverContent>
        </Popover>
      </div>
    </motion.div>
  );
}
