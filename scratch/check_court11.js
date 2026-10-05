const { Pool } = require('pg');
const pool = new Pool({
  connectionString: 'postgresql://postgres.zhtyktlktykotyzhxyps:Ch3l3l3t110977@aws-1-ap-northeast-2.pooler.supabase.com:5432/postgres'
});

async function run() {
  try {
    const res = await pool.query(`
      SELECT id, name, base_price, day_start_hour, night_start_hour, hourly_prices
      FROM pickle_courts
      WHERE id = 11
    `);
    console.log('=== COURT 11 DETAILS ===');
    const c = res.rows[0];
    console.log('ID:', c.id, 'Name:', c.name, 'Base Price:', c.base_price);
    
    // Check 10:00 PM (22:00) and 11:00 PM (23:00) in hourly_prices
    const hp = c.hourly_prices || [];
    console.log('Hourly price for 22:00 (10 PM):', hp.find(x => x.time === '22:00'));
    console.log('Hourly price for 23:00 (11 PM):', hp.find(x => x.time === '23:00'));

  } catch (err) {
    console.error('ERROR:', err);
  } finally {
    await pool.end();
  }
}
run();
