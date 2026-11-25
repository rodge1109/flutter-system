const { Pool } = require('pg');
const pool = new Pool({
  connectionString: 'postgresql://postgres.zhtyktlktykotyzhxyps:Ch3l3l3t110977@aws-1-ap-northeast-2.pooler.supabase.com:5432/postgres'
});

async function check() {
  try {
    const res = await pool.query(`
      SELECT trigger_name, event_manipulation, action_statement, action_timing
      FROM information_schema.triggers
      WHERE event_object_table = 'pickle_appointment'
    `);
    console.log('Triggers:', JSON.stringify(res.rows, null, 2));

    const funcRes = await pool.query(`
      SELECT routine_name, routine_definition
      FROM information_schema.routines
      WHERE routine_name LIKE '%bot%' OR routine_name LIKE '%firewall%' OR routine_name LIKE '%appointment%'
    `);
    console.log('Routines:', JSON.stringify(funcRes.rows, null, 2));
  } catch (e) {
    console.error(e);
  } finally {
    await pool.end();
  }
}
check();
