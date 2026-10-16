const { Pool } = require('pg');
const pool = new Pool({
  connectionString: 'postgresql://postgres.zhtyktlktykotyzhxyps:Ch3l3l3t110977@aws-1-ap-northeast-2.pooler.supabase.com:5432/postgres'
});

async function run() {
  const users = await pool.query(`
    SELECT id, email, gcash_number, paymaya_number, bank_account, bank_account_name, qr_code_url, payment_instructions
    FROM users 
    WHERE email ILIKE '%redgoose%' OR email ILIKE '%aminova%' OR email ILIKE '%mar15%' OR email ILIKE '%oporto%'
  `);
  console.log('Owners in users table:');
  users.rows.forEach(u => console.log(u));

  const allWithQr = await pool.query(`
    SELECT id, email, gcash_number, qr_code_url FROM users WHERE qr_code_url IS NOT NULL OR gcash_number IS NOT NULL
  `);
  console.log('Users with qr or gcash:', allWithQr.rows);

  await pool.end();
}
run();
