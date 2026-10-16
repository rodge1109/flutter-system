const fs = require('fs');
const content = fs.readFileSync('C:/website/pickle-system/server/index.js', 'utf8');
const lines = content.split('\n');

lines.forEach((line, i) => {
  if (line.includes('/api/booking-services')) {
    console.log((i + 1) + ': ' + line.trim());
  }
});
