class SubtitleItem {
  final int startTime; // milliseconds
  final int endTime; // milliseconds
  final String text;

  SubtitleItem({
    required this.startTime,
    required this.endTime,
    required this.text,
  });

  @override
  String toString() {
    return 'SubtitleItem(start: $startTime, end: $endTime, text: $text)';
  }
}

class SubtitleParser {
  /// Parse SRT format subtitle file
  List<SubtitleItem> parseSrt(String content) {
    final items = <SubtitleItem>[];

    // Split by double newline or empty lines
    final blocks = content.split(RegExp(r'\n\s*\n'));

    for (final block in blocks) {
      final lines = block.trim().split('\n');
      if (lines.length < 3) continue;

      // Line 0: Index number (ignored)
      // Line 1: Time codes
      // Line 2+: Subtitle text

      try {
        final timeLine = lines[1];
        final timeMatch = RegExp(
                r'(\d{2}):(\d{2}):(\d{2})[,.](\d{3})\s*-->\s*(\d{2}):(\d{2}):(\d{2})[,.](\d{3})')
            .firstMatch(timeLine);

        if (timeMatch == null) continue;

        final startTime = _parseTime(
          int.parse(timeMatch.group(1)!),
          int.parse(timeMatch.group(2)!),
          int.parse(timeMatch.group(3)!),
          int.parse(timeMatch.group(4)!),
        );

        final endTime = _parseTime(
          int.parse(timeMatch.group(5)!),
          int.parse(timeMatch.group(6)!),
          int.parse(timeMatch.group(7)!),
          int.parse(timeMatch.group(8)!),
        );

        // Join text lines (skip index and time)
        final text = lines.sublist(2).join('\n').trim();

        if (text.isNotEmpty) {
          items.add(SubtitleItem(
            startTime: startTime,
            endTime: endTime,
            text: text,
          ));
        }
      } catch (e) {
        // Skip malformed blocks
        continue;
      }
    }

    return items;
  }

  /// Parse VTT format subtitle file
  List<SubtitleItem> parseVtt(String content) {
    final items = <SubtitleItem>[];

    // Remove WEBVTT header
    final withoutHeader = content.replaceFirst(RegExp(r'^WEBVTT[^\n]*\n'), '');

    // Split by double newline
    final blocks = withoutHeader.split(RegExp(r'\n\s*\n'));

    for (final block in blocks) {
      final lines = block.trim().split('\n');
      if (lines.isEmpty) continue;

      try {
        // Find time line (might have optional cue identifier before it)
        String? timeLine;
        int textStartIndex = 1;

        for (int i = 0; i < lines.length; i++) {
          if (lines[i].contains('-->')) {
            timeLine = lines[i];
            textStartIndex = i + 1;
            break;
          }
        }

        if (timeLine == null || textStartIndex >= lines.length) continue;

        final timeMatch = RegExp(
                r'(\d{2}):(\d{2}):(\d{2})[,.](\d{3})\s*-->\s*(\d{2}):(\d{2}):(\d{2})[,.](\d{3})')
            .firstMatch(timeLine);

        if (timeMatch == null) continue;

        final startTime = _parseTime(
          int.parse(timeMatch.group(1)!),
          int.parse(timeMatch.group(2)!),
          int.parse(timeMatch.group(3)!),
          int.parse(timeMatch.group(4)!),
        );

        final endTime = _parseTime(
          int.parse(timeMatch.group(5)!),
          int.parse(timeMatch.group(6)!),
          int.parse(timeMatch.group(7)!),
          int.parse(timeMatch.group(8)!),
        );

        // Join text lines
        final text = lines.sublist(textStartIndex).join('\n').trim();

        if (text.isNotEmpty) {
          items.add(SubtitleItem(
            startTime: startTime,
            endTime: endTime,
            text: text,
          ));
        }
      } catch (e) {
        // Skip malformed blocks
        continue;
      }
    }

    return items;
  }

  /// Parse subtitle file based on content/extension
  List<SubtitleItem> parse(String content, String? extension) {
    if (extension == null || extension.isEmpty) {
      // Try to auto-detect
      if (content.startsWith('WEBVTT')) {
        return parseVtt(content);
      } else {
        return parseSrt(content);
      }
    }

    switch (extension.toLowerCase()) {
      case 'vtt':
        return parseVtt(content);
      case 'srt':
      default:
        return parseSrt(content);
    }
  }

  /// Convert time to milliseconds
  int _parseTime(int hours, int minutes, int seconds, int millis) {
    return (hours * 3600000) + (minutes * 60000) + (seconds * 1000) + millis;
  }

  /// Format milliseconds to HH:MM:SS,mmm
  String formatTime(int milliseconds) {
    final hours = milliseconds ~/ 3600000;
    final minutes = (milliseconds % 3600000) ~/ 60000;
    final seconds = (milliseconds % 60000) ~/ 1000;
    final millis = milliseconds % 1000;

    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')},'
        '${millis.toString().padLeft(3, '0')}';
  }
}
