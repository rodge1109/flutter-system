const { Pool } = require('pg');
const pool = new Pool({
  connectionString: 'postgresql://postgres.zhtyktlktykotyzhxyps:Ch3l3l3t110977@aws-1-ap-northeast-2.pooler.supabase.com:5432/postgres'
});

async function run() {
  const courts = await pool.query(`
    SELECT id, name, venue_name, owner_email
    FROM pickle_courts
  `);
  console.log('Courts count:', courts.rows.length);
  courts.rows.forEach(c => console.log(c));

  // Check if there is pickle_venues, pickle_owner_settings, pickle_settings, etc.
  const tables = await pool.query(`
    SELECT table_name FROM information_schema.tables WHERE table_schema = 'public'
  `);
  console.log('Tables:', tables.rows.map(t => t.table_name));

  // Check pickle_venues if exists
  if (tables.rows.some(t => t.table_name === 'pickle_venues')) {
    const venues = await pool.query(`SELECT * FROM pickle_venues`);
    console.log('Venues:', venues.rows);
  }

  // Check pickle_court_settings / pickle_owner_settings / etc.
  for (const t of tables.rows) {
    if (t.table_name.includes('setting') || t.table_name.includes('payment') || t.table_name.includes('owner')) {
      const rows = await pool.query(`SELECT * FROM ${t.table_name} LIMIT 5`);
      console.log(`Table ${t.table_name}:`, rows.rows);
    }
  }

  await pool.end();
}
run();
