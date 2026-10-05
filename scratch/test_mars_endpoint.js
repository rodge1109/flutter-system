const https = require('https');

const url = 'https://pickle-system.onrender.com/api/owner-earnings/mar15oporto%40gmail.com';

https.get(url, (res) => {
  let data = '';
  res.on('data', chunk => data += chunk);
  res.on('end', () => {
    try {
      const parsed = JSON.parse(data);
      console.log('Success:', parsed.success);
      if (parsed.transactions && parsed.transactions.length > 0) {
        console.log('Total transactions returned:', parsed.transactions.length);
        console.log('\nSample MARS VALLEY transactions with payment fields:');
        parsed.transactions.slice(0, 5).forEach(t => {
          console.log({
            id: t.id,
            player_name: t.player_name,
            proof_of_payment: t.proof_of_payment,
            agent_code: t.agent_code,
            booking_type: t.booking_type
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
