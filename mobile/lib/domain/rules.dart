import 'models.dart';

const projectStatuses = {
  'planning': 'برنامه‌ریزی', 'doing': 'در حال انجام', 'waiting': 'منتظر اقدام دیگران',
  'paused': 'متوقف‌شده', 'done': 'تکمیل‌شده', 'archived': 'آرشیوشده'
};
const taskStatuses = {
  'todo': 'انجام‌نشده', 'doing': 'در حال انجام', 'waiting': 'منتظر',
  'done': 'انجام‌شده', 'cancelled': 'لغوشده'
};
String? validateTitle(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return 'عنوان لازم است';
  if (trimmed.length > 180) return 'عنوان نباید بیشتر از ۱۸۰ نویسه باشد';
  return null;
}
bool isOverdue(AppTask task, DateTime now) {
  if (task.dueAt == null || task.status == 'done' || task.status == 'cancelled') return false;
  final today = DateTime(now.year, now.month, now.day);
  final due = DateTime.fromMillisecondsSinceEpoch(task.dueAt!);
  return DateTime(due.year, due.month, due.day).isBefore(today);
}
int progress(List<AppTask> tasks) {
  final active = tasks.where((t) => t.status != 'cancelled').toList();
  if (active.isEmpty) return 0;
  return ((active.where((t) => t.status == 'done').length / active.length) * 100).round();
}
int taskScore(AppTask task, DateTime now) {
  var score = task.priority == 3 ? 30 : task.priority == 2 ? 20 : 10;
  if (isOverdue(task, now)) { score += 40; }
  else if (task.dueAt != null) {
    final due = DateTime.fromMillisecondsSinceEpoch(task.dueAt!);
    final days = DateTime(due.year, due.month, due.day).difference(DateTime(now.year, now.month, now.day)).inDays;
    if (days == 0) { score += 30; }
    else if (days <= 3 && days > 0) { score += 15; }
  }
  if (task.status == 'doing') { score += 5; }
  return score;
}
List<AppTask> todaySuggestions(List<AppTask> tasks, DateTime now) {
  final open = tasks.where((t) => t.status != 'done' && t.status != 'cancelled').toList();
  open.sort((a, b) {
    final score = taskScore(b, now).compareTo(taskScore(a, now));
    if (score != 0) return score;
    final due = (a.dueAt ?? 1 << 62).compareTo(b.dueAt ?? 1 << 62);
    return due != 0 ? due : a.createdAt.compareTo(b.createdAt);
  });
  return open.take(3).toList();
}
