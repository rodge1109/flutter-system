const fs = require('fs');
const path1 = 'C:/Users/ADMIN/AppData/Local/Pub/Cache/hosted/pub.dev/iris_method_channel-1.2.0/android/build.gradle';
if(fs.existsSync(path1)) {
  let content = fs.readFileSync(path1, 'utf8');
  if (!content.includes('namespace')) {
    content = content.replace('android {', 'android {\n    namespace "io.agora.iris_method_channel"');
    fs.writeFileSync(path1, content);
    console.log('patched iris');
  }
}
const path2 = 'C:/Users/ADMIN/AppData/Local/Pub/Cache/hosted/pub.dev/agora_rtc_engine-6.2.2/android/build.gradle';
if(fs.existsSync(path2)) {
  let content = fs.readFileSync(path2, 'utf8');
  if (!content.includes('namespace')) {
    content = content.replace('android {', 'android {\n    namespace "io.agora.rtc_engine"');
    fs.writeFileSync(path2, content);
    console.log('patched agora');
  }
}
