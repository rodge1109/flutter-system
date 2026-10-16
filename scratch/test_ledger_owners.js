const pool = require('../../pickle-system/server/db.js');

async function testOwners() {
  const query = `
    WITH ledger_totals AS (
      SELECT 
        LOWER(TRIM(owner_email)) as owner_email_key,
        COALESCE(SUM(CASE WHEN LOWER(type) = 'charge' THEN amount ELSE 0 END), 0) as total_charges,
        COALESCE(SUM(CASE WHEN LOWER(type) = 'payment' THEN amount ELSE 0 END), 0) as total_payments,
        COUNT(*) as total_entries,
        MAX(transaction_date) as last_transaction_date
      FROM court_owner_ledger
      GROUP BY LOWER(TRIM(owner_email))
    ),
    courts_owners AS (
      SELECT 
        LOWER(TRIM(c.owner_email)) as owner_email_key,
        TRIM(c.owner_email) as owner_email,
        MAX(COALESCE(c.venue_name, c.name, '')) as venue_name,
        MAX(COALESCE(u.full_name, '')) as owner_name
      FROM pickle_courts c
      LEFT JOIN users u ON LOWER(TRIM(c.owner_email)) = LOWER(TRIM(u.email))
      WHERE c.owner_email IS NOT NULL AND TRIM(c.owner_email) != ''
      GROUP BY LOWER(TRIM(c.owner_email)), TRIM(c.owner_email)
    )
    SELECT 
      COALESCE(co.owner_email, lt.owner_email_key) as owner_email,
      COALESCE(NULLIF(co.owner_name, ''), 'Court Owner') as owner_name,
      COALESCE(co.venue_name, 'Pickleball Court') as venue_name,
      COALESCE(lt.total_charges, 0)::numeric(12,2) as total_charges,
      COALESCE(lt.total_payments, 0)::numeric(12,2) as total_payments,
      (COALESCE(lt.total_charges, 0) - COALESCE(lt.total_payments, 0))::numeric(12,2) as current_balance,
      COALESCE(lt.total_entries, 0)::int as total_entries,
      lt.last_transaction_date
    FROM courts_owners co
    FULL OUTER JOIN ledger_totals lt ON co.owner_email_key = lt.owner_email_key
    ORDER BY venue_name ASC, owner_email ASC;
  `;
  const res = await pool.query(query);
  console.log('Found owners:', res.rows);
  process.exit(0);
}

testOwners();
