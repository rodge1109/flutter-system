const fs = require('fs');
const path = require('path');
const pubspecPath = path.join(__dirname, 'pubspec.yaml');
let content = fs.readFileSync(pubspecPath, 'utf8');

// Ensure agora_rtc_engine and permission_handler are in the dependencies block
if (!content.includes('agora_rtc_engine:')) {
    content = content.replace('dependencies:\n', 'dependencies:\n  agora_rtc_engine: 6.1.0\n  permission_handler: ^11.3.1\n');
} else {
    content = content.replace(/agora_rtc_engine:.*/, 'agora_rtc_engine: 6.1.0');
}

if (!content.includes('permission_handler:')) {
    content = content.replace('dependencies:\n', 'dependencies:\n  permission_handler: ^11.3.1\n');
} else {
    content = content.replace(/permission_handler:.*/, 'permission_handler: ^11.3.1');
}

fs.writeFileSync(pubspecPath, content);
