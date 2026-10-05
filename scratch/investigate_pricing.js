const { Pool } = require('pg');
const pool = new Pool({
  connectionString: 'postgresql://postgres.zhtyktlktykotyzhxyps:Ch3l3l3t110977@aws-1-ap-northeast-2.pooler.supabase.com:5432/postgres'
});

async function run() {
  try {
    console.log('\n=== CHECKING ALL AMINOVA COURTS & PRICING ===');
    const courts = await pool.query(`
      SELECT *
      FROM pickle_courts
      WHERE owner_email = 'genovabrylejethro@gmail.com' OR venue_name ILIKE '%aminova%' OR name ILIKE '%aminova%'
    `);
    console.log('pickle_courts:', courts.rows);

    console.log('\n=== CHECKING AMINOVA LOYALTY SETTINGS ===');
    const loyalty = await pool.query(`
      SELECT * FROM pickle_loyalty_settings
      WHERE owner_email = 'genovabrylejethro@gmail.com'
    `);
    console.log('pickle_loyalty_settings:', loyalty.rows);

    console.log('\n=== CHECKING ALL CUSTOMERS FOR AMINOVA OWNER ===');
    const allCusts = await pool.query(`
      SELECT * FROM pickle_customer
      WHERE owner_email = 'genovabrylejethro@gmail.com'
    `);
    console.log('pickle_customer count:', allCusts.rows.length);
    console.log('pickle_customer list:', allCusts.rows);

  } catch (err) {
    console.error('ERROR:', err);
  } finally {
    await pool.end();
  }
}
run();
