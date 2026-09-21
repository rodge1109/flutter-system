const { Pool } = require('pg');
const pool = new Pool({
  connectionString: 'postgresql://postgres.zhtyktlktykotyzhxyps:Ch3l3l3t110977@aws-1-ap-northeast-2.pooler.supabase.com:5432/postgres'
});

async function run() {
  try {
    console.log('1. Updating Dianalyn Lacson (dianalyn.lacsonz@gmail.com) is_member to false...');
    const updateRes = await pool.query(`
      UPDATE pickle_customer
      SET is_member = FALSE
      WHERE email = 'dianalyn.lacsonz@gmail.com' AND owner_email = 'genovabrylejethro@gmail.com'
      RETURNING *;
    `);
    console.log('UPDATED CUSTOMER:', updateRes.rows[0]);

    console.log('\n2. Changing pickle_customer.is_member column default to FALSE...');
    await pool.query(`
      ALTER TABLE pickle_customer
      ALTER COLUMN is_member SET DEFAULT FALSE;
    `);
    console.log('COLUMN DEFAULT UPDATED TO FALSE SUCCESSFULLY!');

  } catch (err) {
    console.error('ERROR:', err);
  } finally {
    await pool.end();
  }
}
run();
