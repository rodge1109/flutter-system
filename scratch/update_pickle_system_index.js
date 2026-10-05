const fs = require('fs');

const filePath = 'C:/website/pickle-system/server/index.js';
let content = fs.readFileSync(filePath, 'utf8');

// 1. Fix auto-register customer on booking: change is_member from true to false
const target1 = `VALUES ($1, $2, LOWER($3), $4, true, 1, 1, CURRENT_TIMESTAMP)`;
const replacement1 = `VALUES ($1, $2, LOWER($3), $4, false, 1, 1, CURRENT_TIMESTAMP)`;

// 2. Fix POST /api/owner/customers: change is_member !== false to is_member === true || is_member === 'true'
const target2 = `[owner_email.trim(), full_name.trim(), email.trim().toLowerCase(), phone ? phone.trim() : null, is_member !== false]`;
const replacement2 = `[owner_email.trim(), full_name.trim(), email.trim().toLowerCase(), phone ? phone.trim() : null, is_member === true || is_member === 'true']`;

let count = 0;
if (content.includes(target1)) {
  content = content.replace(target1, replacement1);
  console.log('Successfully replaced target 1 (booking auto-customer creation is_member default to false)');
  count++;
} else {
  console.error('Target 1 not found!');
}

if (content.includes(target2)) {
  content = content.replace(target2, replacement2);
  console.log('Successfully replaced target 2 (POST customer endpoint is_member default to false)');
  count++;
} else {
  console.error('Target 2 not found!');
}

if (count > 0) {
  fs.writeFileSync(filePath, content, 'utf8');
  console.log('Updated server/index.js in pickle-system successfully!');
}
