const { Pool } = require('pg');
const pool = new Pool({
  connectionString: 'postgresql://postgres.zhtyktlktykotyzhxyps:Ch3l3l3t110977@aws-1-ap-northeast-2.pooler.supabase.com:5432/postgres'
});

async function run() {
  try {
    const res = await pool.query(`SELECT * FROM pickle_customer`);
    console.log(`=== TOTAL CUSTOMERS IN DB: ${res.rows.length} ===`);
    console.dir(res.rows, { depth: null });
  } catch (err) {
    console.error('ERROR:', err);
  } finally {
    await pool.end();
  }
}
run();
