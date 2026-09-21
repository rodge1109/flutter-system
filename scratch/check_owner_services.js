const { Pool } = require('pg');
const pool = new Pool({
  connectionString: 'postgresql://postgres.zhtyktlktykotyzhxyps:Ch3l3l3t110977@aws-1-ap-northeast-2.pooler.supabase.com:5432/postgres'
});

async function run() {
  try {
    console.log('--- CHECKING booking_services ---');
    const services = await pool.query('SELECT * FROM booking_services ORDER BY id;');
    console.log(services.rows);

    console.log('\n--- CHECKING booking_specialists ---');
    const specialists = await pool.query('SELECT * FROM booking_specialists ORDER BY id;');
    console.log(specialists.rows);

    console.log('\n--- CHECKING pickle_courts ---');
    const courts = await pool.query('SELECT * FROM pickle_courts ORDER BY id;');
    console.log(courts.rows);

    console.log('\n--- CHECKING users (Zena Ann Baterna) ---');
    const users = await pool.query("SELECT id, name, email, role, court_id, court_name, venue_id, venue_name FROM users WHERE name ILIKE '%Zena%' OR email ILIKE '%zena%';");
    console.log(users.rows);

  } catch (err) {
    console.error('ERROR:', err);
  } finally {
    await pool.end();
  }
}
run();
