const fs = require('fs');
let pubspec = fs.readFileSync('pubspec.yaml', 'utf8');
const missingBlock = `
  flutter_secure_storage: ^10.3.1
  google_sign_in: ^6.2.1
  flutter_facebook_auth: ^7.2.0
  firebase_core: ^4.13.0
  firebase_messaging: ^16.5.0
  flutter_map_cancellable_tile_provider: ^3.0.2
  agora_rtc_engine: 6.1.0
  permission_handler: ^11.3.1

dev_dependencies:
  flutter_test:
    sdk: flutter
`;

pubspec = pubspec.replace('local_auth: ^2.2.0', 'local_auth: ^2.2.0' + missingBlock);
pubspec = pubspec.replace('agora_rtc_engine: 6.1.0\n  permission_handler: ^11.3.1', '');
fs.writeFileSync('pubspec.yaml', pubspec);
