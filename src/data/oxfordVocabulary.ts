// Re-export from new oxford-vocabulary structure
export { oxfordWords } from './oxford-vocabulary';
export type { Word, Level, Phonetics } from './oxford-vocabulary/types';

// Level descriptions for UI
export const levelDescriptions: Record<import('./oxford-vocabulary/types').Level, { name: string; description: string }> = {
  A1: {
    name: 'Beginner',
    description: 'Basic everyday words and expressions',
  },
  A2: {
    name: 'Elementary',
    description: 'Simple phrases for routine tasks',
  },
  B1: {
    name: 'Intermediate',
    description: 'Main points on familiar topics',
  },
  B2: {
    name: 'Upper-Intermediate',
    description: 'Complex texts and abstract topics',
  },
  C1: {
    name: 'Advanced',
    description: 'Fluent, spontaneous expression',
  },
  C2: {
    name: 'Proficiency',
    description: 'Near-native level mastery',
  },
};
