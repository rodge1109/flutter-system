const fs = require('fs');
const files = [
  'lib/screens/dashboard_screen.dart'
];

function roundToGrid(numStr) {
  let val = parseFloat(numStr);
  if (val === 0) return 0;
  let rounded = Math.round(val / 8) * 8;
  if (rounded === 0) return 8; 
  return rounded;
}

files.forEach(f => {
  if (fs.existsSync(f)) {
    let content = fs.readFileSync(f, 'utf8');
    
    content = content.replace(/(EdgeInsets\.[a-zA-Z]+\([^)]+\))/g, (match) => {
      return match.replace(/([0-9]+\.?[0-9]*)/g, (num) => {
        return roundToGrid(num).toString() + (num.includes('.') ? '.0' : '');
      });
    });

    content = content.replace(/(SizedBox\(\s*(width|height)\s*:\s*)([0-9]+\.?[0-9]*)/g, (match, prefix, type, num) => {
      return prefix + roundToGrid(num).toString() + (num.includes('.') ? '.0' : '');
    });

    fs.writeFileSync(f, content);
  }
});
console.log("Padding standardized in dashboard!");
