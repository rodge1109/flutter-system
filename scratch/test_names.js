const https = require('https');

const url = 'https://pickle-system.onrender.com/api/owner-earnings/rodge1109%40yahoo.com';

https.get(url, (res) => {
  let data = '';
  res.on('data', chunk => data += chunk);
  res.on('end', () => {
    try {
      const parsed = JSON.parse(data);
      console.log('Players in response:');
      const names = [...new Set(parsed.transactions.map(t => t.player_name || t.full_name))];
      console.log(names);
    } catch (e) {
      console.error('Error parsing JSON:', e.message);
    }
  });
}).on('error', err => {
  console.error('Fetch error:', err.message);
});
