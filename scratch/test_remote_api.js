const https = require('https');

function fetchJson(url) {
  return new Promise((resolve, reject) => {
    https.get(url, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          resolve(JSON.parse(data));
        } catch (e) {
          resolve({ raw: data });
        }
      });
    }).on('error', reject);
  });
}

async function run() {
  try {
    console.log('=== TEST LOYALTY STATUS FOR ALANIS ===');
    const url1 = 'https://pickle-system.onrender.com/api/customer/loyalty-status?email=lepitenalanis@gmail.com&owner_email=genovabrylejethro@gmail.com';
    console.log('URL1:', url1);
    const res1 = await fetchJson(url1);
    console.log('Response 1:', res1);

    console.log('\n=== TEST ALL LOYALTY FOR ALANIS ===');
    const url2 = 'https://pickle-system.onrender.com/api/customer/all-loyalty?email=lepitenalanis@gmail.com';
    console.log('URL2:', url2);
    const res2 = await fetchJson(url2);
    console.log('Response 2:', res2);

  } catch (err) {
    console.error('ERROR:', err);
  }
}
run();
