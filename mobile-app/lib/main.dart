import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:media_kit/media_kit.dart';
import 'dart:async';

import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/services/storage_service.dart';
import 'core/services/auth_service.dart';
import 'core/services/api_service.dart';
import 'core/services/nsfw_settings_service.dart';
import 'core/services/locale_service.dart';
import 'core/services/theme_service.dart';
import 'l10n/app_localizations.dart';

const String _pendingPaymentOrderKey = 'pending_payment_order_id';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize media_kit (required before creating any Player instances).
  MediaKit.ensureInitialized();

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

  // Initialize Hive
  await Hive.initFlutter();

  // Initialize services
  await StorageService.init();

  // Initialize AuthService
  final prefs = await SharedPreferences.getInstance();
  final authService = AuthService(prefs);
  final nsfwSettingsService = NsfwSettingsService(prefs);
  final themeService = ThemeNotifier(prefs);

  runApp(ProviderScope(
    overrides: [
      authServiceProvider.overrideWithValue(authService),
      nsfwSettingsServiceProvider.overrideWithValue(nsfwSettingsService),
      themeProvider.overrideWith((ref) => themeService),
    ],
    child: const BlueVideoApp(),
  ));
}

class BlueVideoApp extends ConsumerStatefulWidget {
  const BlueVideoApp({super.key});

  @override
  ConsumerState<BlueVideoApp> createState() => _BlueVideoAppState();
}

class _BlueVideoAppState extends ConsumerState<BlueVideoApp>
    with WidgetsBindingObserver {
  final GlobalKey<ScaffoldMessengerState> _messengerKey =
      GlobalKey<ScaffoldMessengerState>();
  Timer? _pendingPaymentTimer;
  bool _isCheckingPendingPayment = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPendingPayment();
    });
    _pendingPaymentTimer = Timer.periodic(
      const Duration(seconds: 12),
      (_) => _checkPendingPayment(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pendingPaymentTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPendingPayment();
    }
  }

  Future<void> _checkPendingPayment() async {
    if (!mounted || _isCheckingPendingPayment) return;

    _isCheckingPendingPayment = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final orderId = prefs.getString(_pendingPaymentOrderKey);
      if (orderId == null || orderId.isEmpty) {
        return;
      }

      final data = await ApiService().getPaymentStatus(orderId);
      final status = (data['status']?.toString() ?? '').toUpperCase();

      if (status == 'COMPLETED') {
        await prefs.remove(_pendingPaymentOrderKey);
        await ref.read(authServiceProvider).refreshCurrentUser();
        _showPaymentSnackBar(success: true);
      } else if (status == 'FAILED' || status == 'CANCELED' || status == 'CANCELLED') {
        await prefs.remove(_pendingPaymentOrderKey);
        _showPaymentSnackBar(success: false);
      }
    } catch (_) {
      // Ignore transient network errors and retry on next tick/resume.
    } finally {
      _isCheckingPendingPayment = false;
    }
  }

  void _showPaymentSnackBar({required bool success}) {
    final messenger = _messengerKey.currentState;
    final context = _messengerKey.currentContext;
    if (messenger == null || context == null) return;

    final l10n = AppLocalizations.of(context);
    final message =
        success ? l10n.paymentConfirmedCoinsAdded : l10n.paymentNotCompletedRetry;
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? Colors.green : Colors.orange,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final locale = ref.watch(localeProvider);
    final themeMode = ref.watch(themeProvider
        .select((theme) => ref.read(themeProvider.notifier).getThemeMode()));

    // App is ready to use real API

    return MaterialApp.router(
      title: 'Blue Video App',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: _messengerKey,
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
        Locale('vi'),
        Locale('ko'),
        Locale('th'),
        Locale('pt'),
        Locale('es'),
        Locale('id'),
        Locale('tr'),
        Locale('ar'),
      ],
    );
  }
}
