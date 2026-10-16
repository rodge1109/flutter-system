const pool = require('../../pickle-system/server/db.js');

async function testCRUD() {
  try {
    console.log('Testing Ledger CRUD operations...');

    // 1. Insert Charge
    const insertRes1 = await pool.query(`
      INSERT INTO court_owner_ledger (owner_email, venue_name, transaction_date, particulars, type, amount, reference_number, notes, created_by)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
      RETURNING *;
    `, [
      'karlonezeroz@gmail.com',
      'Secret Drill',
      '2026-10-01',
      'Monthly Platform Fee - October 2026',
      'charge',
      1500.00,
      'INV-2026-001',
      'Regular monthly software fee',
      'superadmin@system.com'
    ]);
    const id1 = insertRes1.rows[0].id;
    console.log('Inserted charge entry:', id1);

    // 2. Insert Payment
    const insertRes2 = await pool.query(`
      INSERT INTO court_owner_ledger (owner_email, venue_name, transaction_date, particulars, type, amount, reference_number, notes, created_by)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
      RETURNING *;
    `, [
      'karlonezeroz@gmail.com',
      'Secret Drill',
      '2026-10-05',
      'GCash Payment for Oct Subscription',
      'payment',
      1000.00,
      'GCASH-998877',
      'Partial payment received',
      'superadmin@system.com'
    ]);
    const id2 = insertRes2.rows[0].id;
    console.log('Inserted payment entry:', id2);

    // 3. Query ledger for owner
    const fetchRes = await pool.query(`
      SELECT 
        id,
        owner_email,
        venue_name,
        TO_CHAR(transaction_date, 'YYYY-MM-DD') as transaction_date,
        particulars,
        type,
        amount::numeric(12,2) as amount,
        reference_number,
        notes
      FROM court_owner_ledger
      WHERE LOWER(TRIM(owner_email)) = 'karlonezeroz@gmail.com'
      ORDER BY transaction_date ASC, id ASC;
    `);

    let runningBalance = 0.0;
    const computed = fetchRes.rows.map(r => {
      const amt = parseFloat(r.amount) || 0.0;
      const isCharge = r.type.toLowerCase() === 'charge';
      const chg = isCharge ? amt : 0.0;
      const pay = !isCharge ? amt : 0.0;
      runningBalance += (chg - pay);
      return {
        ...r,
        charges: chg,
        payment: pay,
        running_balance: runningBalance
      };
    });
    console.log('Computed ledger entries for Secret Drill:');
    console.table(computed);

    // 4. Update id2
    await pool.query(`
      UPDATE court_owner_ledger
      SET amount = $1, notes = $2
      WHERE id = $3
    `, [1500.00, 'Full payment received', id2]);
    console.log('Updated payment entry to 1500.00');

    // 5. Clean up test records
    await pool.query('DELETE FROM court_owner_ledger WHERE id IN ($1, $2)', [id1, id2]);
    console.log('Cleaned up test records successfully!');
    process.exit(0);
  } catch (err) {
    console.error('Test CRUD error:', err);
    process.exit(1);
  }
}

testCRUD();
