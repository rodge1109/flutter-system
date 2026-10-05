const https = require('https');

const url = 'https://pickle-system.onrender.com/api/owner/bookings/rodge1109%40yahoo.com';

https.get(url, (res) => {
  let data = '';
  res.on('data', chunk => data += chunk);
  res.on('end', () => {
    try {
      const parsed = JSON.parse(data);
      console.log('Success:', parsed.success);
      if (parsed.bookings && parsed.bookings.length > 0) {
        console.log('Total bookings returned:', parsed.bookings.length);
        console.log('Sample booking keys:', Object.keys(parsed.bookings[0]));
        console.log('\nFirst 5 bookings payment fields:');
        parsed.bookings.slice(0, 5).forEach(b => {
          console.log({
            id: b.id,
            full_name: b.full_name,
            proof_of_payment: b.proof_of_payment,
            agent_code: b.agent_code,
            payment_reference: b.payment_reference
          });
        });
      }
    } catch (e) {
      console.error('Error parsing JSON:', e.message);
    }
  });
}).on('error', err => {
  console.error('Fetch error:', err.message);
});
