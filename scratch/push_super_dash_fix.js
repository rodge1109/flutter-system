const { exec } = require('child_process');

console.log('Committing and pushing Super Dashboard calculation rule updates...');

exec('git add lib/screens/super_dashboard_screen.dart && git commit -m "Align Super Dashboard platform earnings calculation with Court Owner Dashboard checkout session rules" && git push', { cwd: 'C:/website/flutter-project' }, (err, stdout, stderr) => {
  console.log('=== GIT PUSH RESULT ===');
  console.log(stdout || stderr);
});
