import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../firebase_options.dart';
import 'firebase_bootstrap.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (DefaultFirebaseOptions.isConfigured) {
    await FirebaseBootstrap.initialize();
  }
}

class NotificationService {
  NotificationService._();

  static final instance = NotificationService._();
  static const _channel = AndroidNotificationChannel(
    'cityrunner_alerts',
    'City Runner alerts',
    description: 'Booking, route, and fleet notifications',
    importance: Importance.high,
  );

  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  void Function(Map<String, dynamic>)? _onTap;
  bool _configured = false;

  Future<void> configure({required void Function(Map<String, dynamic>) onTap}) async {
    if (!FirebaseBootstrap.isReady || _configured) return;
    _configured = true;
    _onTap = onTap;
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await _local.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: (response) => _onTap?.call(_decodePayload(response.payload)),
    );
    final android = _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(_channel);
    await FirebaseMessaging.instance.requestPermission(alert: true, badge: true, sound: true);

    _foregroundSubscription = FirebaseMessaging.onMessage.listen(_showForegroundNotification);
    _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen((message) => _onTap?.call(message.data));
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) _onTap?.call(initial.data);
  }

  Future<String?> getToken() async {
    if (!FirebaseBootstrap.isReady) return null;
    return FirebaseMessaging.instance.getToken();
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;
    await _local.show(
      notification.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'cityrunner_alerts',
          'City Runner alerts',
          channelDescription: 'Booking, route, and fleet notifications',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: message.data.entries.map((entry) => '${entry.key}=${entry.value}').join('&'),
    );
  }

  Map<String, dynamic> _decodePayload(String? payload) {
    if (payload == null || payload.isEmpty) return const {};
    return Map.fromEntries(
      payload.split('&').where((entry) => entry.contains('=')).map((entry) {
        final index = entry.indexOf('=');
        return MapEntry(entry.substring(0, index), entry.substring(index + 1));
      }),
    );
  }

  Future<void> dispose() async {
    await _foregroundSubscription?.cancel();
    await _openedSubscription?.cancel();
  }
}
