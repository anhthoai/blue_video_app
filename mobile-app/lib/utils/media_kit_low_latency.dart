import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';

const Set<String> _liveLowLatencySchemes = {
  'rtsp',
  'rtsps',
  'rtmp',
  'rtmps',
  'srt',
  'udp',
  'tcp',
};

bool shouldUseLowLatencyProfile(String? sourceUrl) {
  if (sourceUrl == null || sourceUrl.isEmpty) return false;
  final scheme = Uri.tryParse(sourceUrl)?.scheme.toLowerCase();
  return scheme != null && _liveLowLatencySchemes.contains(scheme);
}

Future<void> applyMediaKitLowLatency(
  Player player, {
  String? sourceUrl,
}) async {
  if (kIsWeb) return;

  final platform = player.platform;

  Future<void> setProp(String name, dynamic value, String fallback) async {
    final keys = <String>[name, 'options/$name'];
    for (final key in keys) {
      try {
        await (platform as dynamic).setProperty(key, value);
        return;
      } catch (_) {
        try {
          await (platform as dynamic).setProperty(key, fallback);
          return;
        } catch (_) {}
      }
    }

    assert(() {
      debugPrint('media_kit: failed to set low-latency option "$name"');
      return true;
    }());
  }

  // media-kit issue #799: mpv's low-latency profile is the main fix.
  await setProp('profile', 'low-latency', 'low-latency');

  assert(() {
    debugPrint(
      'media_kit: applied low-latency profile'
      '${sourceUrl == null ? '' : ' for $sourceUrl'}',
    );
    return true;
  }());
}