const https = require('https');

const url = 'https://pickle-system.onrender.com/api/owner-earnings/mar15oporto%40gmail.com';

https.get(url, (res) => {
  let data = '';
  res.on('data', chunk => data += chunk);
  res.on('end', () => {
    console.log('Response body:', data);
  });
}).on('error', err => {
  console.error('Fetch error:', err.message);
});
