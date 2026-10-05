const { Pool } = require('pg');
const pool = new Pool({
  connectionString: 'postgresql://postgres.zhtyktlktykotyzhxyps:Ch3l3l3t110977@aws-1-ap-northeast-2.pooler.supabase.com:5432/postgres'
});

async function run() {
  try {
    const res = await pool.query(`
      SELECT name, owner_email FROM pickle_courts WHERE LOWER(name) LIKE '%mars%' OR LOWER(name) LIKE '%marz%';
    `);
    console.log('=== MARS / MARZ VALLEY COURTS ===');
    console.log(res.rows);
  } catch (err) {
    console.error('ERROR:', err);
  } finally {
    await pool.end();
  }
}
run();
