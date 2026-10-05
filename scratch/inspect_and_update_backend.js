const fs = require('fs');

const path = 'C:/website/pickle-system/server/index.js';
if (fs.existsSync(path)) {
  console.log('Found backend index.js at:', path);
  let content = fs.readFileSync(path, 'utf8');

  // Find owner-earnings route
  const idx = content.indexOf('/owner-earnings');
  if (idx !== -1) {
    console.log('Found /owner-earnings route snippet:');
    console.log(content.substring(idx, idx + 800));
  } else {
    console.log('/owner-earnings route not found directly in index.js');
  }
} else {
  console.log('Backend index.js not found at:', path);
}
