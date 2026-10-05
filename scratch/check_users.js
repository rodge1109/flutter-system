const { Pool } = require('pg');
const pool = new Pool({
  connectionString: 'postgresql://postgres.zhtyktlktykotyzhxyps:Ch3l3l3t110977@aws-1-ap-northeast-2.pooler.supabase.com:5432/postgres'
});

async function run() {
  try {
    console.log('=== CHECKING USERS TABLE FOR ALANIS ===');
    const u = await pool.query(`
      SELECT id, email, full_name, role, created_at 
      FROM users 
      WHERE email ILIKE '%alanis%' OR email ILIKE '%lepiten%' OR full_name ILIKE '%alanis%'
    `);
    console.log('users table:', u.rows);

    console.log('=== CHECKING CLIENTS TABLE FOR ALANIS ===');
    const c = await pool.query(`
      SELECT * FROM clients 
      WHERE email ILIKE '%alanis%' OR email ILIKE '%lepiten%' OR name ILIKE '%alanis%'
    `);
    console.log('clients table:', c.rows);

  } catch (err) {
    console.error('ERROR:', err);
  } finally {
    await pool.end();
  }
}
run();
