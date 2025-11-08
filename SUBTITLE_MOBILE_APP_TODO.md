# Subtitle Support - Mobile App Implementation

## ✅ Completed

### 1. Models Updated (`movie_model.dart`)
- ✅ Created `Subtitle` class with all fields
- ✅ Added `flagEmoji` helper (returns flag emoji for language)
- ✅ Added `subtitles` field to `MovieEpisode`
- ✅ Updated `fromJson` to parse subtitles array
- ✅ Updated `toJson` to include subtitles

## 📋 TODO - High Priority

### 1. Update Movie Detail Screen
**File:** `lib/screens/library/movie_detail_screen.dart`

**Add subtitle download buttons below each episode:**
```dart
// After episode title and duration
if (ep.subtitles != null && ep.subtitles!.isNotEmpty)
  Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Wrap(
      spacing: 4,
      runSpacing: 4,
      children: ep.subtitles!.map((sub) {
        return InkWell(
          onTap: () => _downloadSubtitle(sub),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 6,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.grey[400]!),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  sub.flagEmoji,
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(width: 4),
                Text(
                  sub.label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.download,
                  size: 12,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    ),
  ),
```

**Add download method:**
```dart
Future<void> _downloadSubtitle(Subtitle subtitle) async {
  try {
    // Use url_launcher to open the subtitle file URL
    final uri = Uri.parse(subtitle.fileUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Downloading ${subtitle.label} subtitle...',
            ),
          ),
        );
      }
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error downloading subtitle: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
```

### 2. Update Movie Player Screen
**File:** `lib/screens/library/movie_player_screen.dart`

#### A. Add Subtitle State Variables
```dart
// Add to state variables
Subtitle? _selectedSubtitle;
List<SubtitleItem>? _subtitleItems;
String _currentSubtitleText = '';
```

#### B. Add Subtitle Button to Controls
```dart
// In bottom controls row, between mute and fullscreen
IconButton(
  padding: EdgeInsets.zero,
  constraints: const BoxConstraints(
    minWidth: 40,
    minHeight: 40,
  ),
  icon: Icon(
    Icons.closed_caption,
    color: _selectedSubtitle != null 
        ? Colors.yellow 
        : Colors.white,
    size: 22,
  ),
  onPressed: _showSubtitleSelector,
),
```

#### C. Add Subtitle Selector Bottom Sheet
```dart
void _showSubtitleSelector() {
  final episode = _currentEpisode;
  if (episode == null || episode.subtitles == null || episode.subtitles!.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No subtitles available'),
      ),
    );
    return;
  }

  showModalBottomSheet(
    context: context,
    builder: (context) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Subtitle',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            // Off option
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Off'),
              selected: _selectedSubtitle == null,
              onTap: () {
                setState(() {
                  _selectedSubtitle = null;
                  _subtitleItems = null;
                  _currentSubtitleText = '';
                });
                Navigator.pop(context);
              },
            ),
            const Divider(),
            // Subtitle options
            ...episode.subtitles!.map((sub) {
              return ListTile(
                leading: Text(
                  sub.flagEmoji,
                  style: const TextStyle(fontSize: 24),
                ),
                title: Text(sub.label),
                trailing: _selectedSubtitle?.id == sub.id
                    ? const Icon(Icons.check, color: Colors.green)
                    : null,
                selected: _selectedSubtitle?.id == sub.id,
                onTap: () {
                  _loadSubtitle(sub);
                  Navigator.pop(context);
                },
              );
            }).toList(),
          ],
        ),
      );
    },
  );
}
```

#### D. Add Subtitle Loading Method
```dart
Future<void> _loadSubtitle(Subtitle subtitle) async {
  try {
    print('📝 Loading subtitle: ${subtitle.label}');
    
    // Download subtitle file
    final response = await http.get(Uri.parse(subtitle.fileUrl));
    
    if (response.statusCode == 200) {
      // Parse SRT file
      final parser = SubtitleParser();
      final subtitleItems = parser.parseSrt(response.body);
      
      setState(() {
        _selectedSubtitle = subtitle;
        _subtitleItems = subtitleItems;
      });
      
      print('✅ Loaded ${subtitleItems.length} subtitle items');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Loaded ${subtitle.label} subtitle'),
          ),
        );
      }
    }
  } catch (e) {
    print('❌ Error loading subtitle: $e');
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading subtitle: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
```

#### E. Add Subtitle Display Widget
```dart
// Add to video player Stack, after controls
if (_currentSubtitleText.isNotEmpty)
  Positioned(
    bottom: 80, // Above controls
    left: 16,
    right: 16,
    child: Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        _currentSubtitleText,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w500,
          shadows: [
            Shadow(
              color: Colors.black,
              blurRadius: 4,
            ),
          ],
        ),
      ),
    ),
  ),
```

#### F. Update Subtitle Based on Video Position
```dart
// Add to video controller listener
void _updateSubtitleText() {
  if (_subtitleItems == null || _videoController == null) {
    return;
  }
  
  final position = _videoController!.value.position;
  final currentMillis = position.inMilliseconds;
  
  // Find subtitle for current time
  for (final item in _subtitleItems!) {
    if (currentMillis >= item.startTime && 
        currentMillis <= item.endTime) {
      if (_currentSubtitleText != item.text) {
        setState(() {
          _currentSubtitleText = item.text;
        });
      }
      return;
    }
  }
  
  // No subtitle for current time
  if (_currentSubtitleText.isNotEmpty) {
    setState(() {
      _currentSubtitleText = '';
    });
  }
}

// Call in video controller listener
_videoController!.addListener(() {
  // ... existing code ...
  _updateSubtitleText();
});
```

### 3. Create Subtitle Parser Helper
**File:** `lib/utils/subtitle_parser.dart`

```dart
class SubtitleItem {
  final int startTime; // milliseconds
  final int endTime; // milliseconds
  final String text;

  SubtitleItem({
    required this.startTime,
    required this.endTime,
    required this.text,
  });
}

class SubtitleParser {
  List<SubtitleItem> parseSrt(String content) {
    final items = <SubtitleItem>[];
    final blocks = content.split('\n\n');
    
    for (final block in blocks) {
      final lines = block.trim().split('\n');
      if (lines.length < 3) continue;
      
      // Parse time
      final timeLine = lines[1];
      final timeMatch = RegExp(
        r'(\d{2}):(\d{2}):(\d{2}),(\d{3})\s*-->\s*(\d{2}):(\d{2}):(\d{2}),(\d{3})'
      ).firstMatch(timeLine);
      
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
      final text = lines.sublist(2).join('\n');
      
      items.add(SubtitleItem(
        startTime: startTime,
        endTime: endTime,
        text: text,
      ));
    }
    
    return items;
  }
  
  int _parseTime(int hours, int minutes, int seconds, int millis) {
    return (hours * 3600000) + 
           (minutes * 60000) + 
           (seconds * 1000) + 
           millis;
  }
}
```

### 4. Add Required Packages
**File:** `pubspec.yaml`

```yaml
dependencies:
  url_launcher: ^6.2.2  # For downloading subtitles
  http: ^1.1.0  # For fetching subtitle files
```

## 📝 Implementation Steps

1. ✅ Update models (DONE)
2. Update movie detail screen (add download buttons)
3. Add subtitle parser utility
4. Update movie player screen:
   - Add subtitle selection button
   - Add subtitle selector bottom sheet
   - Add subtitle loading logic
   - Add subtitle display widget
   - Update video listener for subtitle sync
5. Add required packages to pubspec.yaml
6. Test with imported episodes that have subtitles

## 🧪 Testing Checklist

- [ ] Subtitle models parse correctly from API
- [ ] Download buttons appear in movie detail screen
- [ ] Clicking download opens uloz.to in browser
- [ ] Subtitle button appears in player controls
- [ ] Subtitle selector shows available languages with flags
- [ ] Selecting subtitle loads and displays it
- [ ] Subtitle text updates as video plays
- [ ] Subtitle text is readable and positioned correctly
- [ ] Turning off subtitle works
- [ ] Subtitle persists when changing episodes
- [ ] Subtitle syncs correctly with video position

## 🎨 UI Preview

### Movie Detail Screen
```
Episode 1: Video Title
40m

🇬🇧 English ⬇️  🇹🇭 Thai ⬇️  🇯🇵 Japanese ⬇️  🇦🇪 Arabic ⬇️
```

### Movie Player - Subtitle Selector
```
┌─────────────────────────┐
│ Select Subtitle         │
├─────────────────────────┤
│ ✕ Off               ✓   │
├─────────────────────────┤
│ 🇬🇧 English              │
│ 🇹🇭 Thai                 │
│ 🇯🇵 Japanese             │
│ 🇦🇪 Arabic               │
└─────────────────────────┘
```

### Movie Player - Subtitle Display
```
┌─────────────────────────────┐
│                             │
│       [Video Playing]       │
│                             │
│  ┌─────────────────────┐   │
│  │  Subtitle text here │   │  ← Subtitle overlay
│  └─────────────────────┘   │
│                             │
│  [Progress] [Time] [CC]🟡   │  ← CC button highlighted
└─────────────────────────────┘
```

## 📚 Resources

- **SRT Format:** https://en.wikipedia.org/wiki/SubRip
- **ISO 639-2 Codes:** https://en.wikipedia.org/wiki/List_of_ISO_639-2_codes
- **Flutter Video Player:** https://pub.dev/packages/video_player
- **URL Launcher:** https://pub.dev/packages/url_launcher

---

**Note:** This implementation uses a custom subtitle parser. Alternative: Use the `subtitle` package (https://pub.dev/packages/subtitle) for more robust subtitle format support (SRT, VTT, ASS, SSA).

