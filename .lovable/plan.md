

## Integrate Full Oxford Vocabulary (A1-C2)

This plan covers integrating your new vocabulary data structure with all 6 CEFR levels (A1 through C2), replacing the current B2/C1 only setup.

### Summary of Changes

Your new vocabulary structure has key differences from the current one:

| Field | Current | New |
|-------|---------|-----|
| Levels | B2, C1 | A1, A2, B1, B2, C1, C2 |
| Phonetic | `phonetic: string` | `phonetics: { us: string; uk: string }` |
| Definition | `definition: string` | `type: string` (e.g., "noun", "verb") |
| Example | `example: string` | `examples: string[]` (array) |

### Implementation Phases

---

**Phase 1: Add New Vocabulary Data Structure**

You will provide the vocabulary files. I will:

1. Create `src/data/oxford-vocabulary/types.ts` with your new types
2. Create `src/data/oxford-vocabulary/index.ts` with all level imports
3. Create level folders: `A1/`, `A2/`, `B1/`, `B2/`, `C1/`, `C2/` with `part1.ts` through `part4.ts` each

---

**Phase 2: Update Core Data Exports**

Update `src/data/oxfordVocabulary.ts`:
- Change Level type from `'B2' | 'C1'` to `'A1' | 'A2' | 'B1' | 'B2' | 'C1' | 'C2'`
- Re-export from the new structure
- Add `levelDescriptions` for all 6 levels

---

**Phase 3: Update State Management Hooks**

Update `src/hooks/useProgress.ts`:
- Change default state from `{ B2: [], C1: [] }` to include all 6 levels
- Update the database loading logic to handle all levels

Update `src/hooks/useBookmarks.ts`:
- Same changes for bookmarked words state

---

**Phase 4: Update UI Components**

**4a. Main Page (`src/pages/Index.tsx`)**
- Change `levels` array from `['B2', 'C1']` to `['A1', 'A2', 'B1', 'B2', 'C1', 'C2']`

**4b. Word Cards**

Update `src/components/WordCard.tsx`:
- Change `word.phonetic` to `word.phonetics.us` (default to US pronunciation)
- Change `word.definition` to `word.type`
- Change `word.example` to `word.examples[0]` (display first example)

Update `src/components/DesktopWordCard.tsx`:
- Same changes as WordCard

**4c. Level Tabs (`src/components/DesktopLevelTabs.tsx`)**
- Add horizontal scrolling for mobile to fit 6 tabs
- May need smaller padding on mobile

**4d. Search Panel (`src/components/SearchPanel.tsx`)**
- Change `word.definition` search to `word.type`
- Update display to show `word.type` instead of definition

**4e. Bookmarks Panel (`src/components/BookmarksPanel.tsx`)**
- Change `word.phonetic` to `word.phonetics.us`

**4f. All Words Panel (`src/components/AllWordsPanel.tsx`)**
- Change `word.definition` to `word.type`

**4g. Up Next Section (`src/components/UpNextSection.tsx`)**
- No changes needed (only displays word and level)

---

### Files to Create (You Provide Content)

```text
src/data/oxford-vocabulary/
  ├── types.ts
  ├── index.ts
  ├── A1/
  │     ├── part1.ts
  │     ├── part2.ts
  │     ├── part3.ts
  │     └── part4.ts
  ├── A2/ (same structure)
  ├── B1/ (same structure)
  ├── B2/ (same structure)
  ├── C1/ (same structure)
  └── C2/ (same structure)
```

### Files to Update

- `src/data/oxfordVocabulary.ts` - Update types and re-export
- `src/hooks/useProgress.ts` - Add all 6 levels to default state
- `src/hooks/useBookmarks.ts` - Add all 6 levels to default state
- `src/pages/Index.tsx` - Update levels array
- `src/components/WordCard.tsx` - Update phonetic, definition, example
- `src/components/DesktopWordCard.tsx` - Update phonetic, definition, example
- `src/components/DesktopLevelTabs.tsx` - Add mobile scrolling for 6 tabs
- `src/components/SearchPanel.tsx` - Update search and display
- `src/components/BookmarksPanel.tsx` - Update phonetic display
- `src/components/AllWordsPanel.tsx` - Update definition display

### Files to Delete (Cleanup)

- `src/data/c1VocabularyPart1.ts`
- `src/data/c1VocabularyPart2.ts`
- `src/data/c1VocabularyPart3.ts`
- `src/data/c1VocabularyPart4.ts`
- `src/components/LevelCard.tsx` (no longer used after previous changes)

---

### Technical Details

**New Word Type:**
```text
interface Phonetics {
  us: string;
  uk: string;
}

interface Word {
  id: string;           // e.g., "a1-001"
  word: string;         // e.g., "a"
  type: string;         // e.g., "indefinite article"
  level: Level;         // "A1" | "A2" | "B1" | "B2" | "C1" | "C2"
  phonetics: Phonetics; // { us: "/eɪ/", uk: "/eɪ/" }
  examples: string[];   // Array of example sentences
}
```

**Default Progress State:**
```text
{
  A1: [],
  A2: [],
  B1: [],
  B2: [],
  C1: [],
  C2: []
}
```

**Phonetic Display Change:**
```text
// Before
/{word.phonetic}/

// After (using US by default)
/{word.phonetics.us}/
```

**Example Display Change:**
```text
// Before
{word.example}

// After (first example from array)
{word.examples[0]}
```

---

### Next Step

Please provide the vocabulary files for all levels. You can either:
1. Upload them as files
2. Paste the content directly

I'll then create the folder structure and update all components to work with the new data format.

