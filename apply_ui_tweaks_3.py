import re

path = r'C:\website\flutter-project\lib\screens\dashboard_screen.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Update font sizes and icons for the sections
def replace_section_title(content, section_name, icon_name):
    # Match the row containing the text for the section
    # e.g., Text('Active Open Plays', style: TextStyle(fontFamily: 'Poppins', fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: -0.5, color: AppColors.deepTeal))
    pattern = rf"(Text\(\s*'{section_name}',\s*style: TextStyle\([^)]*?fontSize: )20(,[^)]*?\)\s*,?\s*\))"
    
    # We want to replace the Text with a Row that has an icon and the text
    replacement = f"""Row(
            children: [
              Icon({icon_name}, size: 22, color: AppColors.primaryGreen),
              SizedBox(width: 8),
              \\1 18 \\2,
            ],
          )"""
    return re.sub(pattern, replacement, content)

content = replace_section_title(content, "Active Open Plays", "Icons.sports_tennis")
content = replace_section_title(content, "Active Open Challenges", "Icons.emoji_events")
content = replace_section_title(content, "Pasalo Courts", "Icons.swap_horiz")

# 2. Tighten padding between sections in _buildBodyContent
content = content.replace("SizedBox(height: 24),\n            // Open Plays Section", "SizedBox(height: 16),\n            // Open Plays Section")
content = content.replace("SizedBox(height: 24),\n            // Open Challenges Section", "SizedBox(height: 16),\n            // Open Challenges Section")
content = content.replace("SizedBox(height: 24),\n            // Pasalo Courts Section", "SizedBox(height: 16),\n            // Pasalo Courts Section")

# 3. Replace AppBar title with PICKLEBOOK logo
app_bar_title_pattern = r"(title: isMain \? )Column\([\s\S]*?children:\s*\[\s*Text\([\s\S]*?'Hello,.*?',[\s\S]*?Text\([\s\S]*?\"Let's book your court\.\",[\s\S]*?\],\s*\)( : null,)"
logo_replacement = r"\1Text('PICKLEBOOK', style: TextStyle(fontFamily: 'Poppins', fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.deepTeal, letterSpacing: -0.5))\2"
content = re.sub(app_bar_title_pattern, logo_replacement, content)

# 4. Move Greeting down above the Next Booking Card
body_top_pattern = r"(Column\(\s*crossAxisAlignment: CrossAxisAlignment\.start,\s*children: \[\s*SizedBox\(height: )90(\),\s*)(// My Next Booking Card)"

greeting_widget = """80),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hello, ${_userName.split(' ').first}!',
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.deepTeal),
                  ),
                  Text(
                    "Let's book your court.",
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 14, color: AppColors.stoneGray),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),

            \\3"""

content = re.sub(body_top_pattern, r"\g<1>" + greeting_widget, content)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Updates applied successfully!")
