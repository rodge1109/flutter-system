const pool = require('../../pickle-system/server/db.js');

async function migrate() {
  try {
    console.log('Running court_owner_ledger migration...');
    const createTableQuery = `
      CREATE TABLE IF NOT EXISTS court_owner_ledger (
        id SERIAL PRIMARY KEY,
        owner_email VARCHAR(255) NOT NULL,
        venue_name VARCHAR(255),
        transaction_date DATE NOT NULL DEFAULT CURRENT_DATE,
        particulars TEXT NOT NULL,
        type VARCHAR(20) NOT NULL, -- 'charge' or 'payment'
        amount NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
        reference_number VARCHAR(100),
        notes TEXT,
        created_by VARCHAR(255),
        created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
      );
      CREATE INDEX IF NOT EXISTS idx_court_owner_ledger_owner ON court_owner_ledger(owner_email, transaction_date);
    `;
    await pool.query(createTableQuery);
    console.log('Table court_owner_ledger created or already exists successfully.');
    
    // Check table columns
    const res = await pool.query(`
      SELECT column_name, data_type 
      FROM information_schema.columns 
      WHERE table_name = 'court_owner_ledger'
      ORDER BY ordinal_position;
    `);
    console.log('Columns in court_owner_ledger:', res.rows);
    process.exit(0);
  } catch (err) {
    console.error('Migration error:', err);
    process.exit(1);
  }
}

migrate();
