const { exec } = require('child_process');

exec('git status', { cwd: 'C:/website/pickle-system' }, (err, stdout, stderr) => {
  console.log('GIT STATUS in C:/website/pickle-system:');
  console.log(stdout || stderr);

  if (stdout.includes('modified:')) {
    console.log('Committing and pushing backend changes to Render...');
    exec('git add . && git commit -m "Include proof_of_payment, agent_code, and booking_type in owner-earnings response" && git push', { cwd: 'C:/website/pickle-system' }, (err2, stdout2, stderr2) => {
      console.log('GIT PUSH OUTPUT:');
      console.log(stdout2 || stderr2);
    });
  }
});
