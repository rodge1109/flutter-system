const https = require('https');

const url = 'https://pickle-system.onrender.com/api/owner/bookings/mar15oporto%40gmail.com';

https.get(url, (res) => {
  let data = '';
  res.on('data', chunk => data += chunk);
  res.on('end', () => {
    try {
      const parsed = JSON.parse(data);
      const jlou = parsed.bookings.find(b => (b.full_name || '').includes('jloucarmelotes'));
      console.log('=== EXACT JLOUCARMELOTES BOOKING OBJECT FROM API ===');
      console.log(jlou);
    } catch (e) {
      console.error('Error:', e.message);
    }
  });
});
