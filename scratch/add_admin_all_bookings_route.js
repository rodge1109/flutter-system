const fs = require('fs');

const path = 'C:/website/pickle-system/server/index.js';
if (fs.existsSync(path)) {
  let content = fs.readFileSync(path, 'utf8');

  if (!content.includes('/api/admin/all-bookings')) {
    console.log('Adding /api/admin/all-bookings route to backend index.js...');

    const newRoute = `
// ==================== SUPER ADMIN ALL BOOKINGS ROUTE ====================
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

    content += newRoute;
    fs.writeFileSync(path, content, 'utf8');
    console.log('SUCCESSFULLY ADDED /api/admin/all-bookings ROUTE TO BACKEND index.js!');
  } else {
    console.log('Route /api/admin/all-bookings already exists in backend index.js!');
  }
} else {
  console.log('Backend index.js not found at path:', path);
}
