/**
 * MEMBER LOYALTY & CUSTOMER MANAGEMENT BACKEND MODULE
 * Copy and paste these endpoints into your Express server (index.js / routes).
 */

/* ==========================================================================
   SQL DATABASE MIGRATION (PostgreSQL / MySQL)
   ==========================================================================

-- 1. Customers Directory Table
CREATE TABLE IF NOT EXISTS pickle_customer (
    id SERIAL PRIMARY KEY,
    owner_email VARCHAR(255) NOT NULL,
    full_name VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL,
    phone VARCHAR(50),
    is_member BOOLEAN DEFAULT TRUE,
    loyalty_points INT DEFAULT 0,
    stamp_count INT DEFAULT 0,
    total_completed_bookings INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT unique_customer_per_owner UNIQUE (owner_email, email)
);

-- 2. Loyalty & Member Price Settings Table
CREATE TABLE IF NOT EXISTS pickle_loyalty_settings (
    id SERIAL PRIMARY KEY,
    owner_email VARCHAR(255) UNIQUE NOT NULL,
    member_discount_type VARCHAR(50) DEFAULT 'PERCENTAGE', -- 'PERCENTAGE', 'FIXED_PRICE', 'DISCOUNT_AMOUNT'
    member_discount_value NUMERIC(10, 2) DEFAULT 15.00,
    milestone_target INT DEFAULT 10,
    free_reward_enabled BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 3. Loyalty Audit Logs Table
CREATE TABLE IF NOT EXISTS pickle_loyalty_logs (
    id SERIAL PRIMARY KEY,
    customer_id INT REFERENCES pickle_customer(id) ON DELETE CASCADE,
    booking_id INT,
    action VARCHAR(50) NOT NULL, -- 'STAMP_EARNED', 'FREE_BOOKING_REDEEMED', 'POINTS_RESET'
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
*/

// ==========================================================================
// EXPRESS.JS BACKEND API ENDPOINTS
// ==========================================================================

// 1. Fetch Owner's Registered Customers & Loyalty Status
app.get('/api/owner/customers', async (req, res) => {
  try {
    const { owner_email } = req.query;
    if (!owner_email) {
      return res.status(400).json({ success: false, message: 'owner_email is required' });
    }
    const result = await db.query(
      `SELECT * FROM pickle_customer WHERE owner_email = $1 ORDER BY created_at DESC`,
      [owner_email]
    );
    res.json({ success: true, customers: result.rows || result });
  } catch (error) {
    console.error('Error fetching customers:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

// 2. Add or Update Customer Record (Full Name, Email, VIP Member status)
app.post('/api/owner/customers', async (req, res) => {
  try {
    const { owner_email, full_name, email, phone, is_member } = req.body;
    if (!owner_email || !full_name || !email) {
      return res.status(400).json({ success: false, message: 'Missing required fields' });
    }

    const query = `
      INSERT INTO pickle_customer (owner_email, full_name, email, phone, is_member, updated_at)
      VALUES ($1, $2, $3, $4, $5, NOW())
      ON CONFLICT (owner_email, email) DO UPDATE SET
        full_name = EXCLUDED.full_name,
        phone = EXCLUDED.phone,
        is_member = EXCLUDED.is_member,
        updated_at = NOW()
      RETURNING *;
    `;
    const result = await db.query(query, [owner_email, full_name, email, phone || null, is_member !== false]);
    res.json({ success: true, customer: result.rows ? result.rows[0] : result[0] });
  } catch (error) {
    console.error('Error saving customer:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

// 3. Delete Customer
app.delete('/api/owner/customers/:id', async (req, res) => {
  try {
    const { id } = req.params;
    await db.query(`DELETE FROM pickle_customer WHERE id = $1`, [id]);
    res.json({ success: true, message: 'Customer removed successfully' });
  } catch (error) {
    console.error('Error deleting customer:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

// 4. Fetch Owner Loyalty & Member Price Settings
app.get('/api/owner/loyalty-settings', async (req, res) => {
  try {
    const { owner_email } = req.query;
    if (!owner_email) {
      return res.status(400).json({ success: false, message: 'owner_email is required' });
    }
    const result = await db.query(
      `SELECT * FROM pickle_loyalty_settings WHERE owner_email = $1`,
      [owner_email]
    );
    const settings = (result.rows && result.rows[0]) ? result.rows[0] : {
      owner_email,
      member_discount_type: 'PERCENTAGE',
      member_discount_value: 15.00,
      milestone_target: 10,
      free_reward_enabled: true,
    };
    res.json({ success: true, settings });
  } catch (error) {
    console.error('Error fetching loyalty settings:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

// 5. Save/Update Loyalty Settings
app.post('/api/owner/loyalty-settings', async (req, res) => {
  try {
    const { owner_email, member_discount_type, member_discount_value, milestone_target, free_reward_enabled } = req.body;
    if (!owner_email) {
      return res.status(400).json({ success: false, message: 'owner_email is required' });
    }

    const query = `
      INSERT INTO pickle_loyalty_settings 
        (owner_email, member_discount_type, member_discount_value, milestone_target, free_reward_enabled)
      VALUES ($1, $2, $3, $4, $5)
      ON CONFLICT (owner_email) DO UPDATE SET
        member_discount_type = EXCLUDED.member_discount_type,
        member_discount_value = EXCLUDED.member_discount_value,
        milestone_target = EXCLUDED.milestone_target,
        free_reward_enabled = EXCLUDED.free_reward_enabled
      RETURNING *;
    `;
    const result = await db.query(query, [
      owner_email,
      member_discount_type || 'PERCENTAGE',
      member_discount_value || 15.00,
      milestone_target || 10,
      free_reward_enabled !== false,
    ]);
    res.json({ success: true, settings: result.rows ? result.rows[0] : result[0] });
  } catch (error) {
    console.error('Error saving loyalty settings:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

// 6. Fetch Customer Loyalty Status for Court Booking Checkout
app.get('/api/customer/loyalty-status', async (req, res) => {
  try {
    const { email, owner_email } = req.query;
    if (!email || !owner_email) {
      return res.status(400).json({ success: false, message: 'email and owner_email required' });
    }
    const result = await db.query(
      `SELECT * FROM pickle_customer WHERE email = $1 AND owner_email = $2`,
      [email, owner_email]
    );
    if (result.rows && result.rows.length > 0) {
      res.json({ success: true, customer: result.rows[0] });
    } else {
      res.json({ success: true, customer: null });
    }
  } catch (error) {
    console.error('Error fetching loyalty status:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});
