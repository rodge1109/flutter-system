const { Pool } = require('pg');
const pool = new Pool({
  connectionString: 'postgresql://postgres.zhtyktlktykotyzhxyps:Ch3l3l3t110977@aws-1-ap-northeast-2.pooler.supabase.com:5432/postgres'
});

async function run() {
  // Check users table
  const user = await pool.query(`SELECT * FROM users WHERE email = 'redgoosefoodandbev@gmail.com'`);
  console.log('User redgoose:', user.rows);

  // Search all tables for any occurrence of 3856 or Metrobank or qr
  const tables = await pool.query(`
    SELECT table_name FROM information_schema.tables WHERE table_schema = 'public'
  `);
  
  for (const t of tables.rows) {
    const cols = await pool.query(`
      SELECT column_name FROM information_schema.columns WHERE table_name = $1 AND data_type IN ('text', 'character varying', 'json', 'jsonb')
    `, [t.table_name]);
    
    for (const c of cols.rows) {
      try {
        const match = await pool.query(`
          SELECT * FROM "${t.table_name}" WHERE CAST("${c.column_name}" AS TEXT) ILIKE '%3856%' OR CAST("${c.column_name}" AS TEXT) ILIKE '%Metrobank%' LIMIT 2
        `);
        if (match.rows.length > 0) {
          console.log(`FOUND MATCH in table ${t.table_name}, column ${c.column_name}:`, match.rows);
        }
      } catch (_) {}
    }
  }

  await pool.end();
}
run();
