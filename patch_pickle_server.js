const fs = require('fs');
const filePath = 'c:/website/pickle-system/server/index.js';
let code = fs.readFileSync(filePath, 'utf8');

// 1. Add migration
const migrationTarget = "pool.query('ALTER TABLE pickle_courts ADD COLUMN IF NOT EXISTS faq TEXT').catch(() => {});";
const migrationRepl = migrationTarget + "\npool.query('ALTER TABLE pickle_courts ADD COLUMN IF NOT EXISTS is_verified BOOLEAN DEFAULT false').catch(() => {});";
if (!code.includes('is_verified BOOLEAN DEFAULT false')) {
  code = code.replace(migrationTarget, migrationRepl);
}

// 2. Add is_verified to mappedCourts in /api/booking-services
const mapTarget = "about_venue: c.about_venue || '',";
const mapRepl = "is_verified: c.is_verified === true || c.is_verified === 'true' || c.is_verified === 1,\n        isVerified: c.is_verified === true || c.is_verified === 'true' || c.is_verified === 1,\n        about_venue: c.about_venue || '',";
if (!code.includes('is_verified: c.is_verified === true')) {
  code = code.replace(mapTarget, mapRepl);
}

// 3. Add toggle endpoints before MESSAGING section
const messagingTarget = "// ==================== MESSAGING ====================";
const endpointsToAdd = `// Toggle court/venue verified status (Superadmin)
app.post('/api/admin/courts/toggle-verified', async (req, res) => {
  try {
    const { courtId, venueName, isVerified } = req.body;
    const verifiedVal = isVerified === true || isVerified === 'true' || isVerified === 1;
    let query = '';
    let values = [];
    if (courtId !== undefined && courtId !== null && courtId !== '') {
      query = 'UPDATE pickle_courts SET is_verified = $1 WHERE id = $2 RETURNING *';
      values = [verifiedVal, courtId];
    } else if (venueName) {
      query = 'UPDATE pickle_courts SET is_verified = $1 WHERE LOWER(TRIM(venue_name)) = LOWER(TRIM($2)) OR LOWER(TRIM(name)) = LOWER(TRIM($2)) RETURNING *';
      values = [verifiedVal, venueName];
    }
    if (query) {
      const { rows } = await pool.query(query, values);
      return res.json({ success: true, isVerified: verifiedVal, rowsUpdated: rows.length });
    }
    res.status(400).json({ success: false, message: 'Missing courtId or venueName' });
  } catch (err) {
    console.error('Error toggling court verification:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

// Toggle court active status (Superadmin)
app.post('/api/admin/courts/toggle-active', async (req, res) => {
  try {
    const { courtId, venueName, isActive } = req.body;
    const activeVal = isActive === true || isActive === 'true' || isActive === 1;
    let query = '';
    let values = [];
    if (courtId !== undefined && courtId !== null && courtId !== '') {
      query = 'UPDATE pickle_courts SET active = $1 WHERE id = $2 RETURNING *';
      values = [activeVal, courtId];
    } else if (venueName) {
      query = 'UPDATE pickle_courts SET active = $1 WHERE LOWER(TRIM(venue_name)) = LOWER(TRIM($2)) OR LOWER(TRIM(name)) = LOWER(TRIM($2)) RETURNING *';
      values = [activeVal, venueName];
    }
    if (query) {
      const { rows } = await pool.query(query, values);
      return res.json({ success: true, isActive: activeVal, rowsUpdated: rows.length });
    }
    res.status(400).json({ success: false, message: 'Missing courtId or venueName' });
  } catch (err) {
    console.error('Error toggling court active:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

`;

if (!code.includes('/api/admin/courts/toggle-verified')) {
  code = code.replace(messagingTarget, endpointsToAdd + messagingTarget);
}

fs.writeFileSync(filePath, code, 'utf8');
console.log('Successfully patched index.js cleanly!');
