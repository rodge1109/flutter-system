const { Pool } = require('pg');
const pool = new Pool({
  connectionString: 'postgresql://postgres.zhtyktlktykotyzhxyps:Ch3l3l3t110977@aws-1-ap-northeast-2.pooler.supabase.com:5432/postgres'
});

async function run() {
  try {
    const ownerEmail = 'zenaannbaterna@gmail.com';
    
    console.log('--- COURTS FOR ZENA ANN BATERNA ---');
    const courts = await pool.query('SELECT id, name, owner_email FROM pickle_courts WHERE owner_email = $1;', [ownerEmail]);
    console.log(courts.rows);

    const courtIds = courts.rows.map(c => c.id);
    const courtNames = courts.rows.map(c => c.name);

    console.log('\n--- QUERY BY specialist_id IN courtIds ---');
    const q1 = await pool.query('SELECT id, full_name, service_type, preferred_date, preferred_time, status, specialist_id FROM pickle_appointment WHERE specialist_id = ANY($1::int[]);', [courtIds]);
    console.log(q1.rows);

    console.log('\n--- QUERY BY service_type IN courtNames ---');
    const q2 = await pool.query('SELECT id, full_name, service_type, preferred_date, preferred_time, status, specialist_id FROM pickle_appointment WHERE service_type = ANY($1::text[]);', [courtNames]);
    console.log(q2.rows);

    console.log('\n--- QUERY BY TRIM(service_type) IN TRIM(courtNames) ---');
    const trimmedNames = courtNames.map(n => n.trim());
    const q3 = await pool.query('SELECT id, full_name, service_type, preferred_date, preferred_time, status, specialist_id FROM pickle_appointment WHERE TRIM(service_type) = ANY($1::text[]);', [trimmedNames]);
    console.log(q3.rows);

    console.log('\n--- CHECK PREFERRED_DATE FILTER ---');
    const q4 = await pool.query(`
      SELECT id, full_name, service_type, preferred_date, preferred_time, status, specialist_id
      FROM pickle_appointment
      WHERE specialist_id = 15 AND preferred_date >= CURRENT_DATE;
    `);
    console.log('preferred_date >= CURRENT_DATE:', q4.rows);

  } catch (err) {
    console.error('ERROR:', err);
  } finally {
    await pool.end();
  }
}
run();
