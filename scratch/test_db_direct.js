const { Pool } = require('pg');
const pool = new Pool({
  connectionString: 'postgresql://postgres.zhtyktlktykotyzhxyps:Ch3l3l3t110977@aws-1-ap-northeast-2.pooler.supabase.com:5432/postgres'
});

async function run() {
  try {
    const ownerEmail = 'mar15oporto@gmail.com';
    const res = await pool.query(`
      SELECT 
        a.id, 
        a.full_name as player_name,
        a.preferred_date, 
        a.preferred_time, 
        a.total_amount, 
        a.status,
        a.payment_method,
        a.is_open_play,
        a.created_at,
        a.proof_of_payment,
        a.agent_code,
        c.name as court_name
      FROM pickle_appointment a
      JOIN pickle_courts c ON a.service_type = c.name
      WHERE c.owner_email = $1 
        AND a.status != 'cancelled'
        AND a.status != 'blocked'
      ORDER BY a.id DESC LIMIT 10;
    `, [ownerEmail]);

    console.log('=== SUCCESSFUL QUERY FOR MAR15OPORTO ===');
    console.log(res.rows);
  } catch (err) {
    console.error('ERROR:', err);
  } finally {
    await pool.end();
  }
}
run();
