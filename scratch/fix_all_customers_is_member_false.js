const { Pool } = require('pg');
const pool = new Pool({
  connectionString: 'postgresql://postgres.zhtyktlktykotyzhxyps:Ch3l3l3t110977@aws-1-ap-northeast-2.pooler.supabase.com:5432/postgres'
});

async function run() {
  try {
    console.log('1. Setting pickle_customer.is_member column default to FALSE in PostgreSQL database...');
    await pool.query(`
      ALTER TABLE pickle_customer
      ALTER COLUMN is_member SET DEFAULT FALSE;
    `);
    console.log('Column default successfully set to FALSE.');

    console.log('2. Updating existing customer records to is_member = FALSE...');
    const updateRes = await pool.query(`
      UPDATE pickle_customer
      SET is_member = FALSE
      WHERE is_member = TRUE;
    `);
    console.log(`Successfully updated ${updateRes.rowCount} customers from is_member = TRUE to FALSE.`);

    const checkRes = await pool.query(`
      SELECT is_member, count(*) FROM pickle_customer GROUP BY is_member;
    `);
    console.log('=== VERIFIED PICKLE_CUSTOMER IS_MEMBER COUNTS ===');
    console.log(checkRes.rows);

  } catch (err) {
    console.error('ERROR during database update:', err);
  } finally {
    await pool.end();
  }
}
run();
