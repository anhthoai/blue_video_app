import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ContentProtectionService {
  ContentProtectionService._();

  static final ContentProtectionService instance = ContentProtectionService._();

  static const MethodChannel _channel =
      MethodChannel('com.onlybl.app/content_protection');
  static const String _prefsKey = 'content_protection_enabled';

  bool? _currentEnabled;
  bool _hasRestoredPersistedValue = false;

  Future<void> restoreLastKnownSetting() async {
    if (_hasRestoredPersistedValue) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_prefsKey) ?? false;
    _hasRestoredPersistedValue = true;
    await _apply(enabled, persist: false);
  }

  Future<void> setEnabled(bool enabled) async {
    await _apply(enabled, persist: true);
  }

  Future<void> _apply(bool enabled, {required bool persist}) async {
    if (_currentEnabled == enabled) {
      if (persist) {
        await _persist(enabled);
      }
      return;
    }

    try {
      await _channel.invokeMethod<void>('setProtectionEnabled', {
        'enabled': enabled,
      });
    } on MissingPluginException {
      debugPrint(
        '⚠️ Content protection is not implemented on this platform, skipping native update.',
      );
    } on PlatformException catch (error) {
      debugPrint('❌ Failed to apply content protection: $error');
    }

    _currentEnabled = enabled;

    if (persist) {
      await _persist(enabled);
    }
  }

  Future<void> _persist(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, enabled);
  }
}
