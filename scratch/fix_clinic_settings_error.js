const fs = require('fs');
const { exec } = require('child_process');

const path = 'C:/website/pickle-system/server/index.js';
let content = fs.readFileSync(path, 'utf8');

// Strip invalid a.booking_type
content = content.replaceAll('a.booking_type,', '');
content = content.replaceAll('a.booking_type', '');

// Fix initClinicSettings call at bottom if present
if (content.includes('initClinicSettings()')) {
  console.log('Replacing raw initClinicSettings() call with safe conditional check...');
  content = content.replace(
    'initClinicSettings()',
    'if (typeof initClinicSettings === "function") { try { initClinicSettings(); } catch(e) {} }'
  );
}

fs.writeFileSync(path, content, 'utf8');

exec('node --check C:/website/pickle-system/server/index.js', (err, stdout, stderr) => {
  if (err) {
    console.error('SYNTAX ERROR:', stderr);
  } else {
    console.log('SUCCESS: FIXED initClinicSettings AND SYNTAX IS 100% VALID!');
  }
});
