import { useState } from 'react';
import { motion } from 'framer-motion';
import { GraduationCap, Search, User, LogOut, BarChart3, Moon, Sun, Bookmark, Sparkles, ChevronDown } from 'lucide-react';
import { Link, useNavigate } from 'react-router-dom';
import { useAuth } from '@/hooks/useAuth';
import { useTheme } from 'next-themes';
import { Button } from '@/components/ui/button';
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger } from '@/components/ui/dropdown-menu';
import { Input } from '@/components/ui/input';
import { Badge } from '@/components/ui/badge';
import { Level } from '@/data/oxfordVocabulary';
import { cn } from '@/lib/utils';

const MAIN_TYPES = ['noun', 'verb', 'adjective', 'adverb'];

interface HeaderProps {
  onSearchClick?: () => void;
  onStatsClick?: () => void;
  onBookmarksClick?: () => void;
  showDesktopSearch?: boolean;
  onSearchChange?: (query: string) => void;
  searchQuery?: string;
  // Level tabs props
  levels?: Level[];
  selectedLevel?: Level;
  onLevelChange?: (level: Level) => void;
  // Type filter props
  wordTypes?: string[];
  selectedTypes?: string[];
  onTypeToggle?: (type: string) => void;
  onClearTypes?: () => void;
}

export function Header({
  onSearchClick,
  onStatsClick,
  onBookmarksClick,
  showDesktopSearch = false,
  onSearchChange,
  searchQuery = '',
  levels = [],
  selectedLevel,
  onLevelChange,
  wordTypes = [],
  selectedTypes = [],
  onTypeToggle,
  onClearTypes,
}: HeaderProps) {
  const { user, signOut } = useAuth();
  const { theme, setTheme } = useTheme();
  const navigate = useNavigate();

  // Separate main types from other types
  const mainTypes = wordTypes.filter(t => MAIN_TYPES.includes(t));
  const otherTypes = wordTypes.filter(t => !MAIN_TYPES.includes(t));
  const selectedOtherCount = selectedTypes.filter(t => otherTypes.includes(t)).length;
  
  return (
    <motion.header
      initial={{ opacity: 0, y: -20 }}
      animate={{ opacity: 1, y: 0 }}
      className="flex flex-col gap-4"
    >
      {/* Top row: Logo, Search, Actions */}
      <div className="flex items-center justify-between gap-4">
        {/* Logo */}
        <div className="flex items-center gap-2">
          <motion.div
            animate={{ rotate: [0, -10, 10, -10, 0] }}
            transition={{ duration: 2, repeat: Infinity, repeatDelay: 3 }}
          >
            <GraduationCap className="h-7 w-7 text-primary md:h-8 md:w-8" />
          </motion.div>
          <h1 className="font-display text-lg font-bold text-foreground md:text-xl hidden md:block">
            Oxford Vocab
          </h1>
        </div>
        
        {/* Desktop: Centered Search Bar */}
        <div className="hidden flex-1 justify-center md:flex">
          <div className="relative w-full max-w-md">
            <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
            <Input
              type="text"
              placeholder="Search..."
              value={searchQuery}
              onChange={(e) => onSearchChange?.(e.target.value)}
              onClick={onSearchClick}
              className="w-full rounded-full border-border bg-muted/50 pl-10 pr-4 text-sm placeholder:text-muted-foreground focus:bg-card"
            />
          </div>
        </div>
        
        {/* Mobile: User menu */}
        <div className="md:hidden">
          {user ? (
            <DropdownMenu>
              <DropdownMenuTrigger asChild>
                <button className="rounded-full p-2 text-muted-foreground hover:bg-muted">
                  <User className="h-5 w-5" />
                </button>
              </DropdownMenuTrigger>
              <DropdownMenuContent align="end">
                <DropdownMenuItem onClick={() => navigate('/profile')}>
                  <User className="mr-2 h-4 w-4" />
                  Profile
                </DropdownMenuItem>
                <DropdownMenuItem onClick={() => signOut()}>
                  <LogOut className="mr-2 h-4 w-4" />
                  Sign out
                </DropdownMenuItem>
              </DropdownMenuContent>
            </DropdownMenu>
          ) : (
            <Link to="/auth">
              <Button variant="ghost" size="sm" className="text-primary">
                Sign in
              </Button>
            </Link>
          )}
        </div>
        
        {/* Desktop: Bookmarks, Stats, Theme, and Auth */}
        <div className="hidden items-center gap-3 md:flex">
          <motion.button
            whileHover={{ scale: 1.05 }}
            whileTap={{ scale: 0.95 }}
            onClick={onBookmarksClick}
            className="flex items-center gap-2 text-sm font-medium text-muted-foreground transition-colors hover:text-foreground"
          >
            <Bookmark className="h-4 w-4" />
            <span>Saved</span>
          </motion.button>
          
          <motion.button
            whileHover={{ scale: 1.05 }}
            whileTap={{ scale: 0.95 }}
            onClick={onStatsClick}
            className="flex items-center gap-2 text-sm font-medium text-muted-foreground transition-colors hover:text-foreground"
          >
            <BarChart3 className="h-4 w-4" />
            <span>Stats</span>
          </motion.button>
          
          <motion.button
            whileHover={{ scale: 1.05 }}
            whileTap={{ scale: 0.95 }}
            onClick={() => setTheme(theme === 'dark' ? 'light' : 'dark')}
            className="flex items-center justify-center rounded-full p-2 text-muted-foreground transition-colors hover:bg-muted hover:text-foreground"
          >
            {theme === 'dark' ? <Sun className="h-4 w-4" /> : <Moon className="h-4 w-4" />}
          </motion.button>
          
          {user ? (
            <DropdownMenu>
              <DropdownMenuTrigger asChild>
                <motion.button
                  whileHover={{ scale: 1.05 }}
                  whileTap={{ scale: 0.95 }}
                  className="flex h-9 w-9 items-center justify-center rounded-full bg-gradient-gold text-accent-foreground shadow-gold"
                >
                  <User className="h-4 w-4" />
                </motion.button>
              </DropdownMenuTrigger>
              <DropdownMenuContent align="end">
                <DropdownMenuItem onClick={() => navigate('/profile')}>
                  <User className="mr-2 h-4 w-4" />
                  Profile
                </DropdownMenuItem>
                <DropdownMenuItem onClick={() => signOut()}>
                  <LogOut className="mr-2 h-4 w-4" />
                  Sign out
                </DropdownMenuItem>
              </DropdownMenuContent>
            </DropdownMenu>
          ) : (
            <Link to="/auth">
              <motion.button
                whileHover={{ scale: 1.05 }}
                whileTap={{ scale: 0.95 }}
                className="flex h-9 w-9 items-center justify-center rounded-full border-2 border-primary text-primary transition-colors hover:bg-primary hover:text-primary-foreground"
              >
                <User className="h-4 w-4" />
              </motion.button>
            </Link>
          )}
        </div>
      </div>

      {/* Desktop: Level Tabs */}
      {levels.length > 0 && onLevelChange && (
        <div className="hidden justify-center md:flex">
          <div className="relative flex items-center rounded-full bg-muted p-1">
            {levels.map((level) => {
              const isSelected = selectedLevel === level;
              
              return (
                <motion.button
                  key={level}
                  onClick={() => onLevelChange(level)}
                  whileTap={{ scale: 0.95 }}
                  className={cn(
                    'relative z-10 flex items-center gap-2 rounded-full px-5 py-2 text-sm font-semibold transition-colors duration-200',
                    isSelected
                      ? 'text-accent-foreground'
                      : 'text-muted-foreground hover:text-foreground'
                  )}
                >
                  {isSelected && (
                    <motion.div
                      layoutId="headerLevelTabBackground"
                      className="absolute inset-0 rounded-full bg-gradient-gold shadow-gold"
                      transition={{ type: 'spring', stiffness: 400, damping: 30 }}
                    />
                  )}
                  <span className="relative z-10 flex items-center gap-1.5">
                    {isSelected && (
                      <motion.span
                        initial={{ scale: 0, opacity: 0 }}
                        animate={{ scale: 1, opacity: 1 }}
                        exit={{ scale: 0, opacity: 0 }}
                        transition={{ delay: 0.1 }}
                      >
                        <Sparkles className="h-3.5 w-3.5" />
                      </motion.span>
                    )}
                    <span>Level {level}</span>
                  </span>
                </motion.button>
              );
            })}
          </div>
        </div>
      )}

      {/* Desktop: Type Filter */}
      {wordTypes.length > 0 && onTypeToggle && (
        <div className="hidden items-center justify-center gap-3 md:flex">
          <span className="text-xs font-medium uppercase tracking-wider text-muted-foreground">
            Filter by type:
          </span>
          <div className="flex items-center gap-2">
            {/* Main types */}
            {mainTypes.map((type) => (
              <Badge
                key={type}
                variant={selectedTypes.includes(type) ? 'default' : 'outline'}
                className={cn(
                  'cursor-pointer text-xs capitalize transition-all',
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
                      'flex items-center gap-1 rounded-full border px-2.5 py-0.5 text-xs font-semibold transition-colors',
                      selectedOtherCount > 0
                        ? 'border-transparent bg-primary text-primary-foreground'
                        : 'border-border text-muted-foreground hover:bg-muted hover:text-foreground'
                    )}
                  >
                    More
                    {selectedOtherCount > 0 && (
                      <span className="flex h-4 min-w-4 items-center justify-center rounded-full bg-primary-foreground text-[10px] font-bold text-primary">
                        {selectedOtherCount}
                      </span>
                    )}
                    <ChevronDown className="h-3 w-3" />
                  </button>
                </DropdownMenuTrigger>
                <DropdownMenuContent align="center" className="min-w-[120px]">
                  {otherTypes.map((type) => (
                    <DropdownMenuItem
                      key={type}
                      onClick={() => onTypeToggle(type)}
                      className={cn(
                        'capitalize cursor-pointer',
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
          <button
            onClick={onClearTypes}
            disabled={selectedTypes.length === 0}
            className={cn(
              "text-xs font-semibold uppercase tracking-wider transition-all duration-300",
              selectedTypes.length > 0
                ? "text-primary hover:text-primary/80 opacity-100"
                : "opacity-0 pointer-events-none"
            )}
          >
            Clear All
          </button>
        </div>
      )}
    </motion.header>
  );
}
