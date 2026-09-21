const { Pool } = require('pg');
const pool = new Pool({
  connectionString: 'postgresql://postgres.zhtyktlktykotyzhxyps:Ch3l3l3t110977@aws-1-ap-northeast-2.pooler.supabase.com:5432/postgres'
});

async function run() {
  try {
    const res = await pool.query(`
      INSERT INTO pickle_appointment (full_name, phone_number, email, service_type, preferred_date, preferred_time, status)
      VALUES ($1, $2, $3, $4, $5, $6, 'pending')
      RETURNING *;
    `, ['ROGER TONACAO', '09123456789', 'test_roger@test.com', 'Orange Court', '2026-10-31', '12:00 AM']);
    
    console.log('INSERT SUCCESS:', res.rows[0]);

    // Clean up test row
    await pool.query('DELETE FROM pickle_appointment WHERE id = $1', [res.rows[0].id]);
    console.log('CLEANED UP TEST ROW');
  } catch (err) {
    console.error('INSERT ERROR:', err.message);
  } finally {
    await pool.end();
  }
}
run();
