const fs = require('fs');

const path = 'C:/website/pickle-system/server/index.js';
let raw = fs.readFileSync(path, 'utf8');
const isCrlf = raw.includes('\r\n');
let content = raw.replace(/\r\n/g, '\n');

// 1. Update mappedCourts in GET /api/booking-services to include court_number, base_price, hourly_prices, etc.
const targetMap = `        name: c.name,
        venue_name: c.venue_name || null,`;

const replaceMap = `        name: c.name,
        court_number: c.court_number || null,
        courtNumber: c.court_number || null,
        venue_name: c.venue_name || null,`;

if (content.includes(targetMap)) {
  content = content.replace(targetMap, replaceMap);
  console.log('SUCCESS: Added court_number and courtNumber to GET /api/booking-services mappedCourts');
} else {
  console.error('ERROR: targetMap not found!');
}

const targetPrice = `        description: c.description || '',
        price: c.base_price ? \`PHP \${parseFloat(c.base_price).toFixed(0)}\` : 'PHP 300',`;

const replacePrice = `        description: c.description || '',
        price: c.base_price ? \`PHP \${parseFloat(c.base_price).toFixed(0)}\` : 'PHP 300',
        base_price: c.base_price ? parseFloat(c.base_price).toFixed(0) : '300',
        basePrice: c.base_price ? parseFloat(c.base_price).toFixed(0) : '300',
        hourly_prices: c.hourly_prices,
        hourlyPrices: c.hourly_prices,
        images: c.images || [],
        photos: c.images || [],
        day_discount_rate: c.day_discount_rate,
        is_day_discount_active: c.is_day_discount_active,
        night_discount_rate: c.night_discount_rate,
        is_night_discount_active: c.is_night_discount_active,`;

if (content.includes(targetPrice)) {
  content = content.replace(targetPrice, replacePrice);
  console.log('SUCCESS: Added base_price and discount fields to GET /api/booking-services mappedCourts');
} else {
  console.error('ERROR: targetPrice not found!');
}

// 2. Fix POST /api/courts and PUT /api/courts/:id finalOpenTime and finalCloseTime
const targetPostVars = `    const finalVenueName = venue_name || venueName || venue || '';
    const finalImages = images || photos || [];`;

const replacePostVars = `    const finalOpenTime = openTime || req.body.open_time || '00:00';
    const finalCloseTime = closeTime || req.body.close_time || '23:59';
    const finalCourtNumber = courtNumber || req.body.court_number || null;
    const finalVenueName = venue_name || venueName || venue || '';
    const finalImages = images || photos || [];`;

content = content.replaceAll(targetPostVars, replacePostVars);
console.log('SUCCESS: Injected finalOpenTime, finalCloseTime, finalCourtNumber into routes (POST / PUT courts)');

// 3. In POST /api/courts query parameters, ensure courtNumber uses finalCourtNumber
content = content.replace(
  `address || '', facilities !== undefined ? (typeof facilities === 'string' ? facilities : JSON.stringify(facilities)) : '[]', courtNumber || null, latitude || null, longitude || null,`,
  `address || '', facilities !== undefined ? (typeof facilities === 'string' ? facilities : JSON.stringify(facilities)) : '[]', finalCourtNumber, latitude || null, longitude || null,`
);

// 4. In PUT /api/courts/:id query parameters, ensure courtNumber uses finalCourtNumber
content = content.replace(
  `address || '', (facilities !== undefined && facilities !== null) ? (typeof facilities === 'string' ? facilities : JSON.stringify(facilities)) : '[]', courtNumber || null, latitude || null, longitude || null,`,
  `address || '', (facilities !== undefined && facilities !== null) ? (typeof facilities === 'string' ? facilities : JSON.stringify(facilities)) : '[]', finalCourtNumber, latitude || null, longitude || null,`
);

if (isCrlf) {
  content = content.replace(/\n/g, '\r\n');
}

fs.writeFileSync(path, content, 'utf8');
console.log('Finished writing updated server/index.js');
