const fs = require('fs');

const path = 'C:/website/pickle-system/server/index.js';
let content = fs.readFileSync(path, 'utf8');

const regex = /SELECT\s+a\.id,\s+a\.full_name as player_name,/g;

if (regex.test(content)) {
  content = content.replace(
    /SELECT\s+a\.id,\s+a\.full_name as player_name,/g,
    'SELECT a.id, a.full_name as player_name, a.proof_of_payment, a.agent_code, a.booking_type,'
  );
  fs.writeFileSync(path, content, 'utf8');
  console.log('SUCCESS: Updated SELECT query in backend index.js!');
} else {
  console.error('ERROR: Regex did not match');
}
