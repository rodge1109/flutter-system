const { Pool } = require('pg');
const pool = new Pool({
  connectionString: 'postgresql://postgres.zhtyktlktykotyzhxyps:Ch3l3l3t110977@aws-1-ap-northeast-2.pooler.supabase.com:5432/postgres'
});

async function run() {
  try {
    const res = await pool.query(`
      SELECT column_name, data_type, is_nullable, column_default
      FROM information_schema.columns
      WHERE table_name = 'pickle_appointment'
      ORDER BY ordinal_position;
    `);
    console.log('--- COLUMNS ---');
    console.log(res.rows);

    const triggers = await pool.query(`
      SELECT trigger_name, action_statement
      FROM information_schema.triggers
      WHERE event_object_table = 'pickle_appointment';
    `);
    console.log('--- TRIGGERS ---');
    console.log(triggers.rows);

    const constraints = await pool.query(`
      SELECT conname, pg_get_constraintdef(oid)
      FROM pg_constraint
      WHERE conrelid = 'pickle_appointment'::regclass;
    `);
    console.log('--- CONSTRAINTS ---');
    console.log(constraints.rows);

  } catch (err) {
    console.error('ERROR:', err);
  } finally {
    await pool.end();
  }
}
run();
