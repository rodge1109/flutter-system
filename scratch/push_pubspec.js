const { exec } = require('child_process');

console.log('Committing version bump pubspec.yaml to git...');
exec('git add pubspec.yaml pubspec.lock && git commit -m "Bump version to 1.0.39+47 for Android App Bundle release" && git push', { cwd: 'C:/website/flutter-project' }, (err, stdout, stderr) => {
  console.log(stdout || stderr);
});
