const fs = require('fs');
const { exec } = require('child_process');

const path = 'C:/website/pickle-system/server/index.js';
let content = fs.readFileSync(path, 'utf8');

content = content.replaceAll('a.booking_type,', '');
content = content.replaceAll('a.booking_type', '');

fs.writeFileSync(path, content, 'utf8');

exec('node --check C:/website/pickle-system/server/index.js', (err, stdout, stderr) => {
  if (err) {
    console.error('SYNTAX ERROR:', stderr);
  } else {
    console.log('REMOVED ALL a.booking_type AND SYNTAX IS 100% VALID!');
  }
});
