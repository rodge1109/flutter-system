const { Pool } = require('pg');
const pool = new Pool({
  connectionString: 'postgresql://postgres.zhtyktlktykotyzhxyps:Ch3l3l3t110977@aws-1-ap-northeast-2.pooler.supabase.com:5432/postgres'
});

async function run() {
  try {
    const res = await pool.query(`
      SELECT column_name, column_default, data_type 
      FROM information_schema.columns 
      WHERE table_name = 'pickle_customer';
    `);
    console.log('=== PICKLE_CUSTOMER COLUMNS ===');
    console.log(res.rows);

    const custs = await pool.query(`
      SELECT id, owner_email, full_name, email, is_member FROM pickle_customer ORDER BY id DESC LIMIT 20;
    `);
    console.log('=== RECENT PICKLE_CUSTOMER ENTRIES ===');
    console.log(custs.rows);
  } catch (err) {
    console.error('ERROR:', err);
  } finally {
    await pool.end();
  }
}
run();
