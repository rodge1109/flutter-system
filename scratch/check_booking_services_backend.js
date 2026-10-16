const http = require('http');

async function run() {
  const fs = require('fs');
  const content = fs.readFileSync('C:/website/pickle-system/server/index.js', 'utf8');
  const lines = content.split('\n');
  const idx = lines.findIndex(l => l.includes("app.get('/api/booking-services'"));
  if (idx !== -1) {
    console.log(lines.slice(idx, idx + 80).join('\n'));
  } else {
    console.log('Not found');
  }
}
run();
