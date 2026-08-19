const fs = require('fs');

let content1 = fs.readFileSync('booking_screen.dart', 'utf8');
content1 = content1.replace(/prefixText: '\\\$ ',/g, "prefixText: '₱ ',");
fs.writeFileSync('booking_screen.dart', content1, 'utf8');

let content2 = fs.readFileSync('dashboard_screen.dart', 'utf8');
content2 = content2.replace(/Text\('\?\{\$\{play\['open_play_price'\]\}'/g, "Text('₱${play['open_play_price']}'");
content2 = content2.replace(/Text\('Price: \?\{\$\{play\['open_play_price'\]\}'/g, "Text('Price: ₱${play['open_play_price']}'");
fs.writeFileSync('dashboard_screen.dart', content2, 'utf8');
console.log('Replaced');
