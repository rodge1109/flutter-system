const { Pool } = require('pg');
const pool = new Pool({
  connectionString: 'postgresql://postgres.zhtyktlktykotyzhxyps:Ch3l3l3t110977@aws-1-ap-northeast-2.pooler.supabase.com:5432/postgres'
});

async function run() {
  try {
    console.log('=== CHECKING PICKLE_LOYALTY_LOGS ===');
    const res = await pool.query(`SELECT * FROM pickle_loyalty_logs ORDER BY id DESC LIMIT 50`);
    console.log(res.rows);
  } catch (err) {
    console.error('ERROR:', err);
  } finally {
    await pool.end();
  }
}
run();
