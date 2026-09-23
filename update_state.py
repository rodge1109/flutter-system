import re

with open('c:/website/flutter-project/lib/screens/booking_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Add _selectedCategory
content = content.replace('bool _isLoadingSlots = false;', 'bool _isLoadingSlots = false;\n  String _selectedCategory = \'All\';\n  Set<int> _expandedCourtIds = {};')

# Write back
with open('c:/website/flutter-project/lib/screens/booking_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
