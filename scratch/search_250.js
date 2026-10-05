const { Pool } = require('pg');
const pool = new Pool({
  connectionString: 'postgresql://postgres.zhtyktlktykotyzhxyps:Ch3l3l3t110977@aws-1-ap-northeast-2.pooler.supabase.com:5432/postgres'
});

async function run() {
  try {
    console.log('=== SEARCHING FOR 250 IN PICKLE_APPOINTMENT ===');
    const res = await pool.query(`
      SELECT id, full_name, email, service_type, preferred_date, preferred_time, total_amount, created_at
      FROM pickle_appointment
      WHERE total_amount = '250.00' OR total_amount = '250'
      ORDER BY id DESC
      LIMIT 20
    `);
    console.dir(res.rows, { depth: null });

  } catch (err) {
    console.error('ERROR:', err);
  } finally {
    await pool.end();
  }
}
run();
