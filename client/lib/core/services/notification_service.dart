import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Top-level handler for FCM background messages (Android/iOS).
/// Must be a top-level function (not a class method).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // When the app is in the background or terminated, FCM automatically shows
  // the notification on Android if it contains a `notification` payload.
  // This handler is for data-only messages or extra processing.
  debugPrint('[FCM BG] Message: ${message.messageId}');
}

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifs = FlutterLocalNotificationsPlugin();
  StreamSubscription? _notifListener;
  String? _currentUserId;

  // Stream controller to broadcast unread count changes
  final StreamController<int> _unreadController = StreamController<int>.broadcast();
  Stream<int> get unreadCount => _unreadController.stream;
  int _lastUnreadCount = 0;
  int get currentUnreadCount => _lastUnreadCount;

  /// Initialize the entire notification pipeline.
  Future<void> init(String userId) async {
    _currentUserId = userId;

    // 1. Request permission (Android 13+ and iOS)
    await _requestPermission();

    // 2. Initialize local notifications plugin (Android)
    await _initLocalNotifications();

    // 3. Get & store FCM token
    await _storeFCMToken();

    // 4. Listen for foreground FCM messages
    FirebaseMessaging.onMessage.listen(_handleForegroundFCM);

    // 5. Listen for RTDB notification entries for this user
    _listenForNotifications();
  }

  Future<void> _requestPermission() async {
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      announcement: false,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
    );
    debugPrint('[Notif] Permission: ${settings.authorizationStatus}');
  }

  Future<void> _initLocalNotifications() async {
    if (kIsWeb) return; // Local notifications not used on web

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _localNotifs.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        // User tapped on the notification — could navigate somewhere
        debugPrint('[Notif] Tapped: ${details.payload}');
      },
    );

    // Create a high-importance channel for Android
    const channel = AndroidNotificationChannel(
      'giveme_channel',
      'GiveMe Notifications',
      description: 'Notifications for GiveMe app',
      importance: Importance.high,
      playSound: true,
    );

    await _localNotifs
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<void> _storeFCMToken() async {
    try {
      String? token;
      if (kIsWeb) {
        // For web, pass VAPID key if you have one, otherwise null
        token = await _fcm.getToken(vapidKey: null);
      } else {
        token = await _fcm.getToken();
      }
      if (token != null && _currentUserId != null) {
        await FirebaseDatabase.instance
            .ref()
            .child('users/$_currentUserId/fcmToken')
            .set(token);
        debugPrint('[Notif] FCM token stored');
      }
    } catch (e) {
      debugPrint('[Notif] Token error: $e');
    }

    // Listen for token refresh
    _fcm.onTokenRefresh.listen((newToken) {
      if (_currentUserId != null) {
        FirebaseDatabase.instance
            .ref()
            .child('users/$_currentUserId/fcmToken')
            .set(newToken);
      }
    });
  }

  void _handleForegroundFCM(RemoteMessage message) {
    final notification = message.notification;
    if (notification != null && !kIsWeb) {
      _showLocalNotification(notification.title ?? 'GiveMe', notification.body ?? '');
    }
  }

  Future<void> _showLocalNotification(String title, String body) async {
    if (kIsWeb) return;

    const androidDetails = AndroidNotificationDetails(
      'giveme_channel',
      'GiveMe Notifications',
      channelDescription: 'Notifications for GiveMe app',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const details = NotificationDetails(android: androidDetails);

    await _localNotifs.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
    );
  }

  /// Listen for new entries in `notifications/{userId}` and show them.
  void _listenForNotifications() {
    if (_currentUserId == null) return;

    final ref = FirebaseDatabase.instance.ref().child('notifications/$_currentUserId');

    // Listen for unread count
    ref.orderByChild('read').equalTo(false).onValue.listen((event) {
      final data = event.snapshot.value as Map?;
      _lastUnreadCount = data?.length ?? 0;
      _unreadController.add(_lastUnreadCount);
    });

    // Listen for new children to show local notifications
    _notifListener?.cancel();
    _notifListener = ref.orderByChild('timestamp').onChildAdded.listen((event) {
      final data = event.snapshot.value as Map?;
      if (data == null) return;

      final isRead = data['read'] == true;
      if (isRead) return;

      final title = data['title'] as String? ?? 'GiveMe';
      final body = data['body'] as String? ?? '';
      final timestamp = data['timestamp'] as int? ?? 0;

      // Only show notification if it's recent (within last 10 seconds) to avoid
      // replaying old notifications on app startup
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - timestamp < 10000) {
        if (!kIsWeb) {
          _showLocalNotification(title, body);
        }
      }
    });
  }

  /// Mark all notifications as read for the current user.
  Future<void> markAllAsRead() async {
    if (_currentUserId == null) return;
    final ref = FirebaseDatabase.instance.ref().child('notifications/$_currentUserId');
    final snap = await ref.get();
    if (snap.exists && snap.value != null) {
      final map = Map<String, dynamic>.from(snap.value as Map);
      final updates = <String, dynamic>{};
      for (final key in map.keys) {
        updates['$key/read'] = true;
      }
      await ref.update(updates);
    }
  }

  void dispose() {
    _notifListener?.cancel();
    _unreadController.close();
  }
}
