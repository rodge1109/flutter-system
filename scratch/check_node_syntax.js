const { exec } = require('child_process');

console.log('Testing syntax of C:/website/pickle-system/server/index.js...');
exec('node --check C:/website/pickle-system/server/index.js', (err, stdout, stderr) => {
  if (err) {
    console.error('SYNTAX ERROR DETECTED:');
    console.error(stderr || err.message);
  } else {
    console.log('SYNTAX IS 100% VALID!');
  }
});
