const { Pool } = require('pg');
const pool = new Pool({
  connectionString: 'postgresql://postgres.zhtyktlktykotyzhxyps:Ch3l3l3t110977@aws-1-ap-northeast-2.pooler.supabase.com:5432/postgres'
});

async function run() {
  // Search for '3856' or 'Metrobank' or 'RED GOOSE' across all text columns
  const res = await pool.query(`
    SELECT * FROM pickle_courts WHERE name ILIKE '%RED GOOSE%' OR venue_name ILIKE '%RED GOOSE%'
  `);
  console.log('RED GOOSE courts:', JSON.stringify(res.rows, null, 2));

  // Also check booking_services
  const bs = await pool.query(`
    SELECT * FROM booking_services WHERE name ILIKE '%RED GOOSE%'
  `);
  console.log('booking_services:', JSON.stringify(bs.rows, null, 2));

  // Also check services
  const s = await pool.query(`
    SELECT * FROM services WHERE name ILIKE '%RED GOOSE%'
  `);
  console.log('services:', JSON.stringify(s.rows, null, 2));

  await pool.end();
}
run();
