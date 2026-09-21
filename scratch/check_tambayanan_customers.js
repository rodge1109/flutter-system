const { Pool } = require('pg');
const pool = new Pool({
  connectionString: 'postgresql://postgres.zhtyktlktykotyzhxyps:Ch3l3l3t110977@aws-1-ap-northeast-2.pooler.supabase.com:5432/postgres'
});

async function run() {
  try {
    console.log('--- CUSTOMERS FOR TAMBAYANAN (zenaannbaterna@gmail.com) ---');
    const custs = await pool.query(`
      SELECT id, full_name, email, is_member
      FROM pickle_customer
      WHERE owner_email = 'zenaannbaterna@gmail.com';
    `);
    console.log(custs.rows);
  } catch (err) {
    console.error('ERROR:', err);
  } finally {
    await pool.end();
  }
}
run();
