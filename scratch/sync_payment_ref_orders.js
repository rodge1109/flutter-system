const { Pool } = require('pg');
const pool = new Pool({
  connectionString: 'postgresql://postgres.zhtyktlktykotyzhxyps:Ch3l3l3t110977@aws-1-ap-northeast-2.pooler.supabase.com:5432/postgres'
});

async function run() {
  try {
    console.log('Ensuring payment_reference column exists on pickle_orders...');
    await pool.query(`
      ALTER TABLE pickle_orders ADD COLUMN IF NOT EXISTS payment_reference TEXT;
    `);

    console.log('Updating pickle_orders payment_reference from pickle_appointment...');
    const result = await pool.query(`
      UPDATE pickle_orders o
      SET payment_reference = a.proof_of_payment
      FROM pickle_appointment a
      WHERE o.order_number = CONCAT('ORD-', a.id)
        AND a.proof_of_payment IS NOT NULL
        AND a.proof_of_payment != '';
    `);
    console.log(`Updated ${result.rowCount} rows in pickle_orders!`);

    // Let's also check sample updated rows
    const samples = await pool.query(`
      SELECT order_number, full_name, service_type, payment_reference, gross_amount 
      FROM pickle_orders 
      WHERE payment_reference IS NOT NULL 
      ORDER BY id DESC LIMIT 10;
    `);
    console.log('=== SAMPLE UPDATED PICKLE_ORDERS ===');
    console.log(samples.rows);
  } catch (err) {
    console.error('ERROR:', err);
  } finally {
    await pool.end();
  }
}
run();
