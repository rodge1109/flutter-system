const fs = require('fs');
const { exec } = require('child_process');

const path = 'C:/website/pickle-system/server/index.js';
let content = fs.readFileSync(path, 'utf8');

const brokenSnippet = `  } catch (err) {\n    console.error('Error fetching admin all-bookings:', err);\n    res.status(500).json({ success: false, message: err.message });\n  }\n});`;

content = content.replace(brokenSnippet, '');
// Also handle CRLF if present
content = content.replace(`  } catch (err) {\r\n    console.error('Error fetching admin all-bookings:', err);\r\n    res.status(500).json({ success: false, message: err.message });\r\n  }\r\n});`, '');

fs.writeFileSync(path, content, 'utf8');

exec('node --check C:/website/pickle-system/server/index.js', (err, stdout, stderr) => {
  if (err) {
    console.error('STILL SYNTAX ERROR:', stderr);
  } else {
    console.log('SUCCESS: SYNTAX IS NOW 100% CLEAN AND VALID!');
  }
});
