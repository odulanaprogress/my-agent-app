import 'dart:io';

void main() {
  final dir = Directory('lib');
  final files = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));
  
  final RegExp emojiRegex = RegExp(r'\p{Extended_Pictographic}', unicode: true);
  
  Map<String, List<String>> emojiUsages = {};

  for (var file in files) {
    final lines = file.readAsLinesSync();
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final matches = emojiRegex.allMatches(line);
      for (var match in matches) {
        final emoji = match.group(0)!;
        if (!emojiUsages.containsKey(emoji)) {
          emojiUsages[emoji] = [];
        }
        // Avoid duplicate lines for multiple same emojis in one line
        final usage = '${file.path}:${i+1} -> ${line.trim()}';
        if (!emojiUsages[emoji]!.contains(usage)) {
          emojiUsages[emoji]!.add(usage);
        }
      }
    }
  }

  for (var entry in emojiUsages.entries) {
    print('---');
    print('Emoji: ${entry.key} (${entry.value.length} uses)');
    // Print up to 5 usages
    for (var usage in entry.value.take(5)) {
      print('  - $usage');
    }
    if (entry.value.length > 5) {
      print('  - ... and ${entry.value.length - 5} more');
    }
  }
}
