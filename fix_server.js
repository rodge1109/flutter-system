const fs = require('fs');
const path = 'C:/website/pickle-system/server/index.js';
let content = fs.readFileSync(path, 'utf8');

const target = `        open_time: c.open_time || '00:00',
        close_time: c.close_time || '23:59'
      };`;
const replacement = `        open_time: c.open_time || '00:00',
        close_time: c.close_time || '23:59',
        about_venue: c.about_venue || '',
        booking_policy: c.booking_policy || '',
        faq: c.faq || ''
      };`;

if (content.includes(target)) {
    content = content.replace(target, replacement);
    fs.writeFileSync(path, content, 'utf8');
    console.log("Successfully updated index.js!");
} else {
    console.log("Target string not found in index.js");
}
