const fs = require('fs');
const path = require('path');

const dir = 'C:/Users/ADMIN/.gradle/caches/9.1.0/transforms';
let index = 0;

function walk(currentDir) {
  if (!fs.existsSync(currentDir)) return;
  const files = fs.readdirSync(currentDir);
  for (const file of files) {
    const fullPath = path.join(currentDir, file);
    const stat = fs.statSync(fullPath);
    if (stat.isDirectory()) {
      walk(fullPath);
    } else if (file === 'AndroidManifest.xml') {
      let content = fs.readFileSync(fullPath, 'utf8');
      if (content.includes('package="io.agora.rtc"')) {
        console.log('Patching: ' + fullPath);
        index++;
        content = content.replace('package="io.agora.rtc"', 'package="io.agora.rtc.patched' + index + '"');
        fs.writeFileSync(fullPath, content);
      }
    }
  }
}

walk(dir);
console.log('Done fixing AAR manifests');
