const fs = require('fs');

const path = 'C:/website/pickle-system/server/index.js';
let content = fs.readFileSync(path, 'utf8');

console.log('=== MATCHING static or wildcard ROUTE HANDLERS ===');
const lines = content.split('\n');
lines.forEach((line, index) => {
  if (line.includes("express.static") || line.includes("app.get('*'") || line.includes('app.get("*"')) {
    console.log(`Line ${index + 1}: ${line.trim()}`);
  }
});
