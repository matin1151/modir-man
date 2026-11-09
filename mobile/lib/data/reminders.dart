import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as tz;
import '../domain/models.dart';

class Reminders {
  final plugin = FlutterLocalNotificationsPlugin();
  Future<void> initialize() async {
    timezone_data.initializeTimeZones();
    await plugin.initialize(const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher')));
  }
  int idFor(String taskId) {
    var value = 0;
    for (final code in taskId.codeUnits) { value = (value * 31 + code) & 0x7fffffff; }
    return value;
  }
  Future<void> sync(AppTask task) async {
    await plugin.cancel(idFor(task.id));
    if (task.dueAt == null || task.status == 'done' || task.status == 'cancelled' ||
      task.dueAt! <= DateTime.now().millisecondsSinceEpoch) return;
    final android = plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final allowed = await android?.requestNotificationsPermission();
    if (allowed == false) return;
    await plugin.zonedSchedule(idFor(task.id), 'موعد وظیفه', task.title,
      tz.TZDateTime.from(DateTime.fromMillisecondsSinceEpoch(task.dueAt!).toUtc(), tz.UTC),
      const NotificationDetails(android: AndroidNotificationDetails('task_due', 'موعد وظایف',
        channelDescription: 'یادآوری محلی موعد وظایف')),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime);
  }
  Future<void> cancel(String taskId) => plugin.cancel(idFor(taskId));
}
