import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:modir_man/data/local_repository.dart';
import 'package:modir_man/domain/models.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  test('رابطه پروژه، تاریخچه و بازیابی اتمیک', () async {
    final location = path.join(await getDatabasesPath(), 'modir_man.db');
    await deleteDatabase(location);
    final repo = LocalRepository();
    const p = Project(id: 'p1', name: 'پروژه', createdAt: 1, updatedAt: 1);
    const t = AppTask(id: 't1', title: 'کار', projectId: 'p1', createdAt: 1, updatedAt: 1);
    await repo.saveProject(p);
    await repo.saveTask(t);
    expect((await repo.tasks()).single.projectId, 'p1');
    await repo.saveProject(p.copy(name: 'پروژه جدید'));
    expect((await repo.tasks()).single.projectId, 'p1');
    expect((await repo.history()).length, 3);
    final backup = await repo.exportData();
    await repo.deleteProject('p1');
    expect((await repo.tasks()).single.projectId, null);
    await repo.importData(backup);
    expect((await repo.tasks()).single.projectId, 'p1');
    final broken = Map<String, dynamic>.from(backup);
    broken['tasks'] = [Map<String, Object?>.from((backup['tasks'] as List).single as Map)..['project_id'] = 'missing'];
    await expectLater(repo.importData(broken), throwsFormatException);
    expect((await repo.tasks()).single.projectId, 'p1');
    await repo.close();
    await deleteDatabase(location);
  });
  test('ارتقای نسخه دیتابیس از ۱ به ۲', () async {
    final location = path.join(await getDatabasesPath(), 'modir_man.db');
    await deleteDatabase(location);
    final legacy = await openDatabase(location, version: 1, onCreate: (db, _) async {
      await db.execute('CREATE TABLE projects (id TEXT PRIMARY KEY, name TEXT NOT NULL, description TEXT NOT NULL, category TEXT NOT NULL, status TEXT NOT NULL, goal TEXT NOT NULL, next_action TEXT NOT NULL, notes TEXT NOT NULL, priority INTEGER NOT NULL, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, start_at INTEGER, due_at INTEGER)');
      await db.execute('CREATE TABLE tasks (id TEXT PRIMARY KEY, project_id TEXT, title TEXT NOT NULL, description TEXT NOT NULL, status TEXT NOT NULL, notes TEXT NOT NULL, next_task_id TEXT, priority INTEGER NOT NULL, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, due_at INTEGER, completed_at INTEGER, estimated_minutes INTEGER)');
      await db.execute('CREATE TABLE history (id INTEGER PRIMARY KEY AUTOINCREMENT, entity_type TEXT NOT NULL, entity_id TEXT NOT NULL, action TEXT NOT NULL, at INTEGER NOT NULL)');
    });
    await legacy.close();
    final repo = LocalRepository();
    expect((await repo.exportData())['settings'], isEmpty);
    await repo.close();
    await deleteDatabase(location);
  });
  test('ثبت، تکمیل و بازگشایی وظیفه با حجم بالا', () async {
    final location = path.join(await getDatabasesPath(), 'modir_man.db');
    await deleteDatabase(location);
    final repo = LocalRepository();
    const project = Project(id: 'many', name: 'حجم بالا', createdAt: 1, updatedAt: 1);
    await repo.saveProject(project);
    for (var i = 0; i < 200; i++) {
      await repo.saveTask(AppTask(id: 'task-$i', title: 'کار $i', projectId: project.id, createdAt: i, updatedAt: i));
    }
    expect((await repo.tasks()).length, 200);
    final first = (await repo.tasks()).firstWhere((t) => t.id == 'task-0');
    await repo.saveTask(first.copy(status: 'done', completedAt: 10));
    expect((await repo.tasks()).firstWhere((t) => t.id == 'task-0').completedAt, 10);
    await repo.saveTask(first.copy(status: 'todo', clearCompletion: true));
    expect((await repo.tasks()).firstWhere((t) => t.id == 'task-0').completedAt, null);
    await repo.close();
    await deleteDatabase(location);
  });
}
