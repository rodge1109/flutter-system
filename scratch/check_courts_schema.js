const { Pool } = require('pg');
const pool = new Pool({
  connectionString: 'postgresql://postgres.zhtyktlktykotyzhxyps:Ch3l3l3t110977@aws-1-ap-northeast-2.pooler.supabase.com:5432/postgres'
});

async function run() {
  try {
    const res = await pool.query(`
      SELECT column_name, data_type, is_nullable
      FROM information_schema.columns 
      WHERE table_name = 'pickle_courts'
      ORDER BY ordinal_position;
    `);
    console.log('=== PICKLE_COURTS COLUMNS ===');
    console.table(res.rows);

    const secretDrill = await pool.query(`
      SELECT id, name, court_number, venue_name, address FROM pickle_courts WHERE name ILIKE '%Secret Drill%' OR venue_name ILIKE '%Secret Drill%';
    `);
    console.log('=== SECRET DRILL COURTS ===');
    console.table(secretDrill.rows);
  } catch (e) {
    console.error(e);
  } finally {
    await pool.end();
  }
}
run();
