const { execSync } = require('child_process');

try {
  console.log('Adding changes...');
  execSync('git add .', { cwd: 'C:/website/pickle-system', stdio: 'inherit' });

  console.log('Committing changes...');
  execSync('git commit -m "Include court_number and base_price in booking-services and define finalOpenTime and finalCourtNumber in court routes"', { cwd: 'C:/website/pickle-system', stdio: 'inherit' });

  console.log('Pushing changes to GitHub...');
  execSync('git push', { cwd: 'C:/website/pickle-system', stdio: 'inherit' });

  console.log('SUCCESS: Backend updated and pushed to Render!');
} catch (e) {
  console.error('ERROR:', e.message);
}
