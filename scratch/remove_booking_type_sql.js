const fs = require('fs');

const path = 'C:/website/pickle-system/server/index.js';
let content = fs.readFileSync(path, 'utf8');

if (content.includes('a.booking_type,')) {
  content = content.replace('a.booking_type,', '');
  fs.writeFileSync(path, content, 'utf8');
  console.log('SUCCESS: Removed a.booking_type from /api/admin/all-bookings query!');
} else {
  console.log('a.booking_type already removed.');
}
