const { Pool } = require('pg');
const pool = new Pool({
  connectionString: 'postgresql://postgres.zhtyktlktykotyzhxyps:Ch3l3l3t110977@aws-1-ap-northeast-2.pooler.supabase.com:5432/postgres'
});

async function run() {
  const aminovaAppts = await pool.query(`
    SELECT id, full_name, service_type, preferred_time, total_amount, status, payment_method, notes
    FROM pickle_appointment
    WHERE service_type ILIKE '%AMINOVA%'
    ORDER BY id DESC
    LIMIT 25
  `);
  console.log('AMINOVA appointments (25):', aminovaAppts.rows);

  await pool.end();
}
run();
