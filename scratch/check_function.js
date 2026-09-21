const { Pool } = require('pg');
const pool = new Pool({
  connectionString: 'postgresql://postgres.zhtyktlktykotyzhxyps:Ch3l3l3t110977@aws-1-ap-northeast-2.pooler.supabase.com:5432/postgres'
});

async function run() {
  try {
    const res = await pool.query(`
      SELECT routine_name, routine_definition
      FROM information_schema.routines
      WHERE routine_name = 'block_bot_require_fullname';
    `);
    console.log('--- ROUTINE DEFINITION ---');
    console.log(res.rows);
  } catch (err) {
    console.error('ERROR:', err);
  } finally {
    await pool.end();
  }
}
run();
