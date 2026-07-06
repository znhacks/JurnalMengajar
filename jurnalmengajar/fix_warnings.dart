import 'dart:io';

void main() {
  final libDir = Directory('lib');
  if (!libDir.existsSync()) return;

  int opacityCount = 0;
  int colorCount = 0;
  
  for (final file in libDir.listSync(recursive: true)) {
    if (file is File && file.path.endsWith('.dart')) {
      String content = file.readAsStringSync();
      bool changed = false;

      // Fix withOpacity
      final opacityRegex = RegExp(r'\.withOpacity\((.*?)\)');
      if (opacityRegex.hasMatch(content)) {
        content = content.replaceAllMapped(opacityRegex, (match) {
          return '.withValues(alpha: ${match.group(1)})';
        });
        changed = true;
        opacityCount++;
      }

      // Fix activeColor
      if (content.contains('activeColor:')) {
        content = content.replaceAll('activeColor:', 'activeThumbColor:');
        changed = true;
        colorCount++;
      }

      if (changed) {
        file.writeAsStringSync(content);
      }
    }
  }
  
  stdout.writeln('Fixed withOpacity in $opacityCount files');
  stdout.writeln('Fixed activeColor in $colorCount files');
}
