import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Service to manage app locale/language
class LocaleService {
  static const String _localeKey = 'app_locale';
  
  /// Get the saved locale
  Future<Locale?> getSavedLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final localeCode = prefs.getString(_localeKey);
    
    if (localeCode != null) {
      return Locale(localeCode);
    }
    return null;
  }
  
  /// Save the selected locale
  Future<void> saveLocale(Locale locale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, locale.languageCode);
  }
  
  /// Clear the saved locale (use system default)
  Future<void> clearLocale() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_localeKey);
  }
}

/// Provider for LocaleService
final localeServiceProvider = Provider<LocaleService>((ref) {
  return LocaleService();
});

/// StateNotifier for managing the current locale
class LocaleNotifier extends StateNotifier<Locale> {
  final LocaleService _localeService;
  
  LocaleNotifier(this._localeService) : super(const Locale('en')) {
    _loadSavedLocale();
  }
  
  /// Load saved locale on initialization
  Future<void> _loadSavedLocale() async {
    final savedLocale = await _localeService.getSavedLocale();
    if (savedLocale != null) {
      state = savedLocale;
    }
  }
  
  /// Change the app locale
  Future<void> setLocale(Locale locale) async {
    await _localeService.saveLocale(locale);
    state = locale;
  }
  
  /// Reset to system default
  Future<void> resetToSystemDefault() async {
    await _localeService.clearLocale();
    state = const Locale('en'); // Default fallback
  }
}

/// Provider for the current locale
final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  final localeService = ref.watch(localeServiceProvider);
  return LocaleNotifier(localeService);
});

