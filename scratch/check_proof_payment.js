const { Pool } = require('pg');
const pool = new Pool({
  connectionString: 'postgresql://postgres.zhtyktlktykotyzhxyps:Ch3l3l3t110977@aws-1-ap-northeast-2.pooler.supabase.com:5432/postgres'
});

async function run() {
  try {
    const res = await pool.query(`
      SELECT id, full_name, email, service_type, proof_of_payment, agent_code, created_at 
      FROM pickle_appointment 
      WHERE status != 'cancelled' OR status IS NULL
      ORDER BY id DESC LIMIT 20;
    `);
    console.log('=== RECENT PICKLE_APPOINTMENTS ===');
    console.log(res.rows);
  } catch (err) {
    console.error('ERROR:', err);
  } finally {
    await pool.end();
  }
}
run();
