import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing NSFW content preferences
class NsfwSettingsService {
  static const String _nsfwViewingEnabledKey = 'nsfw_viewing_enabled';
  static const String _nsfwAgeConfirmedKey = 'nsfw_age_confirmed';

  final SharedPreferences _prefs;

  NsfwSettingsService(this._prefs);

  /// Check if user has enabled NSFW viewing
  bool get isNsfwViewingEnabled {
    return _prefs.getBool(_nsfwViewingEnabledKey) ?? false;
  }

  /// Check if user has confirmed they are 18+
  bool get isAgeConfirmed {
    return _prefs.getBool(_nsfwAgeConfirmedKey) ?? false;
  }

  /// Enable NSFW viewing
  Future<void> enableNsfwViewing() async {
    await _prefs.setBool(_nsfwViewingEnabledKey, true);
  }

  /// Disable NSFW viewing
  Future<void> disableNsfwViewing() async {
    await _prefs.setBool(_nsfwViewingEnabledKey, false);
  }

  /// Confirm user is 18+ (this is persistent)
  Future<void> confirmAge() async {
    await _prefs.setBool(_nsfwAgeConfirmedKey, true);
  }

  /// Reset age confirmation (for testing)
  Future<void> resetAgeConfirmation() async {
    await _prefs.setBool(_nsfwAgeConfirmedKey, false);
  }

  /// Toggle NSFW viewing
  Future<void> toggleNsfwViewing(bool value) async {
    await _prefs.setBool(_nsfwViewingEnabledKey, value);
  }
}

/// State class for NSFW settings
class NsfwSettingsState {
  final bool isNsfwViewingEnabled;
  final bool isAgeConfirmed;

  const NsfwSettingsState({
    required this.isNsfwViewingEnabled,
    required this.isAgeConfirmed,
  });

  NsfwSettingsState copyWith({
    bool? isNsfwViewingEnabled,
    bool? isAgeConfirmed,
  }) {
    return NsfwSettingsState(
      isNsfwViewingEnabled: isNsfwViewingEnabled ?? this.isNsfwViewingEnabled,
      isAgeConfirmed: isAgeConfirmed ?? this.isAgeConfirmed,
    );
  }
}

/// State notifier for NSFW settings
class NsfwSettingsNotifier extends StateNotifier<NsfwSettingsState> {
  final NsfwSettingsService _service;

  NsfwSettingsNotifier(this._service)
      : super(NsfwSettingsState(
          isNsfwViewingEnabled: _service.isNsfwViewingEnabled,
          isAgeConfirmed: _service.isAgeConfirmed,
        ));

  /// Enable NSFW viewing
  Future<void> enableNsfwViewing() async {
    await _service.enableNsfwViewing();
    state = state.copyWith(isNsfwViewingEnabled: true);
  }

  /// Disable NSFW viewing
  Future<void> disableNsfwViewing() async {
    await _service.disableNsfwViewing();
    state = state.copyWith(isNsfwViewingEnabled: false);
  }

  /// Confirm age (18+)
  Future<void> confirmAge() async {
    await _service.confirmAge();
    state = state.copyWith(isAgeConfirmed: true);
  }

  /// Toggle NSFW viewing
  Future<void> toggleNsfwViewing(bool value) async {
    await _service.toggleNsfwViewing(value);
    state = state.copyWith(isNsfwViewingEnabled: value);
  }

  /// Refresh state from service
  void refresh() {
    state = NsfwSettingsState(
      isNsfwViewingEnabled: _service.isNsfwViewingEnabled,
      isAgeConfirmed: _service.isAgeConfirmed,
    );
  }
}

/// Provider for NSFW settings service
final nsfwSettingsServiceProvider = Provider<NsfwSettingsService>((ref) {
  throw UnimplementedError('NsfwSettingsService requires SharedPreferences');
});

/// Provider for NSFW settings state
final nsfwSettingsProvider =
    StateNotifierProvider<NsfwSettingsNotifier, NsfwSettingsState>((ref) {
  final service = ref.watch(nsfwSettingsServiceProvider);
  return NsfwSettingsNotifier(service);
});
