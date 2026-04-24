import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'api_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  } catch (error) {
    debugPrint('Failed to initialize Firebase in background handler: $error');
    return;
  }

  debugPrint('Handling background push: ${message.messageId}');
}

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final ApiService _apiService = ApiService();
  static StreamSubscription<String>? _tokenRefreshSubscription;

  static bool _isInitialized = false;
  static bool _isAvailable = false;

  static Future<void> init() async {
    if (_isInitialized) {
      await registerCurrentToken();
      return;
    }

    if (!Platform.isAndroid && !Platform.isIOS) {
      debugPrint('Push notifications are only configured for Android and iOS.');
      return;
    }

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      _isAvailable = true;
    } catch (error) {
      debugPrint('Firebase initialization failed: $error');
      return;
    }

    await _messaging.setAutoInitEnabled(true);
    await _requestPermission();
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription =
        _messaging.onTokenRefresh.listen((String refreshedToken) {
      unawaited(registerCurrentToken(token: refreshedToken));
    });

    _isInitialized = true;
    await registerCurrentToken();
  }

  static Future<void> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    switch (settings.authorizationStatus) {
      case AuthorizationStatus.authorized:
        debugPrint('Push notification permission granted.');
        return;
      case AuthorizationStatus.provisional:
        debugPrint('Push notification permission granted provisionally.');
        return;
      case AuthorizationStatus.denied:
        debugPrint('Push notification permission denied.');
        return;
      case AuthorizationStatus.notDetermined:
        debugPrint('Push notification permission not determined.');
        return;
    }
  }

  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('Received foreground push: ${message.messageId}');
  }

  static Future<void> _handleNotificationTap(RemoteMessage message) async {
    debugPrint('Notification tapped: ${message.messageId}');
  }

  static Future<String?> getToken() async {
    if (!_isAvailable) {
      return null;
    }

    return _messaging.getToken();
  }

  static Future<void> registerCurrentToken({String? token}) async {
    if (!_isAvailable) {
      return;
    }

    try {
      final authToken = await _apiService.getAccessToken();
      if (authToken == null || authToken.isEmpty) {
        return;
      }

      final resolvedToken = token ?? await _messaging.getToken();
      if (resolvedToken == null || resolvedToken.isEmpty) {
        return;
      }

      await _apiService.registerPushToken(
        token: resolvedToken,
        platform: _platformName,
      );
    } catch (error) {
      debugPrint('Failed to register push token: $error');
    }
  }

  static Future<void> unregisterCurrentToken() async {
    if (!_isAvailable) {
      return;
    }

    try {
      final authToken = await _apiService.getAccessToken();
      if (authToken == null || authToken.isEmpty) {
        return;
      }

      final token = await _messaging.getToken();
      if (token == null || token.isEmpty) {
        return;
      }

      await _apiService.unregisterPushToken(token: token);
    } catch (error) {
      debugPrint('Failed to unregister push token: $error');
    }
  }

  static Future<void> subscribeToTopic(String topic) async {
    if (!_isAvailable) {
      return;
    }

    await _messaging.subscribeToTopic(topic);
  }

  static Future<void> unsubscribeFromTopic(String topic) async {
    if (!_isAvailable) {
      return;
    }

    await _messaging.unsubscribeFromTopic(topic);
  }

  static String get _platformName {
    if (Platform.isAndroid) {
      return 'android';
    }
    if (Platform.isIOS) {
      return 'ios';
    }
    return Platform.operatingSystem;
  }
}
