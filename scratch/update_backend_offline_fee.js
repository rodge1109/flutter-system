const fs = require('fs');
const path = 'C:/website/pickle-system/server/index.js';
let content = fs.readFileSync(path, 'utf8');

const startStr = "app.get('/api/owner-earnings/:email'";
const startIdx = content.indexOf(startStr);

if (startIdx === -1) {
  console.error("Route start not found!");
  process.exit(1);
}

const nextRouteIdx = content.indexOf("\n// ==================== FORGOT PASSWORD ====================", startIdx);
if (nextRouteIdx === -1) {
  console.error("End marker not found!");
  process.exit(1);
}

const fullOld = content.substring(startIdx, nextRouteIdx);

const fullNew = `app.get('/api/owner-earnings/:email', async (req, res) => {
  try {
    const ownerEmail = req.params.email;
    
    // Fetch all bookings for courts owned by this owner (including offline blocks)
    const { startDate, endDate } = req.query;
    let query = \`
      SELECT a.id, a.full_name as player_name, a.proof_of_payment, a.agent_code, a.booking_type,
        a.preferred_date, 
        a.preferred_time, 
        a.total_amount, 
        a.status,
        a.payment_method,
        a.is_open_play,
        a.created_at,
        c.name as court_name
      FROM pickle_appointment a
      JOIN pickle_courts c ON a.service_type = c.name
      WHERE c.owner_email = $1 
        AND a.status != 'cancelled'
    \`;
    
    const params = [ownerEmail];
    
    if (startDate && endDate) {
      query += \` AND DATE(a.created_at) >= $2 AND DATE(a.created_at) <= $3\`;
      params.push(startDate, endDate);
    }
    
    query += \` ORDER BY a.created_at DESC\`;
    
    const { rows } = await pool.query(query, params);
    
    // Calculate totals: P15 fixed service charge per booking session; offline bookings have 0 gross and 0 net
    let grossEarnings = 0;
    let totalServiceFee = 0;
    let totalNetEarnings = 0;
    
    const transactions = rows.map(row => {
      const bType = (row.booking_type || '').toLowerCase();
      const status = (row.status || '').toLowerCase();
      const pName = (row.player_name || '').toLowerCase();
      const pMethod = (row.payment_method || '').toLowerCase();

      const isOfflineBlock = status === 'blocked' ||
        status.includes('block') ||
        status.includes('maintenance') ||
        bType === 'owner_block' ||
        bType.includes('offline') ||
        bType.includes('block') ||
        bType.includes('maintenance') ||
        bType.includes('walk') ||
        pName.includes('offline') ||
        pName.includes('maintenance') ||
        pName.includes('block') ||
        pMethod === 'cash' ||
        pMethod === 'offline';

      const courtAmount = parseFloat(row.total_amount) || 0;
      const serviceFee = 15.0; // P15 service charge per booking session
      const gross = isOfflineBlock ? 0.0 : (courtAmount + serviceFee);
      const netEarnings = isOfflineBlock ? 0.0 : courtAmount;

      grossEarnings += gross;
      totalServiceFee += serviceFee;
      totalNetEarnings += netEarnings;
      
      return {
        ...row,
        amount: isOfflineBlock ? 0.0 : courtAmount,
        gross: gross,
        gross_amount: gross,
        grossAmount: gross,
        serviceFee: serviceFee,
        service_fee: serviceFee,
        netEarnings: netEarnings,
        net_amount: netEarnings,
        court_net: netEarnings,
        is_offline: isOfflineBlock
      };
    });
    
    res.json({
      success: true,
      grossEarnings,
      totalServiceFee,
      totalNetEarnings,
      transactions
    });
  } catch (error) {
    console.error('Error fetching owner earnings:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});`;

content = content.replace(fullOld, fullNew);
fs.writeFileSync(path, content, 'utf8');
console.log("SUCCESS: Replaced owner-earnings route in C:/website/pickle-system/server/index.js!");
