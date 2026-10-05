const { Pool } = require('pg');

const pool = new Pool({
  connectionString: 'postgresql://postgres.zhtyktlktykotyzhxyps:Ch3l3l3t110977@aws-1-ap-northeast-2.pooler.supabase.com:5432/postgres'
});

async function run() {
  try {
    await pool.query('UPDATE pickle_loyalty_settings SET member_discount_value = 0.00 WHERE owner_email = $1', ['genovabrylejethro@gmail.com']);
    const res = await pool.query('SELECT * FROM pickle_loyalty_settings WHERE owner_email = $1', ['genovabrylejethro@gmail.com']);
    console.log('SUCCESS: Updated DB settings:', res.rows[0]);
  } catch (e) {
    console.error('ERROR:', e);
  } finally {
    await pool.end();
  }
}

run();
