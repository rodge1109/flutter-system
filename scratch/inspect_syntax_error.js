const fs = require('fs');

const path = 'C:/website/pickle-system/server/index.js';
let content = fs.readFileSync(path, 'utf8');

const lines = content.split('\n');
console.log('=== LINES 7460 to 7485 ===');
lines.slice(7459, 7485).forEach((line, idx) => {
  console.log(`${7460 + idx}: ${line}`);
});
