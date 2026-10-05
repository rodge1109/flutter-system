const { exec } = require('child_process');

console.log('Committing and pushing flutter-project release updates...');

const cmd = 'git add lib/ pubspec.yaml pubspec.lock android/ ios/ && git commit -m "New web release bundle with payment reference, date created, and gross calculation updates" && git push';

exec(cmd, { cwd: 'C:/website/flutter-project' }, (err, stdout, stderr) => {
  console.log('=== GIT PUSH OUTPUT ===');
  console.log(stdout || stderr);
});
