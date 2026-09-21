const { Pool } = require('pg');
const pool = new Pool({
  connectionString: 'postgresql://postgres.zhtyktlktykotyzhxyps:Ch3l3l3t110977@aws-1-ap-northeast-2.pooler.supabase.com:5432/postgres'
});

async function run() {
  try {
    console.log('--- SEARCHING FOR LOVELY BEA YOCTE IN APPOINTMENTS ---');
    const appts = await pool.query(`
      SELECT id, full_name, email, service_type, preferred_date, preferred_time, status, created_at
      FROM pickle_appointment
      WHERE full_name ILIKE '%yocte%' OR full_name ILIKE '%lovely%' OR email ILIKE '%yocte%' OR email ILIKE '%lovely%'
      ORDER BY id DESC;
    `);
    console.log(`Found ${appts.rows.length} row(s):`);
    console.log(appts.rows);

  } catch (err) {
    console.error('ERROR:', err);
  } finally {
    await pool.end();
  }
}
run();
