const fs = require('fs');

const path = 'C:/website/pickle-system/server/index.js';
let content = fs.readFileSync(path, 'utf8');

const catchAllIndex = content.indexOf("app.get('*'");
const adminRouteIndex = content.indexOf("/api/admin/all-bookings");

console.log('catchAllIndex (app.get(*)):', catchAllIndex);
console.log('adminRouteIndex (/api/admin/all-bookings):', adminRouteIndex);

if (catchAllIndex !== -1 && adminRouteIndex > catchAllIndex) {
  console.log('FOUND ISSUE: /api/admin/all-bookings was appended AFTER app.get(*)! Fixing placement...');

  // Extract the admin route block from bottom of file
  const blockStart = content.indexOf("// ==================== SUPER ADMIN ALL BOOKINGS ROUTE ====================");
  let adminBlock = '';
  if (blockStart !== -1) {
    adminBlock = content.substring(blockStart);
    content = content.substring(0, blockStart);
  }

  // Insert adminBlock BEFORE app.get('*'
  content = content.substring(0, catchAllIndex) + adminBlock + '\n\n' + content.substring(catchAllIndex);

  fs.writeFileSync(path, content, 'utf8');
  console.log('SUCCESS: Moved /api/admin/all-bookings BEFORE app.get(*) catch-all route!');
} else {
  console.log('Placement check complete.');
}
