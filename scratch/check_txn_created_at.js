const { Pool } = require('pg');
const pool = new Pool({
  connectionString: 'postgresql://postgres.zhtyktlktykotyzhxyps:Ch3l3l3t110977@aws-1-ap-northeast-2.pooler.supabase.com:5432/postgres'
});

async function run() {
  try {
    const res = await pool.query(`
      SELECT id, full_name, created_at, preferred_date, preferred_time
      FROM pickle_appointment 
      WHERE id IN (951036, 981605, 953264);
    `);
    console.log('=== EXACT CREATED_AT TIMESTAMPS IN POSTGRES ===');
    res.rows.forEach(r => {
      console.log({
        id: r.id,
        name: r.full_name,
        raw_created_at: r.created_at,
        iso_str: r.created_at ? new Date(r.created_at).toISOString() : null,
        local_pht: r.created_at ? new Date(r.created_at).toLocaleString('en-US', { timeZone: 'Asia/Manila' }) : null
      });
    });
  } catch (err) {
    console.error('ERROR:', err);
  } finally {
    await pool.end();
  }
}
run();
