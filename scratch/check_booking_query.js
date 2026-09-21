const { Pool } = require('pg');
const pool = new Pool({
  connectionString: 'postgresql://postgres.zhtyktlktykotyzhxyps:Ch3l3l3t110977@aws-1-ap-northeast-2.pooler.supabase.com:5432/postgres'
});

async function run() {
  try {
    console.log('--- SEARCHING FOR MARY GRACE VILLEGAS ---');
    const res = await pool.query(`
      SELECT *
      FROM pickle_appointment
      WHERE full_name ILIKE '%VILLEGAS%' OR full_name ILIKE '%MARY GRACE%'
      ORDER BY id DESC;
    `);
    console.log(`Found ${res.rows.length} booking(s):`);
    console.log(res.rows);

    console.log('\n--- CHECKING RECENT BOOKINGS FOR TAMBAYANAN ---');
    const resTambayanan = await pool.query(`
      SELECT id, full_name, email, service_type, preferred_date, preferred_time, status, specialist_id, doctor_id, created_at
      FROM pickle_appointment
      WHERE service_type ILIKE '%TAMBAYANAN%'
      ORDER BY id DESC
      LIMIT 10;
    `);
    console.log(`Recent TAMBAYANAN bookings (${resTambayanan.rows.length}):`);
    console.log(resTambayanan.rows);

    console.log('\n--- CHECKING RECENT ALL BOOKINGS ---');
    const resRecent = await pool.query(`
      SELECT id, full_name, email, service_type, preferred_date, preferred_time, status, specialist_id, doctor_id, created_at
      FROM pickle_appointment
      ORDER BY id DESC
      LIMIT 10;
    `);
    console.log(`Recent All bookings (${resRecent.rows.length}):`);
    console.log(resRecent.rows);

  } catch (err) {
    console.error('ERROR:', err);
  } finally {
    await pool.end();
  }
}
run();
