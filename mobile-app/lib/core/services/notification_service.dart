import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  // Initialize notification service
  static Future<void> init() async {
    // Request permission for notifications
    await _requestPermission();

    // Configure message handlers
    _configureMessageHandlers();
  }

  // Request notification permission
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

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted permission');
    } else if (settings.authorizationStatus ==
        AuthorizationStatus.provisional) {
      print('User granted provisional permission');
    } else {
      print('User declined or has not accepted permission');
    }
  }

  // Configure message handlers
  static void _configureMessageHandlers() {
    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification taps
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
  }

  // Handle background messages
  static Future<void> _firebaseMessagingBackgroundHandler(
    RemoteMessage message,
  ) async {
    print('Handling a background message: ${message.messageId}');
  }

  // Handle foreground messages
  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('Handling a foreground message: ${message.messageId}');
  }

  // Handle notification taps
  static Future<void> _handleNotificationTap(RemoteMessage message) async {
    print('Notification tapped: ${message.messageId}');

    // Handle navigation based on notification data
    final data = message.data;
    if (data.containsKey('route')) {
      // Navigate to specific route
      // This would be handled by the router
    }
  }

  // Get FCM token
  static Future<String?> getToken() async {
    return await _messaging.getToken();
  }

  // Subscribe to topic
  static Future<void> subscribeToTopic(String topic) async {
    await _messaging.subscribeToTopic(topic);
  }

  // Unsubscribe from topic
  static Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
  }
}
