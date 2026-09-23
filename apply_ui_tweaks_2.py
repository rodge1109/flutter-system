import re

path = r'C:\website\flutter-project\lib\screens\dashboard_screen.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Nearby Venues font to 18
nv_pattern = r"(Text\(\s*'Nearby Venues',\s*style: TextStyle\([^)]*?fontSize:\s*)\d+"
content = re.sub(nv_pattern, r"\g<1>18", content)

# 2. Move Nearby Venues down by 2px from search bar
# The search bar is above it. It's currently padded by a SizedBox or something, or it's inside `Expanded(child: SingleChildScrollView(padding: EdgeInsets.only(bottom: 16), ...`
# Let's change the top spacing before 'Nearby Venues Header'.
# The structure is: SingleChildScrollView(padding: EdgeInsets.only(bottom: 16), child: Column( ... children: [ // Nearby Venues Header
# I'll insert a SizedBox(height: 2) right before // Nearby Venues Header
header_comment_pattern = r"(// Nearby Venues Header\s*Padding\()"
content = re.sub(header_comment_pattern, r"SizedBox(height: 2),\n                  \1", content)


# 3 & 4. Make hamburger, bell, and chat icons black by forcing iconColor to richBlack
icon_color_pattern = r"final Color iconColor = isMain \? AppColors\.softWhite : AppColors\.richBlack;"
content = re.sub(icon_color_pattern, r"final Color iconColor = AppColors.richBlack;", content)

# Make "Let's book your court" black
subtitle_pattern = r"(Text\(\s*\"Let's book your court\.\",\s*style: TextStyle\([^)]*?color:\s*)AppColors\.softWhite\.withOpacity\(0\.8\)"
content = re.sub(subtitle_pattern, r"\1AppColors.richBlack.withOpacity(0.8)", content)


with open(path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Updates applied successfully!")
