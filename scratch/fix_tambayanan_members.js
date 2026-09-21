const { Pool } = require('pg');
const pool = new Pool({
  connectionString: 'postgresql://postgres.zhtyktlktykotyzhxyps:Ch3l3l3t110977@aws-1-ap-northeast-2.pooler.supabase.com:5432/postgres'
});

async function run() {
  try {
    console.log('--- UPDATING TAMBAYANAN CUSTOMERS IS_MEMBER TO FALSE ---');
    const updateRes = await pool.query(`
      UPDATE pickle_customer
      SET is_member = FALSE
      WHERE owner_email = 'zenaannbaterna@gmail.com'
      RETURNING *;
    `);
    console.log('UPDATED TAMBAYANAN CUSTOMERS:', updateRes.rows);
  } catch (err) {
    console.error('ERROR:', err);
  } finally {
    await pool.end();
  }
}
run();
