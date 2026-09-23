const { Pool } = require('pg');
const pool = new Pool({
  connectionString: 'postgresql://postgres.zhtyktlktykotyzhxyps:Ch3l3l3t110977@aws-1-ap-northeast-2.pooler.supabase.com:5432/postgres'
});

async function fixTimes() {
  try {
    const res = await pool.query("SELECT id, preferred_time FROM pickle_appointment WHERE preferred_time LIKE '%: %'");
    console.log(`Found ${res.rows.length} rows to fix.`);
    for (const row of res.rows) {
      const idx = row.preferred_time.indexOf(': ');
      if (idx !== -1) {
        const cleanTime = row.preferred_time.substring(idx + 2).trim();
        await pool.query("UPDATE pickle_appointment SET preferred_time = $1 WHERE id = $2", [cleanTime, row.id]);
        console.log(`Updated ID ${row.id}: '${row.preferred_time}' -> '${cleanTime}'`);
      }
    }
  } catch (err) {
    console.error(err);
  } finally {
    await pool.end();
  }
}

fixTimes();
