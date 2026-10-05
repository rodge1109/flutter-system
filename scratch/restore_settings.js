const https = require('https');

function postJson(url, bodyData) {
  return new Promise((resolve, reject) => {
    const dataString = JSON.stringify(bodyData);
    const u = new URL(url);
    const req = https.request({
      hostname: u.hostname,
      port: 443,
      path: u.pathname + u.search,
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(dataString)
      }
    }, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try { resolve(JSON.parse(data)); }
        catch (e) { resolve({ raw: data }); }
      });
    }).on('error', reject);
  });
}

async function run() {
  try {
    console.log('=== RESTORING AMINOVA LOYALTY SETTINGS TO 50 ===');
    const postRes = await postJson('https://pickle-system.onrender.com/api/owner/loyalty-settings', {
      owner_email: 'genovabrylejethro@gmail.com',
      member_discount_type: 'DISCOUNT_AMOUNT',
      member_discount_value: 50,
      milestone_target: 10,
      free_reward_enabled: true
    });
    console.log('RESPONSE:', postRes);
  } catch (err) {
    console.error('ERROR:', err);
  }
}
run();
