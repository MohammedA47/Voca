import { motion } from 'framer-motion';
import { ChevronDown } from 'lucide-react';
import { Badge } from '@/components/ui/badge';
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger } from '@/components/ui/dropdown-menu';
import { cn } from '@/lib/utils';

const MAIN_TYPES = ['noun', 'verb', 'adjective', 'adverb'];

interface MobileFiltersProps {
  wordTypes: string[];
  selectedTypes: string[];
  onTypeToggle: (type: string) => void;
  onClearTypes: () => void;
}

export function MobileFilters({
  wordTypes,
  selectedTypes,
  onTypeToggle,
  onClearTypes,
}: MobileFiltersProps) {
  const mainTypes = wordTypes.filter(t => MAIN_TYPES.includes(t));
  const otherTypes = wordTypes.filter(t => !MAIN_TYPES.includes(t));
  const selectedOtherCount = selectedTypes.filter(t => otherTypes.includes(t)).length;

  if (wordTypes.length === 0) return null;

  return (
    <motion.div
      initial={{ opacity: 0, y: 10 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ delay: 0.15 }}
      className="flex flex-col gap-2"
    >
      <div className="flex items-center justify-between">
        <span className="text-[10px] font-medium uppercase tracking-wider text-muted-foreground">
          Filter by type
        </span>
        <button
          onClick={onClearTypes}
          disabled={selectedTypes.length === 0}
          className={cn(
            "text-[10px] font-semibold uppercase tracking-wider transition-all duration-300",
            selectedTypes.length > 0
              ? "text-primary hover:text-primary/80 opacity-100"
              : "opacity-0 pointer-events-none"
          )}
        >
          Clear
        </button>
      </div>
      <div className="flex flex-wrap items-center gap-1.5">
        {/* Main types */}
        {mainTypes.map((type) => (
          <Badge
            key={type}
            variant={selectedTypes.includes(type) ? 'default' : 'outline'}
            className={cn(
              'cursor-pointer text-[11px] capitalize transition-all px-2.5 py-0.5',
              selectedTypes.includes(type)
                ? 'bg-primary text-primary-foreground hover:bg-primary/90'
                : 'border-border bg-transparent text-muted-foreground hover:bg-muted hover:text-foreground'
            )}
            onClick={() => onTypeToggle(type)}
          >
            {type}
          </Badge>
        ))}

        {/* More dropdown for other types */}
        {otherTypes.length > 0 && (
          <DropdownMenu>
            <DropdownMenuTrigger asChild>
              <button
                className={cn(
                  'flex items-center gap-1 rounded-full border px-2 py-0.5 text-[11px] font-semibold transition-colors',
                  selectedOtherCount > 0
                    ? 'border-transparent bg-primary text-primary-foreground'
                    : 'border-border text-muted-foreground hover:bg-muted hover:text-foreground'
                )}
              >
                More
                {selectedOtherCount > 0 && (
                  <span className="flex h-3.5 min-w-3.5 items-center justify-center rounded-full bg-primary-foreground text-[9px] font-bold text-primary">
                    {selectedOtherCount}
                  </span>
                )}
                <ChevronDown className="h-3 w-3" />
              </button>
            </DropdownMenuTrigger>
            <DropdownMenuContent align="start" className="min-w-[100px]">
              {otherTypes.map((type) => (
                <DropdownMenuItem
                  key={type}
                  onClick={() => onTypeToggle(type)}
                  className={cn(
                    'capitalize cursor-pointer text-sm',
                    selectedTypes.includes(type) && 'bg-primary/10 text-primary'
                  )}
                >
                  {selectedTypes.includes(type) && (
                    <span className="mr-2">✓</span>
                  )}
                  {type}
                </DropdownMenuItem>
              ))}
            </DropdownMenuContent>
          </DropdownMenu>
        )}
      </div>
    </motion.div>
  );
}
