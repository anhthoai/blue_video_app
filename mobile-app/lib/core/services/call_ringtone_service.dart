import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';

enum CallRingtoneType {
  incoming,
  outgoing,
}

class CallRingtoneService {
  static CallRingtoneType? _activeType;

  static Future<void> playIncoming() async {
    if (_activeType == CallRingtoneType.incoming) {
      return;
    }

    await stop();
    _activeType = CallRingtoneType.incoming;
    FlutterRingtonePlayer().play(
      android: AndroidSounds.ringtone,
      ios: IosSounds.glass,
      looping: true,
      volume: 1.0,
      asAlarm: false,
    );
  }

  static Future<void> playOutgoing() async {
    if (_activeType == CallRingtoneType.outgoing) {
      return;
    }

    await stop();
    _activeType = CallRingtoneType.outgoing;
    FlutterRingtonePlayer().play(
      android: AndroidSounds.ringtone,
      ios: IosSounds.glass,
      looping: true,
      volume: 0.7,
      asAlarm: false,
    );
  }

  static Future<void> stop() async {
    if (_activeType == null) {
      return;
    }

    FlutterRingtonePlayer().stop();
    _activeType = null;
  }
}