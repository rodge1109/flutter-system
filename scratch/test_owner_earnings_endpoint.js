const https = require('https');

const url = 'https://pickle-system.onrender.com/api/owner-earnings/rodge1109%40yahoo.com';

https.get(url, (res) => {
  let data = '';
  res.on('data', chunk => data += chunk);
  res.on('end', () => {
    try {
      const parsed = JSON.parse(data);
      console.log('Success:', parsed.success);
      if (parsed.transactions && parsed.transactions.length > 0) {
        console.log('Total transactions returned:', parsed.transactions.length);
        console.log('Sample transaction keys:', Object.keys(parsed.transactions[0]));
        console.log('\nFirst 10 transactions payment fields:');
        parsed.transactions.slice(0, 10).forEach(t => {
          console.log({
            id: t.id,
            player_name: t.player_name || t.full_name,
            payment_reference: t.payment_reference,
            proof_of_payment: t.proof_of_payment,
            agent_code: t.agent_code,
            order_number: t.order_number
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
