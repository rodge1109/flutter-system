const fs = require('fs');

const path = 'C:/website/flutter-project/lib/screens/dashboard_screen.dart';
let code = fs.readFileSync(path, 'utf8');

// 1. Remove fetches from _loadUserData
code = code.replace('_fetchOpenPlays();\n', '');
code = code.replace('_fetchOpenChallenges();\n', '');
code = code.replace('_fetchPasaloCourts();\n', '');

// 2. Add fetched flags to DashboardScreenState
if (!code.includes('bool _openPlaysFetched')) {
    code = code.replace('bool _isLoading = true;', 'bool _isLoading = true;\n  bool _openPlaysFetched = false;\n  bool _openChallengesFetched = false;\n  bool _pasaloCourtsFetched = false;');
}

// Helper to replace sections with ExpansionTile
function replaceSection(code, sectionName, title, fetchMethod, fetchedFlag, listVar, emptyText) {
    const startStr = `  Widget _build${sectionName}Section() {\n    return Column(`;
    
    // Find the end of the method
    let startIndex = code.indexOf(startStr);
    if (startIndex === -1) {
        console.log(`Could not find ${sectionName}`);
        return code;
    }
    
    // Simplistic bracket matching to find end of method
    let openBrackets = 0;
    let i = startIndex + `  Widget _build${sectionName}Section() {`.length;
    let endIndex = -1;
    for (; i < code.length; i++) {
        if (code[i] === '{') openBrackets++;
        if (code[i] === '}') {
            if (openBrackets === 0) {
                endIndex = i + 1;
                break;
            }
            openBrackets--;
        }
    }
    
    const originalMethod = code.substring(startIndex, endIndex);
    
    // We need to extract the empty state and the list view from the original
    const emptyStateStart = originalMethod.indexOf(`if (${listVar}.isEmpty)`);
    const elseStart = originalMethod.indexOf(`else`, emptyStateStart);
    const listStart = originalMethod.indexOf(`SizedBox(`, elseStart) !== -1 ? originalMethod.indexOf(`SizedBox(`, elseStart) : originalMethod.indexOf(`ListView`, elseStart);
    
    // Because parsing the inner children of the column accurately via string manipulation is hard,
    // let's just create a completely fresh method for the ExpansionTile, and we just inject the list building logic.
    // Wait, the list building logic (the cards) are different for each.
    // Let's just find `if (${listVar}.isEmpty)` and keep everything from there to the end of the children array.
    
    // Better idea: replace the start of the Column with the ExpansionTile
    let newMethod = originalMethod.replace(
        /return Column\([\s\S]*?children: \[[\s\S]*?Padding\([\s\S]*?child: Row\([\s\S]*?Active Open[\s\S]*?SizedBox\(height: 16\),/i,
        `return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: false,
        onExpansionChanged: (expanded) {
          if (expanded && !${fetchedFlag}) {
            ${fetchMethod}();
            setState(() { ${fetchedFlag} = true; });
          }
        },
        title: Text(
          '${title}',
          style: TextStyle(fontFamily: 'Poppins', fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: -0.5, color: AppColors.deepTeal),
        ),
        children: [
          if (!${fetchedFlag}) 
            Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: AppColors.accentLime))
          else if (${listVar}.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    CustomPaddleIcon(color: Colors.grey.shade400),
                    SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        '${emptyText}',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else`
    );
    
    // Now we need to remove the original empty state check and just keep the `else` block content.
    // Wait, regex might destroy the card. 
    return code; // aborting this approach for a safer one
}

// Safer approach: I will just use manual replace on the exact text of the sections.
fs.writeFileSync('update_script_temp.js', '/* will run custom logic */');
