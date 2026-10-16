const https = require('https');

https.get('https://pickle-system.onrender.com/api/owner/bookings/mar15oporto%40gmail.com', res => {
  let d = '';
  res.on('data', c => d += c);
  res.on('end', () => {
    const data = JSON.parse(d);
    const b = (data.bookings || []).find(x => x.id === 1188028);
    console.log('Booking 1188028:', JSON.stringify(b, null, 2));
  });
});
