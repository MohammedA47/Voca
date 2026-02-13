import { motion, AnimatePresence } from 'framer-motion';
import { X, Flame, BookOpen, Clock, Trophy, TrendingUp } from 'lucide-react';
import { useStatistics } from '@/hooks/useStatistics';
import { useAuth } from '@/hooks/useAuth';
import { cn } from '@/lib/utils';

interface StatisticsPanelProps {
  isOpen: boolean;
  onClose: () => void;
}

const formatTime = (seconds: number): string => {
  if (seconds < 60) return `${seconds}s`;
  const minutes = Math.floor(seconds / 60);
  if (minutes < 60) return `${minutes}m`;
  const hours = Math.floor(minutes / 60);
  const remainingMinutes = minutes % 60;
  return remainingMinutes > 0 ? `${hours}h ${remainingMinutes}m` : `${hours}h`;
};

const getDayLabel = (dateStr: string): string => {
  const date = new Date(dateStr);
  const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  return days[date.getDay()];
};

export function StatisticsPanel({ isOpen, onClose }: StatisticsPanelProps) {
  const { statistics, loading } = useStatistics();
  const { user } = useAuth();

  const maxWordsInWeek = Math.max(...statistics.weeklyActivity.map(d => d.wordsLearned), 1);

  return (
    <AnimatePresence>
      {isOpen && (
        <>
          {/* Backdrop - only on desktop */}
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            onClick={onClose}
            className="fixed inset-0 z-40 hidden bg-background/80 backdrop-blur-sm md:block"
          />

          {/* Panel */}
          <motion.div
            initial={{ opacity: 0, y: '100%' }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: '100%' }}
            transition={{ duration: 0.3, ease: 'easeOut' }}
            className="fixed inset-0 z-50 flex flex-col overflow-y-auto bg-background md:right-0 md:left-auto md:top-0 md:h-full md:w-full md:max-w-md md:bg-card md:shadow-xl"
          >
            {/* Header */}
            <div className="sticky top-0 z-10 flex items-center justify-between border-b border-border bg-card px-6 py-4">
              <div className="flex items-center gap-3">
                <div className="flex h-10 w-10 items-center justify-center rounded-full bg-oxford-gold/10">
                  <TrendingUp className="h-5 w-5 text-oxford-gold" />
                </div>
                <h2 className="text-xl font-bold">Statistics</h2>
              </div>
              <button
                onClick={onClose}
                className="rounded-full p-2 text-muted-foreground transition-colors hover:bg-muted hover:text-foreground"
              >
                <X className="h-5 w-5" />
              </button>
            </div>

            {!user ? (
              <div className="flex flex-col items-center justify-center px-6 py-16 text-center">
                <div className="mb-4 text-4xl">📊</div>
                <h3 className="mb-2 text-lg font-semibold">Sign in to track your progress</h3>
                <p className="text-sm text-muted-foreground">
                  Create an account to see your learning statistics and unlock achievements.
                </p>
              </div>
            ) : loading ? (
              <div className="flex items-center justify-center py-16">
                <div className="h-8 w-8 animate-spin rounded-full border-4 border-primary border-t-transparent" />
              </div>
            ) : (
              <div className="space-y-6 p-6 pb-24">
                {/* Stats Grid */}
                <div className="grid grid-cols-2 gap-4">
                  {/* Streak */}
                  <div className="rounded-xl border border-border bg-gradient-to-br from-orange-500/10 to-transparent p-4">
                    <div className="mb-2 flex items-center gap-2">
                      <Flame className="h-5 w-5 text-orange-500" />
                      <span className="text-sm text-muted-foreground">Current Streak</span>
                    </div>
                    <div className="text-3xl font-bold">{statistics.currentStreak}</div>
                    <div className="text-xs text-muted-foreground">
                      Best: {statistics.longestStreak} days
                    </div>
                  </div>

                  {/* Words Learned */}
                  <div className="rounded-xl border border-border bg-gradient-to-br from-oxford-gold/10 to-transparent p-4">
                    <div className="mb-2 flex items-center gap-2">
                      <BookOpen className="h-5 w-5 text-oxford-gold" />
                      <span className="text-sm text-muted-foreground">Words Learned</span>
                    </div>
                    <div className="text-3xl font-bold">{statistics.totalWordsLearned}</div>
                    <div className="text-xs text-muted-foreground">
                      +{statistics.wordsThisWeek} this week
                    </div>
                  </div>

                  {/* Listening Time */}
                  <div className="rounded-xl border border-border bg-gradient-to-br from-blue-500/10 to-transparent p-4">
                    <div className="mb-2 flex items-center gap-2">
                      <Clock className="h-5 w-5 text-blue-500" />
                      <span className="text-sm text-muted-foreground">Listening Time</span>
                    </div>
                    <div className="text-3xl font-bold">
                      {formatTime(statistics.totalListeningSeconds)}
                    </div>
                    <div className="text-xs text-muted-foreground">
                      +{formatTime(statistics.listeningThisWeek)} this week
                    </div>
                  </div>

                  {/* Achievements */}
                  <div className="rounded-xl border border-border bg-gradient-to-br from-purple-500/10 to-transparent p-4">
                    <div className="mb-2 flex items-center gap-2">
                      <Trophy className="h-5 w-5 text-purple-500" />
                      <span className="text-sm text-muted-foreground">Achievements</span>
                    </div>
                    <div className="text-3xl font-bold">
                      {statistics.achievements.filter(a => a.unlocked).length}
                    </div>
                    <div className="text-xs text-muted-foreground">
                      of {statistics.achievements.length} unlocked
                    </div>
                  </div>
                </div>

                {/* Weekly Activity Chart */}
                <div className="rounded-xl border border-border p-4">
                  <h3 className="mb-4 text-sm font-semibold uppercase tracking-wider text-muted-foreground">
                    Words This Week
                  </h3>
                  <div className="flex items-end justify-between gap-2" style={{ height: 120 }}>
                    {statistics.weeklyActivity.map((day, index) => {
                      const height = (day.wordsLearned / maxWordsInWeek) * 100;
                      const isToday = index === statistics.weeklyActivity.length - 1;
                      return (
                        <div key={day.date} className="flex flex-1 flex-col items-center gap-1">
                          <span className="text-xs font-medium text-muted-foreground">
                            {day.wordsLearned}
                          </span>
                          <div
                            className={cn(
                              'w-full rounded-t-md transition-all',
                              isToday
                                ? 'bg-oxford-gold'
                                : day.wordsLearned > 0
                                  ? 'bg-oxford-gold/50'
                                  : 'bg-muted'
                            )}
                            style={{ height: `${Math.max(height, 4)}%`, minHeight: 4 }}
                          />
                          <span
                            className={cn(
                              'text-xs',
                              isToday ? 'font-semibold text-foreground' : 'text-muted-foreground'
                            )}
                          >
                            {getDayLabel(day.date)}
                          </span>
                        </div>
                      );
                    })}
                  </div>
                </div>

                {/* Achievements */}
                <div className="rounded-xl border border-border p-4">
                  <h3 className="mb-4 text-sm font-semibold uppercase tracking-wider text-muted-foreground">
                    Achievements
                  </h3>
                  <div className="grid grid-cols-4 gap-3">
                    {statistics.achievements.map((achievement) => (
                      <div
                        key={achievement.id}
                        className={cn(
                          'group relative flex flex-col items-center gap-1 rounded-lg p-2 transition-all',
                          achievement.unlocked
                            ? 'bg-oxford-gold/10'
                            : 'bg-muted/50 opacity-50 grayscale'
                        )}
                        title={`${achievement.name}: ${achievement.description}`}
                      >
                        <span className="text-2xl">{achievement.icon}</span>
                        <span className="text-center text-[10px] leading-tight text-muted-foreground">
                          {achievement.name}
                        </span>
                        
                        {/* Tooltip on hover */}
                        <div className="pointer-events-none absolute -top-16 left-1/2 z-10 w-32 -translate-x-1/2 rounded-lg bg-popover p-2 text-center text-xs opacity-0 shadow-lg transition-opacity group-hover:opacity-100">
                          <div className="font-medium">{achievement.name}</div>
                          <div className="text-muted-foreground">{achievement.description}</div>
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              </div>
            )}
          </motion.div>
        </>
      )}
    </AnimatePresence>
  );
}
