import re

path = r'C:\website\flutter-project\lib\screens\dashboard_screen.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Add fetch flags to State class
if 'bool _openPlaysFetched = false;' not in content:
    content = content.replace('bool _isLoading = true;', 'bool _isLoading = true;\n  bool _openPlaysFetched = false;\n  bool _openChallengesFetched = false;\n  bool _pasaloCourtsFetched = false;')

# 2. Remove fetches from _loadUserData
content = content.replace('        _fetchOpenPlays();\n', '')
content = content.replace('        _fetchOpenChallenges();\n', '')
content = content.replace('        _fetchPasaloCourts();\n', '')

def replace_section(content, method_name, title, fetch_method, flag_var, list_var):
    # Find start of method
    start_idx = content.find(f'Widget {method_name}() {{')
    if start_idx == -1: return content
    
    # Find the end of method by brace matching
    brace_count = 0
    in_method = False
    end_idx = -1
    for i in range(start_idx, len(content)):
        if content[i] == '{':
            brace_count += 1
            in_method = True
        elif content[i] == '}':
            brace_count -= 1
            if in_method and brace_count == 0:
                end_idx = i
                break
                
    method_content = content[start_idx:end_idx+1]
    
    # We want to replace the `return Column(`... up to `children: [`
    # with the ExpansionTile, and then at the very end of method replace `);` with `);` and close the ExpansionTile
    
    # First, find the 'return Column('
    col_start = method_content.find('return Column(')
    if col_start == -1: return content
    
    # Let's replace the whole top part of the Column
    # (from 'return Column' down to the first 'if')
    if_start = method_content.find(f'if ({list_var}.isEmpty)')
    if if_start == -1: return content
    
    # We will inject the ExpansionTile header and the loading state
    # Notice we use Theme.of(context).copyWith(dividerColor: Colors.transparent) to hide the border
    new_header = f"""return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: false,
        onExpansionChanged: (expanded) {{
          if (expanded && !{flag_var}) {{
            {fetch_method}();
            setState(() {{ {flag_var} = true; }});
          }}
        }},
        title: Text(
          '{title}',
          style: TextStyle(fontFamily: 'Poppins', fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: -0.5, color: AppColors.deepTeal),
        ),
        children: [
          if (!{flag_var})
            Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: AppColors.accentLime))
          else """
    
    # Replace from 'return Column(' to the 'if (_something.isEmpty)'
    top_replaced = method_content[:col_start] + new_header + method_content[if_start:]
    
    # Now fix the end of the method
    # The original method ended with:
    #       ],
    #     );
    #   }
    # We need to change it to:
    #       ],
    #     ),
    #   );
    # }
    bottom_replaced = top_replaced.rsplit(';', 1)
    if len(bottom_replaced) == 2:
        top_replaced = bottom_replaced[0] + '),\n    );' + bottom_replaced[1]
        
    return content[:start_idx] + top_replaced + content[end_idx+1:]

# Apply replacements
content = replace_section(content, '_buildOpenPlaysSection', 'Active Open Plays', '_fetchOpenPlays', '_openPlaysFetched', '_openPlays')
content = replace_section(content, '_buildOpenChallengesSection', 'Active Open Challenges', '_fetchOpenChallenges', '_openChallengesFetched', '_openChallenges')
content = replace_section(content, '_buildPasaloCourtsSection', 'Pasalo Courts', '_fetchPasaloCourts', '_pasaloCourtsFetched', '_pasaloCourts')

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
print("Dashboard completely updated with ExpansionTiles!")
