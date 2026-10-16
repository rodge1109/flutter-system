const { Pool } = require('pg');
const pool = new Pool({
  connectionString: 'postgresql://postgres.zhtyktlktykotyzhxyps:Ch3l3l3t110977@aws-1-ap-northeast-2.pooler.supabase.com:5432/postgres'
});

async function run() {
  const { rows: courts } = await pool.query(`
    SELECT p.*, 
      u.gcash_number, 
      u.paymaya_number, 
      u.bank_account, 
      u.bank_account_name,
      u.qr_code_url,
      u.payment_instructions
    FROM pickle_courts p
    LEFT JOIN users u ON p.owner_email = u.email
    WHERE p.active = true
  `);

  console.log('--- COURTS LOADED ---');
  courts.forEach(c => {
    console.log({
      name: c.name,
      venue_name: c.venue_name,
      owner_email: c.owner_email,
      gcash_number: c.gcash_number,
      qr_code_url: c.qr_code_url,
      bank_account: c.bank_account
    });
  });

  await pool.end();
}
run();
