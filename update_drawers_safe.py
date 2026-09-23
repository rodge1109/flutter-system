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

# Helper to replace section
def replace_section(content, method_name, list_var, flag_var, fetch_method, title, is_pasalo=False):
    # Regex to match the start of the method down to `if (_something.isEmpty)`
    
    if method_name == '_buildOpenPlaysSection':
        pattern = r"Widget _buildOpenPlaysSection\(\) \{\s*return Column\(\s*crossAxisAlignment: CrossAxisAlignment\.start,\s*children: \[\s*Padding\([\s\S]*?child: Row\([\s\S]*?Text\(\s*'Active Open Plays'[\s\S]*?SizedBox\(height: 16\),"
        replacement = f"""Widget _buildOpenPlaysSection() {{
    return ExpansionTile(
      shape: const Border(),
      collapsedShape: const Border(),
      initiallyExpanded: false,
      onExpansionChanged: (expanded) {{
        if (expanded && !{flag_var}) {{
          {fetch_method}();
          setState(() {{ {flag_var} = true; }});
        }}
      }},
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '{title}',
            style: TextStyle(fontFamily: 'Poppins', fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: -0.5, color: AppColors.deepTeal),
          ),
          if ({list_var}.isNotEmpty)
            GestureDetector(
              onTap: () {{
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AllOpenPlaysScreen(
                      openPlays: _openPlays,
                      onJoinPlay: _showJoinOpenPlayDialog,
                      onViewJoiners: _showJoinersListBottomSheet,
                    ),
                  ),
                );
              }},
              child: Text('See All', style: TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.bold, fontSize: 14)),
            ),
        ],
      ),
      children: [
        if (!{flag_var})
          Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: AppColors.accentLime))
        else"""
    elif method_name == '_buildOpenChallengesSection':
        pattern = r"Widget _buildOpenChallengesSection\(\) \{\s*return Column\(\s*crossAxisAlignment: CrossAxisAlignment\.start,\s*children: \[\s*Padding\([\s\S]*?child: Row\([\s\S]*?Text\(\s*'Active Open Challenges'[\s\S]*?SizedBox\(height: 16\),"
        replacement = f"""Widget _buildOpenChallengesSection() {{
    return ExpansionTile(
      shape: const Border(),
      collapsedShape: const Border(),
      initiallyExpanded: false,
      onExpansionChanged: (expanded) {{
        if (expanded && !{flag_var}) {{
          {fetch_method}();
          setState(() {{ {flag_var} = true; }});
        }}
      }},
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '{title}',
            style: TextStyle(fontFamily: 'Poppins', fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: -0.5, color: AppColors.deepTeal),
          ),
          if ({list_var}.isNotEmpty)
            GestureDetector(
              onTap: () {{
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => OpenChallengesScreen(),
                  ),
                ).then((_) => _loadUserData());
              }},
              child: Text('See All', style: TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.bold, fontSize: 14)),
            ),
        ],
      ),
      children: [
        if (!{flag_var})
          Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: AppColors.accentLime))
        else"""
    else:
        pattern = r"Widget _buildPasaloCourtsSection\(\) \{\s*return Column\(\s*crossAxisAlignment: CrossAxisAlignment\.start,\s*children: \[\s*Padding\([\s\S]*?child: Row\([\s\S]*?Text\(\s*'Pasalo Courts'[\s\S]*?SizedBox\(height: 16\),"
        replacement = f"""Widget _buildPasaloCourtsSection() {{
    return ExpansionTile(
      shape: const Border(),
      collapsedShape: const Border(),
      initiallyExpanded: false,
      onExpansionChanged: (expanded) {{
        if (expanded && !{flag_var}) {{
          {fetch_method}();
          setState(() {{ {flag_var} = true; }});
        }}
      }},
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '{title}',
            style: TextStyle(fontFamily: 'Poppins', fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: -0.5, color: AppColors.deepTeal),
          ),
          if ({list_var}.isNotEmpty)
            GestureDetector(
              onTap: () {{
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PasaloCourtsScreen(),
                  ),
                );
              }},
              child: Text('See All', style: TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.bold, fontSize: 14)),
            ),
        ],
      ),
      children: [
        if (!{flag_var})
          Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: AppColors.accentLime))
        else"""

    # Do the sub
    return re.sub(pattern, replacement, content)

content = replace_section(content, '_buildOpenPlaysSection', '_openPlays', '_openPlaysFetched', '_fetchOpenPlays', 'Active Open Plays')
content = replace_section(content, '_buildOpenChallengesSection', '_openChallenges', '_openChallengesFetched', '_fetchOpenChallenges', 'Active Open Challenges')
content = replace_section(content, '_buildPasaloCourtsSection', '_pasaloCourts', '_pasaloCourtsFetched', '_fetchPasaloCourts', 'Pasalo Courts')

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
print("Updated successfully!")
