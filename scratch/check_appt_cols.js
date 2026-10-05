const { Pool } = require('pg');
const pool = new Pool({
  connectionString: 'postgresql://postgres.zhtyktlktykotyzhxyps:Ch3l3l3t110977@aws-1-ap-northeast-2.pooler.supabase.com:5432/postgres'
});

async function run() {
  try {
    const res = await pool.query(`
      SELECT column_name FROM information_schema.columns WHERE table_name = 'pickle_appointment';
    `);
    console.log('=== PICKLE_APPOINTMENT COLUMNS ===');
    console.log(res.rows.map(r => r.column_name));
  } catch (err) {
    console.error('ERROR:', err);
  } finally {
    await pool.end();
  }
}
run();
