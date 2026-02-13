import { useState, useEffect, useCallback, useMemo } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Header } from '@/components/Header';
import { WordCard } from '@/components/WordCard';
import { BottomNav, NavTab } from '@/components/BottomNav';
import { UpNextSection } from '@/components/UpNextSection';
import { SearchPanel } from '@/components/SearchPanel';
import { SettingsPanel } from '@/components/SettingsPanel';
import { BookmarksPanel } from '@/components/BookmarksPanel';
import { StatisticsPanel } from '@/components/StatisticsPanel';
import { DesktopLevelTabs } from '@/components/DesktopLevelTabs';
import { DesktopWordCard } from '@/components/DesktopWordCard';
import { DesktopSessionPanel } from '@/components/DesktopSessionPanel';
import { MobileFilters } from '@/components/MobileFilters';
import { oxfordWords, Level, levelDescriptions, Word } from '@/data/oxfordVocabulary';
import { useProgress } from '@/hooks/useProgress';
import { useBookmarks } from '@/hooks/useBookmarks';
import { useSpeech } from '@/hooks/useSpeech';
import { useStatistics } from '@/hooks/useStatistics';

const levels: Level[] = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];

export type PhoneticAccent = 'us' | 'uk';

export default function Index() {
  const [selectedLevel, setSelectedLevel] = useState<Level>('A1');
  const [currentWordIndex, setCurrentWordIndex] = useState(0);
  const [activeTab, setActiveTab] = useState<NavTab>('levels');
  const [showDesktopSearch, setShowDesktopSearch] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedTypes, setSelectedTypes] = useState<string[]>([]);
  const [phoneticAccent, setPhoneticAccent] = useState<PhoneticAccent>(() => {
    const saved = localStorage.getItem('phoneticAccent');
    // Default to 'uk' if no saved preference
    return (saved === 'us' ? 'us' : 'uk') as PhoneticAccent;
  });

  // Persist phonetic accent preference
  useEffect(() => {
    localStorage.setItem('phoneticAccent', phoneticAccent);
  }, [phoneticAccent]);

  const {
    progress,
    markAsLearned,
    unmarkAsLearned,
    isLearned,
    getProgressForLevel
  } = useProgress();

  const {
    addBookmark,
    removeBookmark,
    isBookmarked
  } = useBookmarks();

  const { trackActivity } = useStatistics();

  const words = oxfordWords[selectedLevel];
  const hasLevelWords = words.length > 0;

  // Extract unique word types from current level
  const wordTypes = useMemo(() => {
    const types = new Set<string>();
    words.forEach(word => {
      word.type.split(',').forEach(t => types.add(t.trim().toLowerCase()));
    });
    return Array.from(types).sort();
  }, [words]);

  // Filter words by selected types
  const filteredWords = useMemo(() => {
    if (selectedTypes.length === 0) return words;
    return words.filter(word =>
      selectedTypes.some(type =>
        word.type.toLowerCase().includes(type.toLowerCase())
      )
    );
  }, [words, selectedTypes]);

  const currentWord = filteredWords[currentWordIndex];

  // Calculate learned count for daily goal
  const learnedCount = useMemo(() => {
    return filteredWords.filter(w => isLearned(selectedLevel, w.id)).length;
  }, [filteredWords, selectedLevel, isLearned]);

  const toggleType = (type: string) => {
    setSelectedTypes(prev =>
      prev.includes(type)
        ? prev.filter(t => t !== type)
        : [...prev, type]
    );
    setCurrentWordIndex(0);
  };

  const clearTypes = () => {
    setSelectedTypes([]);
    setCurrentWordIndex(0);
  };

  // Get all words across all levels for search
  const allWords = useMemo(() => {
    return Object.values(oxfordWords).flat();
  }, []);

  const goToNextWord = useCallback(() => {
    setCurrentWordIndex(prev => (prev + 1) % filteredWords.length);
  }, [filteredWords.length]);

  const {
    speak,
    stop,
    isSpeaking,
    isLoopingActive,
    speed,
    setSpeed,
    isRandomSpeed,
    setIsRandomSpeed,
    isLooping,
    toggleLoop,
    loopGap,
    setLoopGap,
    clearCache
  } = useSpeech();

  // Handle looping - repeat same word
  const handleSpeakWord = useCallback(() => {
    if (!currentWord) return;
    speak(currentWord.word, phoneticAccent, () => {
      if (isLooping) {
        handleSpeakWord();
      }
    });
  }, [speak, currentWord?.word, isLooping, phoneticAccent]);

  const handleSpeakExample = useCallback((example: string) => {
    if (example) {
      speak(example, phoneticAccent);
    }
  }, [speak, phoneticAccent]);

  // Clear cache when word changes
  useEffect(() => {
    clearCache();
  }, [currentWordIndex, selectedLevel, clearCache]);

  const handleLevelChange = (level: Level) => {
    stop();
    setSelectedLevel(level);
    setCurrentWordIndex(0);
    setSelectedTypes([]);
  };

  const handlePrevious = () => {
    stop();
    setCurrentWordIndex(prev => (prev - 1 + filteredWords.length) % filteredWords.length);
  };

  const handleNext = () => {
    stop();
    goToNextWord();
  };

  const handleToggleLearned = () => {
    if (!currentWord) return;
    if (isLearned(selectedLevel, currentWord.id)) {
      unmarkAsLearned(selectedLevel, currentWord.id);
    } else {
      markAsLearned(selectedLevel, currentWord.id);
      trackActivity(1, 0);
    }
  };

  const handleToggleBookmark = () => {
    if (!currentWord) return;
    if (isBookmarked(selectedLevel, currentWord.id)) {
      removeBookmark(selectedLevel, currentWord.id);
    } else {
      addBookmark(selectedLevel, currentWord.id);
    }
  };

  const handleWordSelect = (index: number) => {
    stop();
    setCurrentWordIndex(index);
  };

  const handleSearchWordSelect = (word: Word, index: number) => {
    if (word.level !== selectedLevel) {
      setSelectedLevel(word.level);
      const newIndex = oxfordWords[word.level].findIndex(w => w.id === word.id);
      setCurrentWordIndex(newIndex >= 0 ? newIndex : 0);
    } else {
      setCurrentWordIndex(index);
    }
    setActiveTab('levels');
    setShowDesktopSearch(false);
    setSearchQuery('');
    stop();
  };

  const handleTabChange = (tab: NavTab) => {
    setActiveTab(tab);
  };

  return (
    <div className="min-h-screen bg-background px-3 py-4 pb-44 md:px-8 md:py-6 md:pb-8">
      {/* Mobile Settings Overlay */}
      <AnimatePresence>
        {activeTab === 'settings' && (
          <SettingsPanel
            isLooping={isLooping}
            speed={speed}
            isRandomSpeed={isRandomSpeed}
            loopGap={loopGap}
            phoneticAccent={phoneticAccent}
            onToggleLoop={toggleLoop}
            onSpeedChange={setSpeed}
            onRandomSpeedToggle={() => setIsRandomSpeed(!isRandomSpeed)}
            onLoopGapChange={setLoopGap}
            onPhoneticAccentChange={setPhoneticAccent}
            onClose={() => setActiveTab('levels')}
          />
        )}
      </AnimatePresence>

      {/* Mobile Bookmarks Overlay */}
      <AnimatePresence>
        {activeTab === 'bookmarks' && (
          <BookmarksPanel
            isBookmarked={isBookmarked}
            isLearned={isLearned}
            onWordSelect={handleSearchWordSelect}
            onClose={() => setActiveTab('levels')}
            variant="mobile"
          />
        )}
      </AnimatePresence>

      {/* Desktop Bookmarks Overlay */}
      <BookmarksPanel
        isOpen={activeTab === 'bookmarks'}
        isBookmarked={isBookmarked}
        isLearned={isLearned}
        onWordSelect={handleSearchWordSelect}
        onClose={() => setActiveTab('levels')}
        variant="desktop"
      />

      {/* Statistics Panel */}
      <StatisticsPanel isOpen={activeTab === 'stats'} onClose={() => setActiveTab('levels')} />

      {/* Mobile Search Overlay */}
      <AnimatePresence>
        {activeTab === 'search' && (
          <SearchPanel
            words={words}
            allWords={allWords}
            onWordSelect={handleSearchWordSelect}
            isLearned={isLearned}
            onClose={() => setActiveTab('levels')}
            variant="mobile"
          />
        )}
      </AnimatePresence>

      <div className="mx-auto max-w-6xl">
        <Header
          onSearchClick={() => setShowDesktopSearch(!showDesktopSearch)}
          onStatsClick={() => setActiveTab('stats')}
          onBookmarksClick={() => setActiveTab('bookmarks')}
          showDesktopSearch={showDesktopSearch}
          searchQuery={searchQuery}
          onSearchChange={setSearchQuery}
          levels={levels}
          selectedLevel={selectedLevel}
          onLevelChange={handleLevelChange}
          wordTypes={wordTypes}
          selectedTypes={selectedTypes}
          onTypeToggle={toggleType}
          onClearTypes={clearTypes}
        />

        {/* Mobile: Level Tabs + Filters */}
        <motion.section
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.1 }}
          className="mt-4 flex flex-col gap-4 md:hidden"
        >
          <DesktopLevelTabs
            levels={levels}
            selectedLevel={selectedLevel}
            onLevelChange={handleLevelChange}
            variant="mobile"
          />
          <MobileFilters
            wordTypes={wordTypes}
            selectedTypes={selectedTypes}
            onTypeToggle={toggleType}
            onClearTypes={clearTypes}
          />
        </motion.section>

        {/* Desktop: Search Panel */}
        <AnimatePresence>
          {showDesktopSearch && searchQuery && (
            <motion.div
              initial={{ opacity: 0, height: 0 }}
              animate={{ opacity: 1, height: 'auto' }}
              exit={{ opacity: 0, height: 0 }}
              className="mt-6 hidden overflow-hidden md:block"
            >
              <SearchPanel
                words={words}
                allWords={allWords}
                onWordSelect={handleSearchWordSelect}
                isLearned={isLearned}
                onClose={() => {
                  setShowDesktopSearch(false);
                  setSearchQuery('');
                }}
                variant="desktop"
                initialQuery={searchQuery}
              />
            </motion.div>
          )}
        </AnimatePresence>

        {/* Mobile: Word Card */}
        <div className="mt-4 md:hidden">
          {hasLevelWords && currentWord ? (
            <WordCard
              word={currentWord}
              isLearned={isLearned(selectedLevel, currentWord.id)}
              isBookmarked={isBookmarked(selectedLevel, currentWord.id)}
              isCurrentWord={true}
              isSpeaking={isSpeaking || isLoopingActive}
              phoneticAccent={phoneticAccent}
              onToggleLearned={handleToggleLearned}
              onToggleBookmark={handleToggleBookmark}
              onPlayWord={handleSpeakWord}
              onStop={stop}
              onPlayExample={handleSpeakExample}
              onPrevious={handlePrevious}
              onNext={handleNext}
              currentIndex={currentWordIndex}
              totalWords={filteredWords.length}
            />
          ) : (
            <div className="rounded-2xl border border-border bg-card p-8 text-center">
              <p className="text-muted-foreground">No vocabulary data available for {selectedLevel} level yet.</p>
            </div>
          )}
        </div>

        {/* Desktop: Two-column layout */}
        <div className="mt-8 hidden gap-6 md:grid md:grid-cols-[1fr,320px] lg:grid-cols-[1fr,360px]">
          {/* Left: Word Card */}
          <motion.section
            initial={{ opacity: 0, x: -20 }}
            animate={{ opacity: 1, x: 0 }}
            transition={{ delay: 0.2 }}
          >
            {hasLevelWords && currentWord ? (
              <DesktopWordCard
                word={currentWord}
                isLearned={isLearned(selectedLevel, currentWord.id)}
                isBookmarked={isBookmarked(selectedLevel, currentWord.id)}
                isSpeaking={isSpeaking || isLoopingActive}
                isLooping={isLooping}
                phoneticAccent={phoneticAccent}
                onToggleLearned={handleToggleLearned}
                onToggleBookmark={handleToggleBookmark}
                onPlayWord={handleSpeakWord}
                onStop={stop}
                onPlayExample={handleSpeakExample}
                onPrevious={handlePrevious}
                onNext={handleNext}
                currentIndex={currentWordIndex}
                totalWords={filteredWords.length}
                learnedCount={learnedCount}
                dailyGoal={20}
              />
            ) : (
              <div className="rounded-2xl border border-border bg-card p-12 text-center">
                <p className="text-lg text-muted-foreground">No vocabulary data available for {selectedLevel} level yet.</p>
              </div>
            )}
          </motion.section>

          {/* Right: Session Panel */}
          <motion.section
            initial={{ opacity: 0, x: 20 }}
            animate={{ opacity: 1, x: 0 }}
            transition={{ delay: 0.3 }}
          >
            <DesktopSessionPanel
              words={filteredWords}
              level={selectedLevel}
              currentIndex={currentWordIndex}
              onWordSelect={handleWordSelect}
              onPrevious={handlePrevious}
              onNext={handleNext}
              isLearned={(wordId) => isLearned(selectedLevel, wordId)}
              isBookmarked={(wordId) => isBookmarked(selectedLevel, wordId)}
              isLooping={isLooping}
              speed={speed}
              isRandomSpeed={isRandomSpeed}
              loopGap={loopGap}
              phoneticAccent={phoneticAccent}
              onToggleLoop={toggleLoop}
              onSpeedChange={setSpeed}
              onRandomSpeedToggle={() => setIsRandomSpeed(!isRandomSpeed)}
              onLoopGapChange={setLoopGap}
              onPhoneticAccentChange={setPhoneticAccent}
            />
          </motion.section>
        </div>
      </div>

      {/* Mobile: Docked Up Next + Bottom Navigation */}
      <UpNextSection
        words={filteredWords}
        currentIndex={currentWordIndex}
        onWordSelect={handleWordSelect}
        isLearned={wordId => isLearned(selectedLevel, wordId)}
      />
      <BottomNav activeTab={activeTab} onTabChange={handleTabChange} />
    </div>
  );
}
