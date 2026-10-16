const { Pool } = require('pg');
const pool = new Pool({
  connectionString: 'postgresql://postgres.zhtyktlktykotyzhxyps:Ch3l3l3t110977@aws-1-ap-northeast-2.pooler.supabase.com:5432/postgres'
});

async function run() {
  try {
    const res = await pool.query('SELECT * FROM pickle_appointment WHERE id = 1188028 OR full_name ILIKE $1', ['%Jeanette%']);
    console.log('Appointments found:', res.rows.length);
    res.rows.forEach(r => {
      console.log({
        id: r.id,
        full_name: r.full_name,
        service_type: r.service_type,
        preferred_date: r.preferred_date,
        preferred_time: r.preferred_time,
        total_amount: r.total_amount,
        status: r.status,
        payment_method: r.payment_method,
        payment_reference: r.payment_reference,
        created_at: r.created_at,
        booking_type: r.booking_type,
        is_open_play: r.is_open_play,
        open_play_price: r.open_play_price,
        notes: r.notes
      });
    });
  } catch (err) {
    console.error('Error:', err);
  } finally {
    await pool.end();
  }
}

run();
