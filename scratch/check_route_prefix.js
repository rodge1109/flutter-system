const fs = require('fs');

const path = 'C:/website/pickle-system/server/index.js';
let content = fs.readFileSync(path, 'utf8');

const matches = content.match(/app\.get\(['"][^'"]+['"]/g);
console.log('=== ROUTE PATHS DEFINED IN server/index.js ===');
if (matches) {
  console.log(matches.slice(0, 30));
}
