const { Pool } = require('pg');
const pool = new Pool({
  connectionString: 'postgresql://postgres.zhtyktlktykotyzhxyps:Ch3l3l3t110977@aws-1-ap-northeast-2.pooler.supabase.com:5432/postgres'
});

async function run() {
  try {
    console.log('--- TAMBAYANAN COURTS ---');
    const courts = await pool.query(`
      SELECT id, name, owner_email, base_price, day_discount_rate, night_discount_rate, is_day_discount_active, is_night_discount_active, day_start_hour, night_start_hour
      FROM pickle_courts
      WHERE owner_email = 'zenaannbaterna@gmail.com';
    `);
    console.log(courts.rows);

    console.log('\n--- TAMBAYANAN LOYALTY SETTINGS ---');
    const loyalty = await pool.query(`
      SELECT *
      FROM pickle_loyalty_settings
      WHERE owner_email = 'zenaannbaterna@gmail.com';
    `);
    console.log(loyalty.rows);

  } catch (err) {
    console.error('ERROR:', err);
  } finally {
    await pool.end();
  }
}
run();
