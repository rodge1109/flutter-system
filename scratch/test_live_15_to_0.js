const https = require('https');
const { Pool } = require('pg');

const pool = new Pool({
  connectionString: 'postgresql://postgres.zhtyktlktykotyzhxyps:Ch3l3l3t110977@aws-1-ap-northeast-2.pooler.supabase.com:5432/postgres'
});

const ownerEmail = 'genovabrylejethro@gmail.com';

function postToLiveServer(data) {
  return new Promise((resolve, reject) => {
    const payload = JSON.stringify(data);
    const req = https.request('https://pickle-system.onrender.com/api/owner/loyalty-settings', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': payload.length
      }
    }, res => {
      let body = '';
      res.on('data', chunk => body += chunk);
      res.on('end', () => resolve(JSON.parse(body)));
    });
    req.on('error', reject);
    req.write(payload);
    req.end();
  });
}

async function runLiveTest() {
  console.log('=== STEP 1: Setting Database discount value to 15 ===');
  await pool.query(
    `UPDATE pickle_loyalty_settings SET member_discount_value = 15.00 WHERE owner_email = $1`,
    [ownerEmail]
  );
  
  let dbCheck1 = await pool.query(`SELECT * FROM pickle_loyalty_settings WHERE owner_email = $1`, [ownerEmail]);
  console.log('DB current value before save:', dbCheck1.rows[0].member_discount_value);

  console.log('\n=== STEP 2: Sending POST request with member_discount_value = 0 to Live API ===');
  const response = await postToLiveServer({
    owner_email: ownerEmail,
    member_discount_type: 'PERCENTAGE',
    member_discount_value: 0,
    milestone_target: 10,
    free_reward_enabled: true
  });

  console.log('Live Server API Response:', response);

  console.log('\n=== STEP 3: Checking Database value after POSTing 0 ===');
  let dbCheck2 = await pool.query(`SELECT * FROM pickle_loyalty_settings WHERE owner_email = $1`, [ownerEmail]);
  console.log('DB saved value after POSTing 0:', dbCheck2.rows[0].member_discount_value);

  await pool.end();
}

runLiveTest().catch(console.error);
