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
    print('Initializing notification service');

    // Initialize timezone first
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));
    print('Timezone initialized');

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
        print('Notification tapped: ${details.payload}');
        // Handle notification response here
      },
    );

    // Request permissions immediately
    await _requestPermissions();
    print('Notification service initialized');
  }

  Future<void> _requestPermissions() async {
    print('Requesting notification permissions');

    if (Platform.isIOS) {
      print('Requesting iOS permissions');
      final bool? result = await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
      print('iOS permission result: $result');
    } else if (Platform.isAndroid) {
      print('Requesting Android permissions');
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      final bool? granted =
          await androidImplementation?.requestNotificationsPermission();
      print('Android permission granted: $granted');
    }
  }

  Future<void> scheduleTaskNotification({
    required int id,
    required String title,
    required DateTime scheduledDate,
  }) async {
    try {
      final scheduledTime = tz.TZDateTime.from(scheduledDate, tz.local);
      print('Scheduling notification:');
      print('ID: $id');
      print('Title: $title');
      print('Scheduled time: $scheduledTime');

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
      print('Notification scheduled successfully');
    } catch (e) {
      print('Error scheduling notification: $e');
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
