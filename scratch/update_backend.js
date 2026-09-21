const fs = require('fs');
const filePath = 'C:/website/pickle-system/server/index.js';

let content = fs.readFileSync(filePath, 'utf8');

const target = "app.post('/api/appointments/hold', async (req, res) => {";
const replacement = "app.post('/api/appointments/hold-v2-secure', async (req, res) => {";

if (content.includes(target)) {
  content = content.replace(target, replacement);
  fs.writeFileSync(filePath, content, 'utf8');
  console.log('SUCCESSFULLY_PATCHED_BACKEND');
} else {
  console.log('TARGET_NOT_FOUND');
}
