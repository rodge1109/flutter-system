const { Pool } = require('pg');
const pool = new Pool({
  connectionString: 'postgresql://postgres.zhtyktlktykotyzhxyps:Ch3l3l3t110977@aws-1-ap-northeast-2.pooler.supabase.com:5432/postgres'
});

async function run() {
  try {
    console.log('--- CUSTOMERS FOR AMINOVA (genovabrylejethro@gmail.com) ---');
    const custs = await pool.query(`
      SELECT id, full_name, email, phone, is_member, stamp_count, total_bookings, created_at
      FROM pickle_customer
      WHERE owner_email = 'genovabrylejethro@gmail.com'
      ORDER BY id DESC;
    `);
    console.log(custs.rows);
  } catch (err) {
    console.error('ERROR:', err);
  } finally {
    await pool.end();
  }
}
run();
