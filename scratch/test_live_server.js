const https = require('https');

function fetchJson(url) {
  return new Promise((resolve, reject) => {
    https.get(url, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try { resolve(JSON.parse(data)); }
        catch (e) { resolve({ raw: data }); }
      });
    }).on('error', reject);
  });
}

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
    console.log('=== GET AMINOVA SETTINGS ===');
    const getRes = await fetchJson('https://pickle-system.onrender.com/api/owner/loyalty-settings?owner_email=genovabrylejethro@gmail.com');
    console.log('GET RESPONSE:', getRes);

    console.log('\n=== TRY POSTING 0 TO LIVE RENDER SERVER ===');
    const postRes = await postJson('https://pickle-system.onrender.com/api/owner/loyalty-settings', {
      owner_email: 'genovabrylejethro@gmail.com',
      member_discount_type: 'PERCENTAGE',
      member_discount_value: 0,
      milestone_target: 10,
      free_reward_enabled: true
    });
    console.log('POST RESPONSE:', postRes);

  } catch (e) {
    console.error(e);
  }
}
run();
