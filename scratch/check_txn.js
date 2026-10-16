const https = require('https');

const url = 'https://pickle-system.onrender.com/api/owner/bookings/redgoosefoodandbev%40gmail.com';
https.get(url, (res) => {
  let d = '';
  res.on('data', chunk => d += chunk);
  res.on('end', () => {
    try {
      const data = JSON.parse(d);
      const txs = (data.bookings || []).filter(t => [1276621, 1276615, 1276396].includes(t.id));
      console.log('Found in owner bookings:', txs.length);
      console.log(JSON.stringify(txs, null, 2));
    } catch (e) {
      console.log('Error parsing JSON:', e.message, d.substring(0, 100));
    }
  });
});
