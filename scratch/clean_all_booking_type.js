const fs = require('fs');

const path = 'C:/website/pickle-system/server/index.js';
let content = fs.readFileSync(path, 'utf8');

const matches = content.match(/a\.booking_type/g);
console.log('Matches for a.booking_type:', matches ? matches.length : 0);

if (content.includes('a.booking_type')) {
  content = content.replaceAll('a.booking_type,', '').replaceAll('a.booking_type', '');
  fs.writeFileSync(path, content, 'utf8');
  console.log('REMOVED ALL INSTANCES OF a.booking_type FROM server/index.js!');
}
