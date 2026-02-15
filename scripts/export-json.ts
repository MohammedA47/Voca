import { oxfordWords } from '../src/data/oxford-vocabulary';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

console.log("Exporting vocabulary...");

// Flatten
let allWords: any[] = [];
Object.values(oxfordWords).forEach((levelWords: any) => {
    allWords = allWords.concat(levelWords);
});

const outputPath = path.resolve(__dirname, '../oxford_vocabulary.json');

fs.writeFileSync(outputPath, JSON.stringify(allWords, null, 2));

console.log(`Exported ${allWords.length} words to ${outputPath}`);
