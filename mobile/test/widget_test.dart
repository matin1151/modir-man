import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modir_man/domain/models.dart';
import 'package:modir_man/ui/home.dart';
import 'package:modir_man/data/reminders.dart';

class FakeReminders extends Reminders {
  @override Future<void> initialize() async {}
  @override Future<void> sync(AppTask task) async {}
  @override Future<void> cancel(String id) async {}
}

class MemoryRepo implements WorkRepository {
  final ps = <Project>[], ts = <AppTask>[];
  @override Future<List<Project>> projects({bool archived = false}) async => ps;
  @override Future<List<AppTask>> tasks() async => ts;
  @override Future<List<Map<String, Object?>>> history() async => [];
  @override Future<void> saveProject(Project p) async { ps.removeWhere((x) => x.id == p.id); ps.add(p); }
  @override Future<void> saveTask(AppTask t) async { ts.removeWhere((x) => x.id == t.id); ts.add(t); }
  @override Future<void> deleteProject(String id) async => ps.removeWhere((x) => x.id == id);
  @override Future<void> deleteTask(String id) async => ts.removeWhere((x) => x.id == id);
  @override Future<Map<String, dynamic>> exportData() async => {};
  @override Future<void> importData(Map<String, dynamic> data) async {}
}
void main() {
  testWidgets('داشبورد راست‌به‌چپ و ثبت سریع کار', (tester) async {
    final repo = MemoryRepo();
    await tester.pumpWidget(MaterialApp(home: Directionality(textDirection: TextDirection.rtl, child: HomePage(repo: repo, reminderService: FakeReminders()))));
    await tester.pumpAndSettle();
    expect(find.text('امروز چه کار کنم؟'), findsOneWidget);
    expect(find.text('کار سریع'), findsOneWidget);
    await tester.tap(find.text('کار سریع'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'کار نمونه');
    await tester.tap(find.text('ثبت'));
    await tester.pumpAndSettle();
    expect(repo.ts.single.title, 'کار نمونه');
  });
  testWidgets('ثبت پروژه و جست‌وجو', (tester) async {
    final repo = MemoryRepo();
    await tester.pumpWidget(MaterialApp(home: Directionality(textDirection: TextDirection.rtl,
      child: HomePage(repo: repo, reminderService: FakeReminders()))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('پروژه‌ها').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('پروژه'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(1), 'کار شخصی');
    await tester.tap(find.text('ذخیره'));
    await tester.pumpAndSettle();
    expect(repo.ps.single.name, 'کار شخصی');
    await tester.enterText(find.byType(TextField).first, 'ناموجود');
    await tester.pumpAndSettle();
    expect(find.text('پروژه‌ای پیدا نشد.'), findsOneWidget);
  });
}
