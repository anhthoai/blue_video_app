import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/services/storage_service.dart';
import 'core/services/auth_service.dart';
import 'core/services/nsfw_settings_service.dart';
import 'core/services/locale_service.dart';
import 'core/services/theme_service.dart';
import 'l10n/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables (optional - will use defaults if .env is missing)
  try {
  await dotenv.load(fileName: ".env");
    debugPrint('✅ .env file loaded successfully');
    debugPrint('   API_BASE_URL: ${dotenv.env['API_BASE_URL'] ?? 'not set'}');
  } catch (e) {
    // .env file not found - will use default values from ApiService
    // ApiService handles NotInitializedError gracefully
    debugPrint('⚠️ .env file not found or failed to load: $e');
    debugPrint('   Using default API URLs from ApiService');
  }

  // Initialize Firebase (disabled for testing with mock data)
  // await Firebase.initializeApp();

  // Initialize Hive
  await Hive.initFlutter();

  // Initialize services
  await StorageService.init();
  // await NotificationService.init(); // Disabled for testing (requires Firebase)

  // Initialize AuthService
  final prefs = await SharedPreferences.getInstance();
  final authService = AuthService(prefs);
  final nsfwSettingsService = NsfwSettingsService(prefs);
  final themeService = ThemeNotifier(prefs);

  // Reload current user with fresh data from API
  await authService.reloadCurrentUser();

  runApp(ProviderScope(
    overrides: [
      authServiceProvider.overrideWithValue(authService),
      nsfwSettingsServiceProvider.overrideWithValue(nsfwSettingsService),
      themeProvider.overrideWith((ref) => themeService),
    ],
    child: const BlueVideoApp(),
  ));
}

class BlueVideoApp extends ConsumerWidget {
  const BlueVideoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final locale = ref.watch(localeProvider);
    final themeMode = ref.watch(themeProvider
        .select((theme) => ref.read(themeProvider.notifier).getThemeMode()));

    // App is ready to use real API

    return MaterialApp.router(
      title: 'Blue Video App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
      locale: locale,
      localizationsDelegates: const [
        AppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('zh'),
        Locale('ja'),
      ],
    );
  }
}
