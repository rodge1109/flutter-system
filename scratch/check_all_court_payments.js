const { Pool } = require('pg');
const pool = new Pool({
  connectionString: 'postgresql://postgres.zhtyktlktykotyzhxyps:Ch3l3l3t110977@aws-1-ap-northeast-2.pooler.supabase.com:5432/postgres'
});

async function run() {
  const courts = await pool.query(`
    SELECT p.id, p.name, p.venue_name, p.owner_email, u.gcash_number, u.qr_code_url, u.bank_account
    FROM pickle_courts p
    LEFT JOIN users u ON p.owner_email = u.email
    ORDER BY p.id ASC
  `);
  console.log('All courts and payment details:');
  courts.rows.forEach(c => console.log(c));

  await pool.end();
}
run();
