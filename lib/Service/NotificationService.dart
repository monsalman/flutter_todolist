import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'dart:io';

class NotificationService {
  static final NotificationService _notificationService =
      NotificationService._internal();
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const String CHANNEL_ID = 'task_reminder_channel';

  factory NotificationService() {
    return _notificationService;
  }

  NotificationService._internal();

  Future<void> init() async {
    // Initialize timezone first
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );

    final InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) async {
        // Handle notification response here
      },
    );

    await _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    if (Platform.isIOS) {
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
    } else if (Platform.isAndroid) {
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }
  }

  Future<void> scheduleTaskNotification({
    required int id,
    required String title,
    required DateTime scheduledDate,
  }) async {
    try {
      final scheduledTime = tz.TZDateTime.from(scheduledDate, tz.local);

      final AndroidNotificationChannel channel = AndroidNotificationChannel(
        CHANNEL_ID,
        'Task Reminders',
        description: 'Notifications for task reminders',
        importance: Importance.max,
        enableVibration: true,
        playSound: true,
      );

      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      await flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        'Task Reminder',
        'Due: $title',
        scheduledTime,
        NotificationDetails(
          android: AndroidNotificationDetails(
            CHANNEL_ID,
            'Task Reminders',
            channelDescription: 'Notifications for task reminders',
            importance: Importance.max,
            priority: Priority.high,
            channelShowBadge: true,
            enableLights: true,
            enableVibration: true,
            playSound: true,
            icon: '@mipmap/ic_launcher',
            largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
            ticker: 'Task reminder',
            fullScreenIntent: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            sound: 'default',
            badgeNumber: 1,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'task_$id',
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<void> cancelNotification(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id);
  }

  Future<void> showTestNotification() async {
    try {
      print('Attempting to show test notification');

      // Create the Android notification channel first
      final AndroidNotificationChannel channel = AndroidNotificationChannel(
        CHANNEL_ID,
        'Task Reminders',
        description: 'Notifications for task reminders',
        importance: Importance.max,
      );

      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      await flutterLocalNotificationsPlugin.show(
        0,
        'Test Notification',
        'This is a test notification',
        NotificationDetails(
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            sound: 'default',
          ),
          android: AndroidNotificationDetails(
            CHANNEL_ID,
            'Task Reminders',
            channelDescription: 'Notifications for task reminders',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
      );
      print('Test notification sent successfully');
    } catch (e) {
      print('Error showing test notification: $e');
      rethrow;
    }
  }
}
