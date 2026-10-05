const { Pool } = require('pg');
const pool = new Pool({
  connectionString: 'postgresql://postgres.zhtyktlktykotyzhxyps:Ch3l3l3t110977@aws-1-ap-northeast-2.pooler.supabase.com:5432/postgres'
});

async function run() {
  try {
    console.log('=== CHECK TRIGGERS ON PICKLE_APPOINTMENT ===');
    const trg = await pool.query(`
      SELECT trigger_name, action_statement, action_orientation, action_timing, event_manipulation
      FROM information_schema.triggers
      WHERE event_object_table = 'pickle_appointment'
    `);
    console.log(trg.rows);

    console.log('=== CHECK TRIGGER FUNCTIONS ===');
    const funcs = await pool.query(`
      SELECT routine_name, routine_definition
      FROM information_schema.routines
      WHERE routine_schema = 'public' AND routine_definition ILIKE '%pickle_customer%'
    `);
    console.log(funcs.rows);

  } catch (err) {
    console.error('ERROR:', err);
  } finally {
    await pool.end();
  }
}
run();
