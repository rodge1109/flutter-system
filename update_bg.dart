import 'dart:io';

void main() {
  final dir = Directory('lib/screens');
  if (!dir.existsSync()) return;
  for (var file in dir.listSync(recursive: true)) {
    if (file is File && file.path.endsWith('.dart')) {
      var content = file.readAsStringSync();
      var newContent = content
          .replaceAll('backgroundColor: Colors.white,', 'backgroundColor: Colors.transparent,')
          .replaceAll('backgroundColor: const Color(0xFF000000), // canvas-night', 'backgroundColor: Colors.transparent,');
      if (content != newContent) {
        file.writeAsStringSync(newContent);
        print('Updated ${file.path}');
      }
    }
  }
}
