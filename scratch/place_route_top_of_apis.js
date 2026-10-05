const fs = require('fs');

const path = 'C:/website/pickle-system/server/index.js';
let content = fs.readFileSync(path, 'utf8');

// Remove existing admin all-bookings block if present
const blockTitle = "// ==================== SUPER ADMIN ALL BOOKINGS ROUTE ====================";
if (content.includes(blockTitle)) {
  const parts = content.split(blockTitle);
  // Remove block from wherever it was
  const afterTitle = parts[1];
  const endBlock = afterTitle.indexOf("});");
  content = parts[0] + afterTitle.substring(endBlock + 3);
}

// Find a clean target line near top API routes, e.g. right after app.get('/api/services'
const target = "app.get('/api/services',";
const targetIdx = content.indexOf(target);

if (targetIdx !== -1) {
  const adminRoute = `
${blockTitle}
app.get('/api/admin/all-bookings', async (req, res) => {
  try {
    const result = await pool.query(\`
      SELECT 
        a.id, 
        a.full_name as player_name,
        a.full_name,
        a.phone_number,
        a.email as user_email,
        a.service_type,
        a.service_type as court_name,
        a.preferred_date, 
        a.preferred_date as appointment_date,
        a.preferred_time, 
        a.preferred_time as appointment_time,
        a.total_amount, 
        a.status,
        a.payment_method,
        a.is_open_play,
        a.created_at,
        a.proof_of_payment,
        a.agent_code,
        a.booking_type,
        c.name as court_name,
        c.owner_email
      FROM pickle_appointment a
      LEFT JOIN pickle_courts c ON a.service_type = c.name
      WHERE a.status != 'cancelled' AND a.status != 'blocked'
      ORDER BY a.id DESC;
    \`);
    res.json({ success: true, bookings: result.rows });
  } catch (err) {
    console.error('Error fetching admin all-bookings:', err);
    res.status(500).json({ success: false, message: err.message });
  }
});
`;

  content = content.substring(0, targetIdx) + adminRoute + '\n\n' + content.substring(targetIdx);
  fs.writeFileSync(path, content, 'utf8');
  console.log('SUCCESS: Placed /api/admin/all-bookings near top API routes (before express.static)!');
} else {
  console.error('ERROR: Target line not found!');
}
