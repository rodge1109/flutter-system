const fs = require('fs');

const path = 'C:/website/pickle-system/server/index.js';
let content = fs.readFileSync(path, 'utf8');

const idx = content.indexOf('/owner-earnings');
if (idx !== -1) {
  console.log('EXACT CODE SNIPPET (300 chars):');
  console.log(JSON.stringify(content.substring(idx, idx + 300)));
}
