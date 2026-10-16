const fs = require('fs');
const targetFile = 'C:/website/pickle-system/server/index.js';
let code = fs.readFileSync(targetFile, 'utf8');

const regex = /app\.get\('\/api\/ledger\/:ownerEmail'[\s\S]*?app\.post\('\/api\/ledger'/;

const replacement = `app.get('/api/ledger/:ownerEmail', async (req, res) => {
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
      const p1 = params.length - 1;
      const p2 = params.length;
      query += " AND transaction_date >= $" + p1 + " AND transaction_date <= $" + p2;
    }

    if (search && search.trim() !== '') {
      params.push('%' + search.trim().toLowerCase() + '%');
      const p = params.length;
      query += " AND (LOWER(particulars) LIKE $" + p + " OR LOWER(COALESCE(reference_number, '')) LIKE $" + p + ")";
    }

    query += " ORDER BY transaction_date ASC, id ASC";

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
app.post('/api/ledger'`;

code = code.replace(regex, replacement);
fs.writeFileSync(targetFile, code, 'utf8');
console.log('Fixed GET /api/ledger/:ownerEmail in index.js');
