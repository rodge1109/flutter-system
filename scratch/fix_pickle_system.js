const fs = require('fs');

const filePath = 'C:/website/pickle-system/server/index.js';
let content = fs.readFileSync(filePath, 'utf8');

const target = '[owner_email.trim(), member_discount_type || \'PERCENTAGE\', member_discount_value || 15.0, milestone_target || 10, free_reward_enabled !== false]';
const replacement = '[owner_email.trim(), member_discount_type || \'PERCENTAGE\', (member_discount_value !== undefined && member_discount_value !== null) ? member_discount_value : 0.0, milestone_target || 10, free_reward_enabled !== false]';

if (content.includes(target)) {
  content = content.replace(target, replacement);
  fs.writeFileSync(filePath, content, 'utf8');
  console.log('SUCCESSFULLY FIXED server/index.js in pickle-system!');
} else {
  console.error('Target line not found in file');
}
