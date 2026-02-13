import { useState, useEffect, useCallback } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { useAuth } from './useAuth';

export interface Achievement {
  id: string;
  name: string;
  description: string;
  icon: string;
  unlocked: boolean;
  unlockedAt?: Date;
}

export interface DailyActivity {
  date: string;
  wordsLearned: number;
  listeningSeconds: number;
}

export interface Statistics {
  currentStreak: number;
  longestStreak: number;
  totalWordsLearned: number;
  wordsThisWeek: number;
  totalListeningSeconds: number;
  listeningThisWeek: number;
  weeklyActivity: DailyActivity[];
  achievements: Achievement[];
}

const ACHIEVEMENTS_CONFIG: Omit<Achievement, 'unlocked' | 'unlockedAt'>[] = [
  { id: 'first_word', name: 'First Steps', description: 'Learn your first word', icon: '🎯' },
  { id: 'ten_words', name: 'Getting Started', description: 'Learn 10 words', icon: '📚' },
  { id: 'fifty_words', name: 'Vocabulary Builder', description: 'Learn 50 words', icon: '🏆' },
  { id: 'hundred_words', name: 'Word Master', description: 'Learn 100 words', icon: '👑' },
  { id: 'three_day_streak', name: 'Consistent', description: 'Maintain a 3-day streak', icon: '🔥' },
  { id: 'seven_day_streak', name: 'Weekly Warrior', description: 'Maintain a 7-day streak', icon: '⚡' },
  { id: 'thirty_day_streak', name: 'Monthly Champion', description: 'Maintain a 30-day streak', icon: '💎' },
  { id: 'one_hour_listening', name: 'Active Listener', description: 'Listen for 1 hour total', icon: '🎧' },
  { id: 'five_hours_listening', name: 'Dedicated Learner', description: 'Listen for 5 hours total', icon: '🎵' },
  { id: 'b2_complete', name: 'B2 Graduate', description: 'Complete all B2 words', icon: '🎓' },
  { id: 'c1_complete', name: 'C1 Master', description: 'Complete all C1 words', icon: '🌟' },
];

const defaultStats: Statistics = {
  currentStreak: 0,
  longestStreak: 0,
  totalWordsLearned: 0,
  wordsThisWeek: 0,
  totalListeningSeconds: 0,
  listeningThisWeek: 0,
  weeklyActivity: [],
  achievements: ACHIEVEMENTS_CONFIG.map(a => ({ ...a, unlocked: false })),
};

export function useStatistics() {
  const [statistics, setStatistics] = useState<Statistics>(defaultStats);
  const [loading, setLoading] = useState(true);
  const { user } = useAuth();

  const calculateStreak = (activities: { activity_date: string }[]): { current: number; longest: number } => {
    if (activities.length === 0) return { current: 0, longest: 0 };

    const dates = activities
      .map(a => new Date(a.activity_date))
      .sort((a, b) => b.getTime() - a.getTime());

    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const yesterday = new Date(today);
    yesterday.setDate(yesterday.getDate() - 1);

    let currentStreak = 0;
    let longestStreak = 0;
    let tempStreak = 1;

    // Check if streak is active (today or yesterday)
    const lastActivityDate = dates[0];
    lastActivityDate.setHours(0, 0, 0, 0);
    
    const isActiveStreak = lastActivityDate.getTime() === today.getTime() || 
                           lastActivityDate.getTime() === yesterday.getTime();

    for (let i = 0; i < dates.length; i++) {
      if (i === 0) {
        tempStreak = 1;
        continue;
      }

      const current = dates[i - 1];
      const prev = dates[i];
      current.setHours(0, 0, 0, 0);
      prev.setHours(0, 0, 0, 0);

      const diffDays = Math.round((current.getTime() - prev.getTime()) / (1000 * 60 * 60 * 24));

      if (diffDays === 1) {
        tempStreak++;
      } else {
        if (i === 1 || tempStreak > longestStreak) {
          longestStreak = Math.max(longestStreak, tempStreak);
        }
        if (isActiveStreak && currentStreak === 0) {
          currentStreak = tempStreak;
        }
        tempStreak = 1;
      }
    }

    longestStreak = Math.max(longestStreak, tempStreak);
    if (isActiveStreak && currentStreak === 0) {
      currentStreak = tempStreak;
    }

    return { current: currentStreak, longest: longestStreak };
  };

  const loadStatistics = useCallback(async () => {
    if (!user) {
      setStatistics(defaultStats);
      setLoading(false);
      return;
    }

    try {
      // Get all activity data
      const { data: activityData } = await supabase
        .from('user_activity')
        .select('*')
        .eq('user_id', user.id)
        .order('activity_date', { ascending: false });

      // Get achievements
      const { data: achievementsData } = await supabase
        .from('user_achievements')
        .select('*')
        .eq('user_id', user.id);

      // Get total words learned from progress
      const { count: totalWords } = await supabase
        .from('user_progress')
        .select('*', { count: 'exact', head: true })
        .eq('user_id', user.id);

      const activities = activityData || [];
      const unlockedAchievements = achievementsData || [];

      // Calculate streaks
      const { current: currentStreak, longest: longestStreak } = calculateStreak(activities);

      // Calculate totals
      const totalListeningSeconds = activities.reduce((sum, a) => sum + a.listening_seconds, 0);

      // Get this week's data
      const weekStart = new Date();
      weekStart.setDate(weekStart.getDate() - 7);
      const weekActivities = activities.filter(a => new Date(a.activity_date) >= weekStart);
      
      const wordsThisWeek = weekActivities.reduce((sum, a) => sum + a.words_learned, 0);
      const listeningThisWeek = weekActivities.reduce((sum, a) => sum + a.listening_seconds, 0);

      // Format weekly activity for chart
      const last7Days: DailyActivity[] = [];
      for (let i = 6; i >= 0; i--) {
        const date = new Date();
        date.setDate(date.getDate() - i);
        const dateStr = date.toISOString().split('T')[0];
        const dayActivity = activities.find(a => a.activity_date === dateStr);
        last7Days.push({
          date: dateStr,
          wordsLearned: dayActivity?.words_learned || 0,
          listeningSeconds: dayActivity?.listening_seconds || 0,
        });
      }

      // Map achievements
      const achievements = ACHIEVEMENTS_CONFIG.map(a => {
        const unlocked = unlockedAchievements.find(ua => ua.achievement_id === a.id);
        return {
          ...a,
          unlocked: !!unlocked,
          unlockedAt: unlocked ? new Date(unlocked.unlocked_at) : undefined,
        };
      });

      setStatistics({
        currentStreak,
        longestStreak,
        totalWordsLearned: totalWords || 0,
        wordsThisWeek,
        totalListeningSeconds,
        listeningThisWeek,
        weeklyActivity: last7Days,
        achievements,
      });
    } catch (error) {
      console.error('Error loading statistics:', error);
    } finally {
      setLoading(false);
    }
  }, [user]);

  useEffect(() => {
    loadStatistics();
  }, [loadStatistics]);

  const trackActivity = useCallback(async (wordsLearned: number = 0, listeningSeconds: number = 0) => {
    if (!user) return;

    const today = new Date().toISOString().split('T')[0];

    try {
      // Try to get existing record
      const { data: existing } = await supabase
        .from('user_activity')
        .select('*')
        .eq('user_id', user.id)
        .eq('activity_date', today)
        .single();

      if (existing) {
        // Update existing
        await supabase
          .from('user_activity')
          .update({
            words_learned: existing.words_learned + wordsLearned,
            listening_seconds: existing.listening_seconds + listeningSeconds,
          })
          .eq('id', existing.id);
      } else {
        // Insert new
        await supabase
          .from('user_activity')
          .insert({
            user_id: user.id,
            activity_date: today,
            words_learned: wordsLearned,
            listening_seconds: listeningSeconds,
          });
      }

      // Reload stats to check for new achievements
      await loadStatistics();
      await checkAndUnlockAchievements();
    } catch (error) {
      console.error('Error tracking activity:', error);
    }
  }, [user, loadStatistics]);

  const checkAndUnlockAchievements = useCallback(async () => {
    if (!user) return;

    const { data: progress } = await supabase
      .from('user_progress')
      .select('level')
      .eq('user_id', user.id);

    const { data: activity } = await supabase
      .from('user_activity')
      .select('*')
      .eq('user_id', user.id);

    const { data: existingAchievements } = await supabase
      .from('user_achievements')
      .select('achievement_id')
      .eq('user_id', user.id);

    const unlockedIds = new Set(existingAchievements?.map(a => a.achievement_id) || []);
    const totalWords = progress?.length || 0;
    const b2Words = progress?.filter(p => p.level === 'B2').length || 0;
    const c1Words = progress?.filter(p => p.level === 'C1').length || 0;
    const { current: streak } = calculateStreak(activity || []);
    const totalListening = activity?.reduce((sum, a) => sum + a.listening_seconds, 0) || 0;

    const achievementsToUnlock: string[] = [];

    // Word milestones
    if (totalWords >= 1 && !unlockedIds.has('first_word')) achievementsToUnlock.push('first_word');
    if (totalWords >= 10 && !unlockedIds.has('ten_words')) achievementsToUnlock.push('ten_words');
    if (totalWords >= 50 && !unlockedIds.has('fifty_words')) achievementsToUnlock.push('fifty_words');
    if (totalWords >= 100 && !unlockedIds.has('hundred_words')) achievementsToUnlock.push('hundred_words');

    // Streak milestones
    if (streak >= 3 && !unlockedIds.has('three_day_streak')) achievementsToUnlock.push('three_day_streak');
    if (streak >= 7 && !unlockedIds.has('seven_day_streak')) achievementsToUnlock.push('seven_day_streak');
    if (streak >= 30 && !unlockedIds.has('thirty_day_streak')) achievementsToUnlock.push('thirty_day_streak');

    // Listening milestones
    if (totalListening >= 3600 && !unlockedIds.has('one_hour_listening')) achievementsToUnlock.push('one_hour_listening');
    if (totalListening >= 18000 && !unlockedIds.has('five_hours_listening')) achievementsToUnlock.push('five_hours_listening');

    // Level completion (assuming ~300 words per level)
    if (b2Words >= 300 && !unlockedIds.has('b2_complete')) achievementsToUnlock.push('b2_complete');
    if (c1Words >= 300 && !unlockedIds.has('c1_complete')) achievementsToUnlock.push('c1_complete');

    // Unlock achievements
    for (const achievementId of achievementsToUnlock) {
      await supabase
        .from('user_achievements')
        .insert({ user_id: user.id, achievement_id: achievementId });
    }

    if (achievementsToUnlock.length > 0) {
      await loadStatistics();
    }
  }, [user, loadStatistics]);

  return {
    statistics,
    loading,
    trackActivity,
    checkAndUnlockAchievements,
    refreshStats: loadStatistics,
  };
}
