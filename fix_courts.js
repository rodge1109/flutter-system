const fs = require('fs');
const path = require('path');
const { Pool } = require('pg');
require('dotenv').config();

const indexPath = path.join(process.cwd(), 'index.js');
let code = fs.readFileSync(indexPath, 'utf-8');

// 1. Fix POST route
const postRegex = /app\.post\('\/api\/courts',\s*async\s*\(req,\s*res\)\s*=>\s*\{[\s\S]*?(?=\app\.get\('\/api\/courts\/owner-by-name')/g;
const newPost = `app.post('/api/courts', async (req, res) => {
  try {
    const { 
      name, ownerEmail, duration, description, 
      basePrice, hourlyPrices, address, facilities, courtNumber,
      latitude, longitude, openTime, closeTime,
      venue_name, venueName, venue,
      logoUrl, images, photos,
      dayDiscountRate, isDayDiscountActive,
      nightDiscountRate, isNightDiscountActive,
      bookingPolicy, aboutVenue, faq
    } = req.body;
    
    const finalVenueName = venue_name || venueName || venue || '';
    const finalImages = images || photos || [];

    const result = await pool.query(
      \`INSERT INTO pickle_courts 
        (name, owner_email, duration, description, active, base_price, hourly_prices, address, facilities, 
court_number, latitude, longitude, open_time, close_time, venue_name, logo_url, images, day_discount_rate, is_day_discount_active, 
night_discount_rate, is_night_discount_active, booking_policy, about_venue, faq) 
       VALUES ($1, $2, $3, $4, true, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20, $21, $22, $23) RETURNING *\`,
      [
        name, ownerEmail, duration || 30, description || '', 
        basePrice || 0, hourlyPrices ? JSON.stringify(hourlyPrices) : null, 
        address || '', facilities ? JSON.stringify(facilities) : '[]', courtNumber || null, latitude || null, longitude || null,
        openTime || '00:00', closeTime || '23:59',
        finalVenueName, logoUrl || null, JSON.stringify(finalImages),
        dayDiscountRate || 0, isDayDiscountActive || false,
        nightDiscountRate || 0, isNightDiscountActive || false,
        bookingPolicy || '', aboutVenue || '', faq || ''
      ]
    );
    res.status(201).json({ success: true, court: result.rows[0] });
  } catch (error) {
    console.error('Error adding court:', error);
    if (error.code === '23505') {
      return res.status(400).json({ success: false, message: 'A court with this Name and Court Number already exists.' });
    }
    res.status(500).json({ success: false, message: 'Failed to add court' });
  }
});

  `;
code = code.replace(postRegex, newPost);

// 2. Fix PUT route
const putRegex = /app\.put\('\/api\/courts\/:id',\s*async\s*\(req,\s*res\)\s*=>\s*\{[\s\S]*?(?=\app\.delete\('\/api\/courts\/:id')/g;
const newPut = `app.put('/api/courts/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { 
      name, duration, description, active, 
      basePrice, hourlyPrices, address, facilities, courtNumber,
      latitude, longitude, openTime, closeTime,
      venue_name, venueName, venue,
      logoUrl, images, photos,
      dayDiscountRate, isDayDiscountActive,
      nightDiscountRate, isNightDiscountActive,
      bookingPolicy, aboutVenue, faq
    } = req.body;

    const finalVenueName = venue_name || venueName || venue || '';
    const finalImages = images || photos || [];

    const result = await pool.query(
      \`UPDATE pickle_courts 
       SET name = $1, duration = $2, description = $3, active = $4, 
           base_price = $5, hourly_prices = $6, address = $7, facilities = $8, court_number = $9,
           latitude = $10, longitude = $11, open_time = $12, close_time = $13,
           venue_name = $14, logo_url = $15, images = $16, day_discount_rate = $17, is_day_discount_active = $18,
           night_discount_rate = $19, is_night_discount_active = $20, booking_policy = $21, about_venue = $22, faq = $23,
           updated_at = NOW() 
       WHERE id = $24 RETURNING *\`,
      [
        name, duration || 30, description || '', active !== undefined ? active : true, 
        basePrice || 0, hourlyPrices ? JSON.stringify(hourlyPrices) : null, 
        address || '', facilities ? JSON.stringify(facilities) : '[]', courtNumber || null, latitude || null, longitude || null,
        openTime || '00:00', closeTime || '23:59',
        finalVenueName, logoUrl || null, JSON.stringify(finalImages),
        dayDiscountRate || 0, isDayDiscountActive || false,
        nightDiscountRate || 0, isNightDiscountActive || false,
        bookingPolicy || '', aboutVenue || '', faq || '', id
      ]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Court not found' });
    }
    res.json({ success: true, court: result.rows[0] });
  } catch (error) {
    console.error('Error updating court:', error);
    if (error.code === '23505') {
      return res.status(400).json({ success: false, message: 'A court with this Name and Court Number already exists.' });
    }
    res.status(500).json({ success: false, message: 'Failed to update court' });
  }
});

`;
code = code.replace(putRegex, newPut);

fs.writeFileSync(indexPath, code, 'utf-8');
console.log('Successfully updated index.js');

const dbConfig = {
  connectionString: process.env.DATABASE_URL || 'postgresql://postgres:postgres@localhost:5432/postgres' // fallback
};
const pool = new Pool(dbConfig);

async function alterTable() {
  try {
    await pool.query('ALTER TABLE pickle_courts ADD COLUMN IF NOT EXISTS venue_name TEXT');
    console.log('Added venue_name column');
    await pool.query("ALTER TABLE pickle_courts ADD COLUMN IF NOT EXISTS images JSONB DEFAULT '[]'::jsonb");
    console.log('Added images column');
    await pool.query('ALTER TABLE pickle_courts ADD COLUMN IF NOT EXISTS logo_url TEXT');
    await pool.query('ALTER TABLE pickle_courts ADD COLUMN IF NOT EXISTS day_discount_rate NUMERIC');
    await pool.query('ALTER TABLE pickle_courts ADD COLUMN IF NOT EXISTS is_day_discount_active BOOLEAN DEFAULT false');
    await pool.query('ALTER TABLE pickle_courts ADD COLUMN IF NOT EXISTS night_discount_rate NUMERIC');
    await pool.query('ALTER TABLE pickle_courts ADD COLUMN IF NOT EXISTS is_night_discount_active BOOLEAN DEFAULT false');
    await pool.query('ALTER TABLE pickle_courts ADD COLUMN IF NOT EXISTS booking_policy TEXT');
    await pool.query('ALTER TABLE pickle_courts ADD COLUMN IF NOT EXISTS about_venue TEXT');
    await pool.query('ALTER TABLE pickle_courts ADD COLUMN IF NOT EXISTS faq TEXT');
    console.log('Ensured all columns exist');
  } catch(e) {
    console.error('Error altering table:', e);
  } finally {
    pool.end();
  }
}
alterTable();
