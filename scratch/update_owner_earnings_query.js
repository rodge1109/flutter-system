const fs = require('fs');

const path = 'C:/website/pickle-system/server/index.js';
let content = fs.readFileSync(path, 'utf8');

const targetSelect = `SELECT 
        a.id, 
        a.full_name as player_name,
        a.preferred_date, 
        a.preferred_time, 
        a.total_amount, 
        a.status,
        a.payment_method,
        a.is_open_play,
        a.created_at,
        c.name as court_name`;

const replacementSelect = `SELECT 
        a.id, 
        a.full_name as player_name,
        a.preferred_date, 
        a.preferred_time, 
        a.total_amount, 
        a.status,
        a.payment_method,
        a.is_open_play,
        a.created_at,
        a.proof_of_payment,
        a.agent_code,
        a.booking_type,
        c.name as court_name`;

if (content.includes(targetSelect)) {
  content = content.replace(targetSelect, replacementSelect);
  fs.writeFileSync(path, content, 'utf8');
  console.log('SUCCESS: Updated SELECT query in server/index.js to include proof_of_payment, agent_code, and booking_type!');
} else {
  console.error('ERROR: Target SELECT query not found in server/index.js');
}
