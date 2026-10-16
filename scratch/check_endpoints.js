const fs = require('fs');
const content = fs.readFileSync('C:/website/pickle-system/server/index.js', 'utf8');
const lines = content.split('\n');
const idx = lines.findIndex(l => l.includes("app.post('/api/appointments'"));
if (idx !== -1) {
  console.log(lines.slice(idx + 80, idx + 160).join('\n'));
}
