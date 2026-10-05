const { exec } = require('child_process');

exec('git status', { cwd: 'C:/website/flutter-project' }, (err, stdout, stderr) => {
  console.log('=== GIT STATUS FLUTTER PROJECT ===');
  console.log(stdout || stderr);
});
