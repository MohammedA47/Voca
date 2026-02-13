import { useState, useRef } from 'react';
import { motion, AnimatePresence, PanInfo } from 'framer-motion';
import { Word } from '@/data/oxfordVocabulary';
import { cn } from '@/lib/utils';
import { ChevronDown, CheckCircle } from 'lucide-react';
import { ScrollArea } from '@/components/ui/scroll-area';
interface UpNextSectionProps {
  words: Word[];
  currentIndex: number;
  onWordSelect: (index: number) => void;
  isLearned: (wordId: string) => boolean;
}
export function UpNextSection({
  words,
  currentIndex,
  onWordSelect,
  isLearned
}: UpNextSectionProps) {
  const [isExpanded, setIsExpanded] = useState(false);
  const learnedCount = words.filter(w => isLearned(w.id)).length;
  const progressPercent = learnedCount / words.length * 100;
  const constraintsRef = useRef(null);
  const handleDragEnd = (_: any, info: PanInfo) => {
    // Swipe up to expand, swipe down to collapse
    if (info.offset.y < -50 && !isExpanded) {
      setIsExpanded(true);
    } else if (info.offset.y > 50 && isExpanded) {
      setIsExpanded(false);
    }
  };
  const handleWordClick = (index: number) => {
    onWordSelect(index);
    setIsExpanded(false);
  };
  return <>
      {/* Mobile: Expandable docked bar */}
      <div className="md:hidden" ref={constraintsRef}>
        {/* Backdrop overlay when expanded */}
        <AnimatePresence>
          {isExpanded && <motion.div initial={{
          opacity: 0
        }} animate={{
          opacity: 1
        }} exit={{
          opacity: 0
        }} className="fixed inset-0 z-30 bg-background/80 backdrop-blur-sm" onClick={() => setIsExpanded(false)} />}
        </AnimatePresence>

        {/* Expandable container */}
        <motion.div drag="y" dragConstraints={{
        top: 0,
        bottom: 0
      }} dragElastic={0.2} onDragEnd={handleDragEnd} animate={{
        height: isExpanded ? '70vh' : 96,
        y: isExpanded ? 64 : 0
      }} transition={{
        duration: 0.35,
        ease: [0.4, 0, 0.2, 1]
      }} className="fixed left-0 right-0 bottom-16 z-40 bg-card border-t border-border rounded-t-2xl shadow-lg" style={{
        touchAction: 'none'
      }}>
          {/* Drag handle */}
          <div className="flex justify-center py-2 cursor-grab active:cursor-grabbing">
            <div className="h-1 w-10 rounded-full bg-muted-foreground/30" />
          </div>

          {/* Header */}
          <div className="flex items-center justify-between px-4 pb-2">
            <div className="flex items-center gap-3">
              <h3 className="text-xs font-semibold uppercase tracking-wider text-muted-foreground">
                {isExpanded ? 'All Words' : 'Up Next'}
              </h3>
              <span className="text-xs text-muted-foreground">
                {learnedCount}/{words.length} learned
              </span>
            </div>
            
          </div>

          {/* Content */}
          <AnimatePresence mode="wait">
            {isExpanded ? <motion.div key="expanded" initial={{
            opacity: 0
          }} animate={{
            opacity: 1
          }} exit={{
            opacity: 0
          }} transition={{
            duration: 0.15
          }}>
                <ScrollArea className="h-[calc(70vh-80px)] px-4">
                  <div className="grid grid-cols-2 gap-2 pb-6">
                    {words.map((word, index) => {
                  const isActive = index === currentIndex;
                  const learned = isLearned(word.id);
                  return <motion.button key={word.id} whileTap={{
                    scale: 0.97
                  }} onClick={() => handleWordClick(index)} className={cn('flex items-center justify-between rounded-xl px-4 py-3 text-left transition-all', isActive ? 'bg-primary text-primary-foreground' : learned ? 'bg-accent/10 border border-accent/30' : 'bg-muted/50 border border-border')}>
                          <div>
                            <p className={cn('font-medium text-sm', isActive ? 'text-primary-foreground' : 'text-foreground')}>
                              {word.word}
                            </p>
                            <p className={cn('text-xs mt-0.5', isActive ? 'text-primary-foreground/70' : 'text-muted-foreground')}>
                              {word.level}
                            </p>
                          </div>
                          {learned && !isActive && <CheckCircle className="h-4 w-4 text-accent" />}
                        </motion.button>;
                })}
                  </div>
                </ScrollArea>
              </motion.div> : <motion.div key="collapsed" initial={{
            opacity: 0
          }} animate={{
            opacity: 1
          }} exit={{
            opacity: 0
          }} transition={{
            duration: 0.15
          }} className="px-4 pb-3">
                <div className="flex gap-2 overflow-x-auto scrollbar-hide" style={{
              scrollbarWidth: 'none',
              msOverflowStyle: 'none'
            }}>
                  {words.map((word, index) => {
                const isActive = index === currentIndex;
                const learned = isLearned(word.id);
                return <motion.button key={word.id} whileTap={{
                  scale: 0.95
                }} onClick={() => onWordSelect(index)} className={cn('flex-shrink-0 rounded-full px-3 py-1.5 text-sm font-medium transition-all', isActive ? 'bg-muted text-foreground underline decoration-accent decoration-2 underline-offset-4' : learned ? 'border border-accent/30 bg-accent/5 text-accent' : 'border border-border bg-card text-muted-foreground')}>
                        {word.word}
                      </motion.button>;
              })}
                </div>
              </motion.div>}
          </AnimatePresence>
        </motion.div>
      </div>
    </>;
}