const { Pool } = require('pg');
const pool = new Pool({
  connectionString: 'postgresql://postgres.zhtyktlktykotyzhxyps:Ch3l3l3t110977@aws-1-ap-northeast-2.pooler.supabase.com:5432/postgres'
});

async function run() {
  try {
    const courts = await pool.query(`
      SELECT * FROM pickle_courts WHERE id IN (10, 11)
    `);
    console.log('=== COURTS 10 & 11 ===');
    console.dir(courts.rows, { depth: null });
  } catch (err) {
    console.error('ERROR:', err);
  } finally {
    await pool.end();
  }
}
run();
