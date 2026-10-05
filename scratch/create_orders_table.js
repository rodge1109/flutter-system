const { Pool } = require('pg');
const pool = new Pool({
  connectionString: 'postgresql://postgres.zhtyktlktykotyzhxyps:Ch3l3l3t110977@aws-1-ap-northeast-2.pooler.supabase.com:5432/postgres'
});

async function run() {
  try {
    const query = `
      CREATE TABLE IF NOT EXISTS pickle_orders (
        id SERIAL PRIMARY KEY,
        order_number VARCHAR(100) UNIQUE NOT NULL,
        user_email VARCHAR(255) NOT NULL,
        full_name VARCHAR(255) NOT NULL,
        phone_number VARCHAR(50),
        court_id INTEGER,
        service_type VARCHAR(255) NOT NULL,
        preferred_date DATE NOT NULL,
        preferred_time TEXT,
        total_hours INTEGER DEFAULT 1,
        gross_amount NUMERIC(10,2) NOT NULL DEFAULT 0.00,
        service_fee NUMERIC(10,2) NOT NULL DEFAULT 15.00,
        net_amount NUMERIC(10,2) NOT NULL DEFAULT 0.00,
        payment_method VARCHAR(50) DEFAULT 'GCash',
        billing_status VARCHAR(50) DEFAULT 'paid',
        booking_type VARCHAR(50) DEFAULT 'player_online',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
    `;
    await pool.query(query);
    console.log('SUCCESS: pickle_orders table created cleanly without touching any existing tables!');

    const res = await pool.query(`
      SELECT column_name, data_type 
      FROM information_schema.columns 
      WHERE table_name = 'pickle_orders';
    `);
    console.log('=== PICKLE_ORDERS COLUMNS ===');
    console.log(res.rows);
  } catch (err) {
    console.error('Error creating pickle_orders table:', err);
  } finally {
    await pool.end();
  }
}

run();
