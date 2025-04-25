import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

class SupabaseNotificationService {
  static final SupabaseNotificationService _instance =
      SupabaseNotificationService._internal();
  final _supabase = Supabase.instance.client;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  factory SupabaseNotificationService() {
    return _instance;
  }

  SupabaseNotificationService._internal();

  Future<void> init() async {
    await cancelReadNotifications();
    _subscribeToNotifications();
  }

  void _subscribeToNotifications() {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      _supabase
          .from('notifications')
          .stream(primaryKey: ['id'])
          .eq('user_id', user.id)
          .order('scheduled_for')
          .listen(
            (List<Map<String, dynamic>> notifications) {
              final unreadNotifications = notifications
                  .where((notification) => notification['is_read'] == false)
                  .toList();

              for (final notification in unreadNotifications) {
                _handleNewNotification(notification);
              }
            },
            onError: (error) {
              print('Error in notification subscription: $error');
            },
          );
    } catch (e) {
      print('Error setting up notification subscription: $e');
    }
  }

  Future<void> _handleNewNotification(Map<String, dynamic> notification) async {
    try {
      if (notification['is_read'] == true) {
        print(
            'Notification ${notification['id']} is already read, skipping...');
        return;
      }

      final scheduledForUtc = DateTime.parse(notification['scheduled_for']);
      final scheduledForLocal = scheduledForUtc.toLocal();
      final now = DateTime.now();

      final taskId = notification['task_id'];
      final notificationId = notification['id'];
      if (taskId == null) {
        print('Error: task_id is null in notification');
        return;
      }

      final payload =
          '{"taskId": "$taskId", "notificationId": "$notificationId"}';

      await _localNotifications.cancel(notification['id'].hashCode);

      if (scheduledForLocal.isAfter(now)) {
        await _scheduleLocalNotification(
          id: notification['id'].hashCode,
          title: notification['title'] ?? 'Task Reminder',
          body: notification['body'] ?? 'Task due',
          scheduledDate: scheduledForLocal,
          notificationId: notification['id'].toString(),
          payload: payload,
        );
        print('Scheduled new notification: ${notification['id']}');
      } else {
        await _showImmediateNotification(
          id: notification['id'].hashCode,
          title: notification['title'] ?? 'Task Reminder',
          body: notification['body'] ?? 'Task due',
          notificationId: notification['id'].toString(),
          payload: payload,
        );
        print('Showed immediate notification: ${notification['id']}');
      }
    } catch (e) {
      print('Error handling notification: $e');
    }
  }

  Future<void> _scheduleLocalNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? notificationId,
    String? payload,
  }) async {
    try {
      if (Platform.isAndroid) {
        final AndroidNotificationChannel channel = AndroidNotificationChannel(
          'task_reminder_channel',
          'Task Reminders',
          description: 'Notifications for task reminders',
          importance: Importance.max,
          enableVibration: true,
          playSound: true,
        );

        await _localNotifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(channel);
      }

      final scheduledTime = tz.TZDateTime.from(scheduledDate, tz.local);

      await _localNotifications.zonedSchedule(
        id,
        title,
        body,
        scheduledTime,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'task_reminder_channel',
            'Task Reminders',
            channelDescription: 'Notifications for task reminders',
            importance: Importance.max,
            priority: Priority.high,
            enableVibration: true,
            playSound: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            sound: 'default',
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
    } catch (e) {
      print('Error scheduling local notification: $e');
      rethrow;
    }
  }

  Future<void> _showImmediateNotification({
    required int id,
    required String title,
    required String body,
    String? notificationId,
    String? payload,
  }) async {
    await _localNotifications.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'task_reminder_channel',
          'Task Reminders',
          channelDescription: 'Notifications for task reminders',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: payload,
    );
  }

  Future<void> scheduleTaskNotification({
    required String title,
    required DateTime scheduledDate,
    required String taskId,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      final response = await _supabase
          .from('notifications')
          .insert({
            'user_id': user.id,
            'title': title,
            'body': 'Due Task: $title',
            'scheduled_for': scheduledDate.toIso8601String(),
            'task_id': taskId,
          })
          .select()
          .single();

      await _handleNewNotification(response);
    } catch (e) {
      print('Error scheduling notification: $e');
      rethrow;
    }
  }

  Future<void> cancelNotification(String notificationId) async {
    try {
      await _supabase.from('notifications').delete().eq('id', notificationId);
      await _localNotifications.cancel(notificationId.hashCode);
    } catch (e) {
      print('Error canceling notification: $e');
      rethrow;
    }
  }

  Future<void> cancelNotificationByTaskId(String taskId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final notifications = await _supabase
          .from('notifications')
          .select()
          .eq('task_id', taskId)
          .eq('user_id', user.id);

      for (final notification in notifications) {
        final String id = notification['id'];
        await _localNotifications.cancel(id.hashCode);
        print(
            'Cancelled local notification for task: $taskId, notification id: $id');
      }

      await _supabase.from('notifications').delete().eq('task_id', taskId);
      print('Deleted all notifications for task: $taskId');
    } catch (e) {
      print('Error canceling notification by task_id: $e');
      rethrow;
    }
  }

  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      print('Attempting to mark notification as read: $notificationId');

      final result = await _supabase
          .from('notifications')
          .update({
            'is_read': true,
            'read_at': DateTime.now().toIso8601String(),
          })
          .eq('id', notificationId)
          .select();

      await _localNotifications.cancel(notificationId.hashCode);

      print('Notification marked as read successfully: $notificationId');
      print('Update result: $result');
    } catch (e) {
      print('Error marking notification as read: $e');
      print('NotificationId: $notificationId');
    }
  }

  Future<void> deleteOldNotifications() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final DateTime oneDayAgo = DateTime.now().subtract(Duration(days: 1));

      await _supabase
          .from('notifications')
          .delete()
          .eq('user_id', user.id)
          .eq('is_read', true)
          .lt('read_at', oneDayAgo.toIso8601String());

      await _supabase
          .from('notifications')
          .delete()
          .eq('user_id', user.id)
          .lt('scheduled_for', oneDayAgo.toIso8601String());

      print('Old notifications cleaned up');
    } catch (e) {
      print('Error deleting old notifications: $e');
    }
  }

  Future<void> cancelReadNotifications() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final readNotifications = await _supabase
          .from('notifications')
          .select('id')
          .eq('user_id', user.id)
          .eq('is_read', true);

      for (final notification in readNotifications) {
        await _localNotifications.cancel(notification['id'].hashCode);
      }

      print('Cancelled all read notifications');
    } catch (e) {
      print('Error cancelling read notifications: $e');
    }
  }
}
