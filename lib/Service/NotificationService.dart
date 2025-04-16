import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_todolist/Page/TaskDetail.dart';
import 'package:flutter_todolist/Service/NotificationSupabase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'dart:io';
import 'package:flutter/material.dart';
import 'dart:convert';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class NotificationService {
  static final NotificationService _notificationService =
      NotificationService._internal();
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final SupabaseNotificationService _supabaseNotification =
      SupabaseNotificationService();

  static const String CHANNEL_ID = 'task_reminder_channel';

  factory NotificationService() {
    return _notificationService;
  }

  NotificationService._internal();

  Future<void> init() async {
    try {
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
          try {
            if (details.payload != null) {
              print('Received notification payload: ${details.payload}');

              // Parse payload JSON
              final payloadData = json.decode(details.payload!);
              final taskId = payloadData['taskId'];
              final notificationId = payloadData['notificationId'];

              // Ambil data task dari Supabase
              final task = await Supabase.instance.client
                  .from('tasks')
                  .select()
                  .eq('id', taskId)
                  .single();

              print('Found task: $task');

              // Dapatkan context yang valid menggunakan navigatorKey
              final context = navigatorKey.currentContext;
              if (context != null) {
                // Tandai notifikasi sebagai sudah dibaca menggunakan notificationId
                await _supabaseNotification
                    .markNotificationAsRead(notificationId);
                print('Notification marked as read: $notificationId');

                // Navigate ke TaskDetail
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TaskDetail(
                      task: task,
                      onTaskUpdated: () {
                        // Refresh task list jika diperlukan
                      },
                    ),
                  ),
                );
              } else {
                print('Error: No valid context found');
              }
            } else {
              print('Error: Notification payload is null');
            }
          } catch (e) {
            print('Error handling notification click: $e');
          }
        },
      );

      await _requestPermissions();

      // Initialize Supabase notifications
      await _supabaseNotification.init();
    } catch (e) {
      print('Error initializing notification service: $e');
    }
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
    required String taskId,
  }) async {
    await _supabaseNotification.scheduleTaskNotification(
      title: title,
      scheduledDate: scheduledDate,
      taskId: taskId,
    );
  }

  Future<void> cancelNotification(int id) async {
    await _supabaseNotification.cancelNotification(id.toString());
  }

  Future<void> showTestNotification() async {
    try {
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
    } catch (e) {
      print('Error showing test notification: $e');
      rethrow;
    }
  }

  Future<void> cleanupOldNotifications() async {
    await _supabaseNotification.deleteOldNotifications();
  }
}
