const fs = require('fs');
const path = require('path');

const pubCache = 'C:/Users/ADMIN/AppData/Local/Pub/Cache/hosted/pub.dev';

function patchCompileSdk(dir) {
  if (!fs.existsSync(dir)) return;
  const files = fs.readdirSync(dir);
  for (const file of files) {
    if (file.startsWith('iris_method_channel') || file.startsWith('agora_rtc_engine')) {
      const gradleFile = path.join(dir, file, 'android', 'build.gradle');
      if (fs.existsSync(gradleFile)) {
        let content = fs.readFileSync(gradleFile, 'utf8');
        let changed = false;
        if (content.includes('compileSdkVersion 31')) {
          content = content.replace(/compileSdkVersion 31/g, 'compileSdkVersion 36');
          changed = true;
        }
        if (content.includes('compileSdkVersion 33')) {
          content = content.replace(/compileSdkVersion 33/g, 'compileSdkVersion 36');
          changed = true;
        }
        if (content.includes('compileSdk 31')) {
          content = content.replace(/compileSdk 31/g, 'compileSdk 36');
          changed = true;
        }
        if (changed) {
          fs.writeFileSync(gradleFile, content);
          console.log('Patched compileSdk in ' + gradleFile);
        }
      }
    }
  }
}

patchCompileSdk(pubCache);
