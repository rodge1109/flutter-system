const fs = require('fs');

const path = 'C:/website/pickle-system/server/index.js';
let content = fs.readFileSync(path, 'utf8');

content = content.replace(
  'SELECT a.id, a.full_name as player_name, a.proof_of_payment, a.agent_code, a.booking_type,',
  'SELECT a.id, a.full_name as player_name, a.proof_of_payment, a.agent_code,'
);

fs.writeFileSync(path, content, 'utf8');
console.log('SUCCESS: Removed invalid column a.booking_type from backend index.js!');
