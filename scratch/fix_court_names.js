const { Pool } = require('pg');
const pool = new Pool({
  connectionString: 'postgresql://postgres.zhtyktlktykotyzhxyps:Ch3l3l3t110977@aws-1-ap-northeast-2.pooler.supabase.com:5432/postgres'
});

async function run() {
  try {
    console.log('--- TRIMMING COURT NAMES IN PICKLE_COURTS ---');
    const updateRes = await pool.query(`
      UPDATE pickle_courts
      SET name = TRIM(name);
    `);
    console.log('UPDATED COURTS COUNT:', updateRes.rowCount);

    const courts = await pool.query('SELECT id, name, owner_email FROM pickle_courts ORDER BY id;');
    console.log('UPDATED COURTS LIST:');
    console.log(courts.rows);

  } catch (err) {
    console.error('ERROR:', err);
  } finally {
    await pool.end();
  }
}
run();
