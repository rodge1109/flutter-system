const { Pool } = require('pg');
const pool = new Pool({
  connectionString: 'postgresql://postgres.zhtyktlktykotyzhxyps:Ch3l3l3t110977@aws-1-ap-northeast-2.pooler.supabase.com:5432/postgres'
});

async function run() {
  try {
    const appts = await pool.query(`
      SELECT id, full_name, email, service_type, preferred_date, preferred_time, status, total_amount, proof_of_payment
      FROM pickle_appointment
      WHERE (full_name ILIKE '%yocte%' OR email ILIKE '%yocte%') AND status = 'confirmed'
      ORDER BY id DESC;
    `);
    console.log('--- CONFIRMED BOOKINGS FOR LOVELY BEA YOCTE ---');
    console.log(appts.rows);
  } catch (err) {
    console.error('ERROR:', err);
  } finally {
    await pool.end();
  }
}
run();
