import { Word, Level } from './types';

import { a1VocabularyPart1 } from './A1/part1';
import { a1VocabularyPart2 } from './A1/part2';
import { a1VocabularyPart3 } from './A1/part3';
import { a1VocabularyPart4 } from './A1/part4';
import { a2VocabularyPart1 } from './A2/part1';
import { a2VocabularyPart2 } from './A2/part2';
import { a2VocabularyPart3 } from './A2/part3';
import { a2VocabularyPart4 } from './A2/part4';
import { b1VocabularyPart1 } from './B1/part1';
import { b1VocabularyPart2 } from './B1/part2';
import { b1VocabularyPart3 } from './B1/part3';
import { b1VocabularyPart4 } from './B1/part4';
import { b2VocabularyPart1 } from './B2/part1';
import { b2VocabularyPart2 } from './B2/part2';
import { b2VocabularyPart3 } from './B2/part3';
import { b2VocabularyPart4 } from './B2/part4';
import { c1VocabularyPart1 } from './C1/part1';
import { c1VocabularyPart2 } from './C1/part2';
import { c1VocabularyPart3 } from './C1/part3';
import { c1VocabularyPart4 } from './C1/part4';
import { c2VocabularyPart1 } from './C2/part1';
import { c2VocabularyPart2 } from './C2/part2';
import { c2VocabularyPart3 } from './C2/part3';
import { c2VocabularyPart4 } from './C2/part4';
export const oxfordWords: Record<Level, Word[]> = {
  A1: [
    ...a1VocabularyPart1,
    ...a1VocabularyPart2,
    ...a1VocabularyPart3,
    ...a1VocabularyPart4,
  ],
  A2: [
    ...a2VocabularyPart1,
    ...a2VocabularyPart2,
    ...a2VocabularyPart3,
    ...a2VocabularyPart4,
  ],
  B1: [
    ...b1VocabularyPart1,
    ...b1VocabularyPart2,
    ...b1VocabularyPart3,
    ...b1VocabularyPart4,
  ],
  B2: [
    ...b2VocabularyPart1,
    ...b2VocabularyPart2,
    ...b2VocabularyPart3,
    ...b2VocabularyPart4,
  ],
  C1: [
    ...c1VocabularyPart1,
    ...c1VocabularyPart2,
    ...c1VocabularyPart3,
    ...c1VocabularyPart4,
  ],
  C2: [
    ...c2VocabularyPart1,
    ...c2VocabularyPart2,
    ...c2VocabularyPart3,
    ...c2VocabularyPart4,
  ],
};

export * from './types';