import { motion } from 'framer-motion';
import { Settings, Layers, Search, Bookmark, BarChart3 } from 'lucide-react';
import { cn } from '@/lib/utils';

export type NavTab = 'settings' | 'levels' | 'search' | 'bookmarks' | 'stats';

interface BottomNavProps {
  activeTab: NavTab;
  onTabChange: (tab: NavTab) => void;
}

export function BottomNav({ activeTab, onTabChange }: BottomNavProps) {
  const tabs = [
    { id: 'levels' as NavTab, label: 'Levels', icon: Layers },
    { id: 'search' as NavTab, label: 'Search', icon: Search },
    { id: 'bookmarks' as NavTab, label: 'Saved', icon: Bookmark },
    { id: 'stats' as NavTab, label: 'Stats', icon: BarChart3 },
    { id: 'settings' as NavTab, label: 'Settings', icon: Settings },
  ];

  return (
    <nav className="fixed bottom-0 left-0 right-0 z-50 border-t border-border bg-card/95 backdrop-blur-sm md:hidden">
      <div className="flex items-center justify-around py-2">
        {tabs.map((tab) => {
          const Icon = tab.icon;
          const isActive = activeTab === tab.id;
          
          return (
            <motion.button
              key={tab.id}
              onClick={() => onTabChange(tab.id)}
              whileTap={{ scale: 0.95 }}
              className={cn(
                'flex flex-col items-center gap-1 px-3 py-2 transition-colors',
                isActive ? 'text-oxford-gold' : 'text-muted-foreground'
              )}
            >
              <Icon className={cn('h-5 w-5', isActive && 'stroke-[2.5px]', tab.id === 'bookmarks' && isActive && 'fill-oxford-gold')} />
              <span className="text-xs font-medium">{tab.label}</span>
              {isActive && (
                <motion.div
                  layoutId="activeTab"
                  className="absolute -top-0.5 h-0.5 w-8 rounded-full bg-oxford-gold"
                />
              )}
            </motion.button>
          );
        })}
      </div>
    </nav>
  );
}
