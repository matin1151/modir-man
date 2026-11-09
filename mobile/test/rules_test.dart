import 'package:flutter_test/flutter_test.dart';
import 'package:modir_man/domain/models.dart';
import 'package:modir_man/domain/rules.dart';
import 'package:modir_man/ui/home.dart';

AppTask task(String id, {String status = 'todo', int priority = 2, int? due}) =>
  AppTask(id: id, title: id, status: status, priority: priority, dueAt: due, createdAt: 1, updatedAt: 1);
void main() {
  test('اعتبارسنجی عنوان', () {
    expect(validateTitle('   '), isNotNull);
    expect(validateTitle('کار'), isNull);
    expect(validateTitle('a' * 181), isNotNull);
  });
  test('پیشرفت، وظیفه لغو شده را حذف می‌کند', () {
    expect(progress([task('a', status: 'done'), task('b', status: 'cancelled')]), 100);
    expect(progress([]), 0);
  });
  test('عقب‌افتادگی و سه پیشنهاد', () {
    final now = DateTime(2026, 11, 9);
    final yesterday = DateTime(2026, 11, 8).millisecondsSinceEpoch;
    expect(isOverdue(task('old', due: yesterday), now), isTrue);
    expect(isOverdue(task('done', status: 'done', due: yesterday), now), isFalse);
    final list = todaySuggestions([task('low', priority: 1), task('old', due: yesterday),
      task('high', priority: 3), task('done', status: 'done')], now);
    expect(list.length, 3);
    expect(list.first.id, 'old');
  });
  test('نمایش تاریخ شمسی', () {
    expect(jalali(DateTime(2024, 3, 20).millisecondsSinceEpoch), '1403/01/01');
  });
}
