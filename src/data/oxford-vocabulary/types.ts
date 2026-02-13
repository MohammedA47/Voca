export type Level = 'A1' | 'A2' | 'B1' | 'B2' | 'C1' | 'C2';

export interface Phonetics {
  us: string;
  uk: string;
}

export interface Word {
  id: string;
  word: string;
  type: string;
  level: Level;
  phonetics: Phonetics;
  examples: string[];
}
