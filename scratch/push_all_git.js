const { exec } = require('child_process');

console.log('Checking git status in flutter-project...');

exec('git status --porcelain', { cwd: 'C:/website/flutter-project' }, (err, stdout, stderr) => {
  console.log('PORCELAIN OUTPUT:');
  console.log(stdout);

  if (stdout && stdout.trim().length > 0) {
    console.log('Staging changes, committing, and pushing to origin main...');
    exec('git add . && git commit -m "Update flutter-project with latest payment reference, date created, and release bundle configurations" && git push', { cwd: 'C:/website/flutter-project' }, (err2, stdout2, stderr2) => {
      console.log('=== GIT PUSH RESULT ===');
      console.log(stdout2 || stderr2);
    });
  } else {
    console.log('Git working tree is completely clean! Pushing to ensure remote is up to date...');
    exec('git push', { cwd: 'C:/website/flutter-project' }, (err2, stdout2, stderr2) => {
      console.log('=== GIT PUSH RESULT ===');
      console.log(stdout2 || stderr2);
    });
  }
});
