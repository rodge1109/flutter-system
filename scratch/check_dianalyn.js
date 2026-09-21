const { Pool } = require('pg');
const pool = new Pool({
  connectionString: 'postgresql://postgres.zhtyktlktykotyzhxyps:Ch3l3l3t110977@aws-1-ap-northeast-2.pooler.supabase.com:5432/postgres'
});

async function run() {
  try {
    console.log('--- SEARCHING FOR DIANALYN LACSON IN APPOINTMENTS ---');
    const appts = await pool.query(`
      SELECT *
      FROM pickle_appointment
      WHERE full_name ILIKE '%dianalyn%' OR full_name ILIKE '%lacson%' OR email ILIKE '%dianalyn%'
      ORDER BY id DESC;
    `);
    console.log(`Found ${appts.rows.length} appointment(s):`);
    console.log(appts.rows);

    console.log('\n--- SEARCHING FOR DIANALYN LACSON IN CUSTOMERS ---');
    const custs = await pool.query(`
      SELECT *
      FROM pickle_customer
      WHERE full_name ILIKE '%dianalyn%' OR full_name ILIKE '%lacson%' OR email ILIKE '%dianalyn%';
    `);
    console.log(`Found ${custs.rows.length} customer(s):`);
    console.log(custs.rows);

    console.log('\n--- AMINOVA COURTS (genovabrylejethro@gmail.com) ---');
    const courts = await pool.query(`
      SELECT id, name, owner_email, base_price, day_discount_rate, night_discount_rate, is_day_discount_active, is_night_discount_active, day_start_hour, night_start_hour, hourly_prices
      FROM pickle_courts
      WHERE owner_email = 'genovabrylejethro@gmail.com';
    `);
    console.log(courts.rows);

    console.log('\n--- AMINOVA LOYALTY SETTINGS ---');
    const loyalty = await pool.query(`
      SELECT *
      FROM pickle_loyalty_settings
      WHERE owner_email = 'genovabrylejethro@gmail.com';
    `);
    console.log(loyalty.rows);

  } catch (err) {
    console.error('ERROR:', err);
  } finally {
    await pool.end();
  }
}
run();
