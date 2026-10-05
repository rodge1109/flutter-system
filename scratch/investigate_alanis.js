const { Pool } = require('pg');
const pool = new Pool({
  connectionString: 'postgresql://postgres.zhtyktlktykotyzhxyps:Ch3l3l3t110977@aws-1-ap-northeast-2.pooler.supabase.com:5432/postgres'
});

async function run() {
  try {
    const tables = await pool.query(`
      SELECT table_name 
      FROM information_schema.tables 
      WHERE table_schema = 'public'
      ORDER BY table_name;
    `);

    console.log('=== SEARCHING FOR ALANIS / LEPITEN ===');
    for (const t of tables.rows) {
      const tableName = t.table_name;
      try {
        const cols = await pool.query(`
          SELECT column_name, data_type 
          FROM information_schema.columns 
          WHERE table_name = $1
        `, [tableName]);
        
        const textCols = cols.rows
          .filter(c => ['text', 'character varying', 'varchar'].includes(c.data_type))
          .map(c => `"${c.column_name}"`);
        
        if (textCols.length === 0) continue;

        const whereClause = textCols.map(col => `${col} ILIKE '%alanis%' OR ${col} ILIKE '%lepiten%'`).join(' OR ');
        const query = `SELECT * FROM "${tableName}" WHERE ${whereClause}`;
        
        const res = await pool.query(query);
        if (res.rows.length > 0) {
          console.log(`\n>>> FOUND ${res.rows.length} match(es) in "${tableName}":`);
          console.dir(res.rows, { depth: null });
        }
      } catch (e) {
        console.error(`Error querying ${tableName}:`, e.message);
      }
    }

  } catch (err) {
    console.error('ERROR:', err);
  } finally {
    await pool.end();
  }
}
run();
