const fs = require('fs');
const path = require('path');

const targetFile = 'C:/website/pickle-system/server/index.js';
let code = fs.readFileSync(targetFile, 'utf8');

if (code.includes('/api/ledger/owners')) {
  console.log('Ledger routes already present in index.js');
  process.exit(0);
}

const marker = '// ==================== FORGOT PASSWORD ====================';
if (!code.includes(marker)) {
  console.error('Could not find marker in index.js');
  process.exit(1);
}

const ledgerRoutesCode = `// ==================== COURT OWNER LEDGER ====================
// Get summary of all owners and their current ledger balances
app.get('/api/ledger/owners', async (req, res) => {
  try {
    const query = \`
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
    \`;
    const { rows } = await pool.query(query);
    res.json({ success: true, owners: rows });
  } catch (error) {
    console.error('Error fetching ledger owners:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

// Get ledger transactions for a specific court owner
app.get('/api/ledger/:ownerEmail', async (req, res) => {
  try {
    const ownerEmail = req.params.ownerEmail;
    if (!ownerEmail) {
      return res.status(400).json({ success: false, message: 'Owner email is required' });
    }

    const { startDate, endDate, search } = req.query;
    let query = \`
      SELECT 
        id,
        owner_email,
        venue_name,
        TO_CHAR(transaction_date, 'YYYY-MM-DD') as transaction_date,
        particulars,
        type,
        amount::numeric(12,2) as amount,
        reference_number,
        notes,
        created_by,
        created_at,
        updated_at
      FROM court_owner_ledger
      WHERE LOWER(TRIM(owner_email)) = LOWER(TRIM($1))
    \`;
    const params = [ownerEmail];

    if (startDate && endDate) {
      params.push(startDate, endDate);
      query += \` AND transaction_date >= $\${params.length - 1} AND transaction_date <= $\${params.length}\`;
    }

    if (search && search.trim() !== '') {
      params.push(\`%\${search.trim().toLowerCase()}%\`);
      query += \` AND (LOWER(particulars) LIKE $\${params.length} OR LOWER(COALESCE(reference_number, '')) LIKE $\${params.length})\`;
    }

    query += \` ORDER BY transaction_date ASC, id ASC\`;

    const { rows } = await pool.query(query, params);

    // Compute running balance chronologically
    let runningBalance = 0.0;
    let totalCharges = 0.0;
    let totalPayments = 0.0;

    const entries = rows.map(row => {
      const amt = parseFloat(row.amount) || 0.0;
      const isCharge = (row.type || '').toLowerCase() === 'charge';
      const charges = isCharge ? amt : 0.0;
      const payment = !isCharge ? amt : 0.0;

      totalCharges += charges;
      totalPayments += payment;
      runningBalance += (charges - payment);

      return {
        ...row,
        charges: parseFloat(charges.toFixed(2)),
        payment: parseFloat(payment.toFixed(2)),
        running_balance: parseFloat(runningBalance.toFixed(2))
      };
    });

    res.json({
      success: true,
      owner_email: ownerEmail,
      total_charges: parseFloat(totalCharges.toFixed(2)),
      total_payments: parseFloat(totalPayments.toFixed(2)),
      current_balance: parseFloat(runningBalance.toFixed(2)),
      entries
    });
  } catch (error) {
    console.error('Error fetching owner ledger:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

// Create manual ledger transaction (Super Admin)
app.post('/api/ledger', async (req, res) => {
  try {
    const {
      owner_email,
      venue_name,
      transaction_date,
      particulars,
      type,
      amount,
      reference_number,
      notes,
      created_by
    } = req.body;

    if (!owner_email || !particulars || !type || amount === undefined || amount === null) {
      return res.status(400).json({
        success: false,
        message: 'owner_email, particulars, type, and amount are required'
      });
    }

    const cleanType = type.toLowerCase() === 'payment' ? 'payment' : 'charge';
    const parsedAmount = Math.abs(parseFloat(amount) || 0.0);
    const dateVal = transaction_date || new Date().toISOString().split('T')[0];

    const insertQuery = \`
      INSERT INTO court_owner_ledger (
        owner_email,
        venue_name,
        transaction_date,
        particulars,
        type,
        amount,
        reference_number,
        notes,
        created_by
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
      RETURNING 
        id,
        owner_email,
        venue_name,
        TO_CHAR(transaction_date, 'YYYY-MM-DD') as transaction_date,
        particulars,
        type,
        amount::numeric(12,2) as amount,
        reference_number,
        notes,
        created_by,
        created_at,
        updated_at;
    \`;

    const { rows } = await pool.query(insertQuery, [
      owner_email.trim(),
      venue_name || null,
      dateVal,
      particulars.trim(),
      cleanType,
      parsedAmount,
      reference_number || null,
      notes || null,
      created_by || 'Super Admin'
    ]);

    res.status(201).json({
      success: true,
      message: 'Ledger transaction added successfully',
      entry: rows[0]
    });
  } catch (error) {
    console.error('Error creating ledger entry:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

// Update ledger transaction (Super Admin)
app.put('/api/ledger/:id', async (req, res) => {
  try {
    const id = parseInt(req.params.id, 10);
    if (!id) {
      return res.status(400).json({ success: false, message: 'Valid entry ID required' });
    }

    const {
      owner_email,
      venue_name,
      transaction_date,
      particulars,
      type,
      amount,
      reference_number,
      notes
    } = req.body;

    const cleanType = type && type.toLowerCase() === 'payment' ? 'payment' : 'charge';
    const parsedAmount = Math.abs(parseFloat(amount) || 0.0);

    const updateQuery = \`
      UPDATE court_owner_ledger
      SET 
        owner_email = COALESCE(NULLIF($1, ''), owner_email),
        venue_name = COALESCE($2, venue_name),
        transaction_date = COALESCE($3, transaction_date),
        particulars = COALESCE(NULLIF($4, ''), particulars),
        type = $5,
        amount = $6,
        reference_number = $7,
        notes = $8,
        updated_at = NOW()
      WHERE id = $9
      RETURNING 
        id,
        owner_email,
        venue_name,
        TO_CHAR(transaction_date, 'YYYY-MM-DD') as transaction_date,
        particulars,
        type,
        amount::numeric(12,2) as amount,
        reference_number,
        notes,
        created_by,
        created_at,
        updated_at;
    \`;

    const { rows } = await pool.query(updateQuery, [
      owner_email ? owner_email.trim() : '',
      venue_name || null,
      transaction_date || null,
      particulars ? particulars.trim() : '',
      cleanType,
      parsedAmount,
      reference_number || null,
      notes || null,
      id
    ]);

    if (rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Ledger entry not found' });
    }

    res.json({
      success: true,
      message: 'Ledger transaction updated successfully',
      entry: rows[0]
    });
  } catch (error) {
    console.error('Error updating ledger entry:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

// Delete ledger transaction (Super Admin)
app.delete('/api/ledger/:id', async (req, res) => {
  try {
    const id = parseInt(req.params.id, 10);
    if (!id) {
      return res.status(400).json({ success: false, message: 'Valid entry ID required' });
    }

    const { rowCount } = await pool.query('DELETE FROM court_owner_ledger WHERE id = $1', [id]);
    if (rowCount === 0) {
      return res.status(404).json({ success: false, message: 'Ledger entry not found' });
    }

    res.json({
      success: true,
      message: 'Ledger entry deleted successfully'
    });
  } catch (error) {
    console.error('Error deleting ledger entry:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

` + marker;

code = code.replace(marker, ledgerRoutesCode);
fs.writeFileSync(targetFile, code, 'utf8');
console.log('Successfully injected ledger routes into index.js');
