import { motion } from 'framer-motion';
import { Lock, Sparkles } from 'lucide-react';
import { Level, levelDescriptions } from '@/data/oxfordVocabulary';
import { cn } from '@/lib/utils';

interface DesktopLevelTabsProps {
  levels: Level[];
  selectedLevel: Level;
  onLevelChange: (level: Level) => void;
  variant?: 'mobile' | 'desktop';
}

export function DesktopLevelTabs({ levels, selectedLevel, onLevelChange, variant = 'desktop' }: DesktopLevelTabsProps) {
  const isMobile = variant === 'mobile';
  
  return (
    <div className="flex flex-col items-center gap-2">
      <div className="relative flex items-center rounded-full bg-muted p-1">
        {levels.map((level) => {
          const isSelected = selectedLevel === level;
          const isLocked = false; // Could implement unlock logic
          
          return (
            <motion.button
              key={level}
              onClick={() => onLevelChange(level)}
              whileTap={{ scale: 0.95 }}
              className={cn(
                'relative z-10 flex items-center gap-1 rounded-full font-semibold transition-colors duration-200',
                isMobile 
                  ? 'px-3 py-1.5 text-xs' 
                  : 'px-6 py-2.5 text-sm gap-2',
                isSelected
                  ? 'text-accent-foreground'
                  : 'text-muted-foreground hover:text-foreground'
              )}
            >
              {isSelected && (
                <motion.div
                  layoutId={`levelTabBackground-${variant}`}
                  className="absolute inset-0 rounded-full bg-gradient-gold shadow-gold"
                  transition={{ type: 'spring', stiffness: 400, damping: 30 }}
                />
              )}
              <span className={cn(
                "relative z-10 flex items-center",
                isMobile ? "gap-1" : "gap-2"
              )}>
                {isSelected && (
                  <motion.span
                    initial={{ scale: 0, opacity: 0 }}
                    animate={{ scale: 1, opacity: 1 }}
                    exit={{ scale: 0, opacity: 0 }}
                    transition={{ delay: 0.1 }}
                  >
                    <Sparkles className={cn(isMobile ? "h-3 w-3" : "h-4 w-4")} />
                  </motion.span>
                )}
                <span>{isMobile ? level : `Level ${level}`}</span>
              </span>
              {isLocked && !isSelected && (
                <Lock className="h-3.5 w-3.5" />
              )}
            </motion.button>
          );
        })}
      </div>
      <p className={cn(
        "text-muted-foreground",
        isMobile ? "text-[10px]" : "text-xs"
      )}>
        {levelDescriptions[selectedLevel].description}
      </p>
    </div>
  );
}
