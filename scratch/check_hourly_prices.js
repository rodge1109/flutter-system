const { Pool } = require('pg');
const pool = new Pool({
  connectionString: 'postgresql://postgres.zhtyktlktykotyzhxyps:Ch3l3l3t110977@aws-1-ap-northeast-2.pooler.supabase.com:5432/postgres'
});

async function run() {
  try {
    const courts = await pool.query(`
      SELECT id, name, base_price, hourly_prices
      FROM pickle_courts
      WHERE owner_email = 'genovabrylejethro@gmail.com'
    `);
    for (const c of courts.rows) {
      console.log(`=== COURT ${c.id}: ${c.name} (base_price: ${c.base_price}) ===`);
      console.log(JSON.stringify(c.hourly_prices, null, 2));
    }
  } catch (err) {
    console.error('ERROR:', err);
  } finally {
    await pool.end();
  }
}
run();
