const { Pool } = require('pg');
const pool = new Pool({
  connectionString: 'postgresql://postgres.zhtyktlktykotyzhxyps:Ch3l3l3t110977@aws-1-ap-northeast-2.pooler.supabase.com:5432/postgres'
});

async function run() {
  try {
    console.log('--- DISTINCT STATUS VALUES IN PICKLE_APPOINTMENT ---');
    const distinct = await pool.query(`
      SELECT status, COUNT(*) as count
      FROM pickle_appointment
      GROUP BY status
      ORDER BY count DESC;
    `);
    console.log(distinct.rows);

    console.log('\n--- ROWS WITH STATUS = queued ---');
    const queuedRows = await pool.query(`
      SELECT id, full_name, email, service_type, preferred_date, preferred_time, status, created_at, proof_of_payment
      FROM pickle_appointment
      WHERE status ILIKE '%queued%' OR status ILIKE '%queue%'
      ORDER BY id DESC
      LIMIT 20;
    `);
    console.log(`Found ${queuedRows.rows.length} row(s):`);
    console.log(queuedRows.rows);

  } catch (err) {
    console.error('ERROR:', err);
  } finally {
    await pool.end();
  }
}
run();
