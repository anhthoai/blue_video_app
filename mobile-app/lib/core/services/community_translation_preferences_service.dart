import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

String normalizeCommunityTranslationLanguageCode(String code) {
  final normalized = code.trim().toLowerCase();
  if (normalized == 'zh-cn' || normalized == 'zh-tw') {
    return normalized;
  }
  return normalized.split('-').first;
}

class CommunityTranslationPreferencesService {
  static const String _disabledSourcesKey =
      'community_translation_disabled_auto_sources';

  Future<Set<String>> getDisabledAutoTranslateSources() async {
    final prefs = await SharedPreferences.getInstance();
    final values = prefs.getStringList(_disabledSourcesKey) ?? <String>[];
    return values
        .map(normalizeCommunityTranslationLanguageCode)
        .where((code) => code.isNotEmpty)
        .toSet();
  }

  Future<void> saveDisabledAutoTranslateSources(Set<String> sources) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _disabledSourcesKey,
      sources.toList()..sort(),
    );
  }
}

final communityTranslationPreferencesServiceProvider =
    Provider<CommunityTranslationPreferencesService>((ref) {
  return CommunityTranslationPreferencesService();
});

class CommunityTranslationPreferencesNotifier extends StateNotifier<Set<String>> {
  CommunityTranslationPreferencesNotifier(this._service) : super(const <String>{}) {
    _load();
  }

  final CommunityTranslationPreferencesService _service;

  Future<void> _load() async {
    state = await _service.getDisabledAutoTranslateSources();
  }

  bool isAutoTranslateEnabled(String? sourceLanguageCode) {
    if (sourceLanguageCode == null || sourceLanguageCode.trim().isEmpty) {
      return true;
    }

    final normalized =
        normalizeCommunityTranslationLanguageCode(sourceLanguageCode);
    return !state.contains(normalized);
  }

  Future<void> setAutoTranslateEnabled(
    String sourceLanguageCode,
    bool enabled,
  ) async {
    final normalized =
        normalizeCommunityTranslationLanguageCode(sourceLanguageCode);
    if (normalized.isEmpty) {
      return;
    }

    final updated = Set<String>.from(state);
    if (enabled) {
      updated.remove(normalized);
    } else {
      updated.add(normalized);
    }

    state = updated;
    await _service.saveDisabledAutoTranslateSources(updated);
  }
}

final communityTranslationPreferencesProvider = StateNotifierProvider<
    CommunityTranslationPreferencesNotifier, Set<String>>((ref) {
  return CommunityTranslationPreferencesNotifier(
    ref.watch(communityTranslationPreferencesServiceProvider),
  );
});