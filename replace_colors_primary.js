const fs = require('fs');
const path = require('path');

const libDir = path.join(__dirname, 'lib');

function walkDir(dir, callback) {
    fs.readdirSync(dir).forEach(f => {
        let dirPath = path.join(dir, f);
        let isDirectory = fs.statSync(dirPath).isDirectory();
        isDirectory ? walkDir(dirPath, callback) : callback(path.join(dir, f));
    });
}

walkDir(libDir, function(filePath) {
    if (!filePath.endsWith('.dart')) return;
    
    let content = fs.readFileSync(filePath, 'utf8');
    let changed = false;

    if (content.includes('Color(0xFF0F5B48)')) {
        content = content.replace(/Color\(0xFF0F5B48\)/g, 'AppColors.primaryGreen');
        changed = true;
    }
    
    // Check if AppColors is used but not imported
    if (changed && content.includes('AppColors') && !content.includes('app_colors.dart')) {
        content = "import 'package:flutter_project/theme/app_colors.dart';\n" + content;
    }

    if (changed) {
        fs.writeFileSync(filePath, content, 'utf8');
        console.log(`Updated ${filePath}`);
    }
});
