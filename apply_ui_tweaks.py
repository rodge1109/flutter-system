import re

path = r'C:\website\flutter-project\lib\screens\dashboard_screen.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Update font colors in _buildAppBar()
app_bar_pattern = r"(Text\(\s*'Hello,.*?',\s*style: TextStyle\([^)]*?color: )AppColors\.softWhite(\)[^)]*\))"
content = re.sub(app_bar_pattern, r"\1AppColors.richBlack\2", content)

subtitle_pattern = r"(Text\(\s*'Let\'s book your court\.',\s*style: TextStyle\([^)]*?color: )AppColors\.softWhite\.withOpacity\(0\.8\)(\)[^)]*\))"
content = re.sub(subtitle_pattern, r"\1AppColors.richBlack.withOpacity(0.8)\2", content)

# Also update the AppBar actions icons (Notification and Chat) if they are white.
content = content.replace("Icon(Icons.notifications_none_rounded, color: AppColors.softWhite)", "Icon(Icons.notifications_none_rounded, color: AppColors.richBlack)")
content = content.replace("Icon(Icons.chat_bubble_outline_rounded, color: AppColors.softWhite)", "Icon(Icons.chat_bubble_outline_rounded, color: AppColors.richBlack)")

# 2. Make the active play and others fonts smaller by 2px (22 -> 20)
# This includes 'Nearby Venues', 'Active Open Plays', 'Active Open Challenges', 'Pasalo Courts'
content = content.replace("'Nearby Venues',\n                          style: TextStyle(fontFamily: 'Poppins', fontSize: 22,", "'Nearby Venues',\n                          style: TextStyle(fontFamily: 'Poppins', fontSize: 20,")
content = content.replace("'Active Open Plays',\n            style: TextStyle(fontFamily: 'Poppins', fontSize: 22,", "'Active Open Plays',\n            style: TextStyle(fontFamily: 'Poppins', fontSize: 20,")
content = content.replace("'Active Open Challenges',\n            style: TextStyle(fontFamily: 'Poppins', fontSize: 22,", "'Active Open Challenges',\n            style: TextStyle(fontFamily: 'Poppins', fontSize: 20,")
content = content.replace("'Pasalo Courts',\n            style: TextStyle(fontFamily: 'Poppins', fontSize: 22,", "'Pasalo Courts',\n            style: TextStyle(fontFamily: 'Poppins', fontSize: 20,")

# 3. Bring back the white container by making it distinct.
# Replace Color(0xFFFAFAFA) with Colors.white and add a shadow
container_pattern = r"decoration: BoxDecoration\(\s*color: Color\(0xFFFAFAFA\),\s*borderRadius: BorderRadius\.only\(\s*topLeft: Radius\.circular\(32\),\s*topRight: Radius\.circular\(32\),\s*\),"
container_replacement = """decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(32),
                topRight: Radius.circular(32),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.richBlack.withOpacity(0.05),
                  blurRadius: 10,
                  offset: Offset(0, -4),
                ),
              ],"""
content = re.sub(container_pattern, container_replacement, content)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Updates applied successfully!")
