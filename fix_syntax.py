path = r'C:\website\flutter-project\lib\screens\dashboard_screen.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Replace all occurrences of:
#     )),
#     );
#   }
# with:
#     ),
#   );
# }
import re
content = re.sub(r'\]\,\s*\)\)\,\s*\)\;\s*\}', '],\n      ),\n    );\n  }', content)
content = re.sub(r'\)\)\,\s*\)\;\s*\}', '),\n    );\n  }', content)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
print("Syntax fixed")
