import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import '../domain/models.dart';

class LocalRepository implements WorkRepository {
  Database? _database;
  Future<Database> get db async => _database ??= await openDatabase(
    path.join(await getDatabasesPath(), 'modir_man.db'),
    version: 2,
    onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
    onCreate: (db, version) async {
      await db.execute('CREATE TABLE projects (id TEXT PRIMARY KEY, name TEXT NOT NULL, description TEXT NOT NULL, category TEXT NOT NULL, status TEXT NOT NULL, goal TEXT NOT NULL, next_action TEXT NOT NULL, notes TEXT NOT NULL, priority INTEGER NOT NULL, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, start_at INTEGER, due_at INTEGER)');
      await db.execute('CREATE TABLE tasks (id TEXT PRIMARY KEY, project_id TEXT REFERENCES projects(id) ON DELETE SET NULL, title TEXT NOT NULL, description TEXT NOT NULL, status TEXT NOT NULL, notes TEXT NOT NULL, next_task_id TEXT, priority INTEGER NOT NULL, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, due_at INTEGER, completed_at INTEGER, estimated_minutes INTEGER)');
      await db.execute('CREATE TABLE history (id INTEGER PRIMARY KEY AUTOINCREMENT, entity_type TEXT NOT NULL, entity_id TEXT NOT NULL, action TEXT NOT NULL, at INTEGER NOT NULL)');
      await db.execute('CREATE INDEX idx_tasks_due ON tasks(due_at)');
      await db.execute('CREATE INDEX idx_tasks_project ON tasks(project_id)');
      await db.execute('CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)');
    },
    onUpgrade: (db, oldVersion, newVersion) async {
      if (oldVersion < 2) {
        await db.execute('CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)');
      }
    },
  );
  Map<String, Object?> projectRow(Project p) => {'id': p.id, 'name': p.name, 'description': p.description,
    'category': p.category, 'status': p.status, 'goal': p.goal, 'next_action': p.nextAction,
    'notes': p.notes, 'priority': p.priority, 'created_at': p.createdAt, 'updated_at': p.updatedAt,
    'start_at': p.startAt, 'due_at': p.dueAt};
  Project projectFrom(Map<String, Object?> m) => Project(id: m['id'] as String, name: m['name'] as String,
    description: m['description'] as String, category: m['category'] as String, status: m['status'] as String,
    goal: m['goal'] as String, nextAction: m['next_action'] as String, notes: m['notes'] as String,
    priority: m['priority'] as int, createdAt: m['created_at'] as int, updatedAt: m['updated_at'] as int,
    startAt: m['start_at'] as int?, dueAt: m['due_at'] as int?);
  Map<String, Object?> taskRow(AppTask t) => {'id': t.id, 'project_id': t.projectId, 'title': t.title,
    'description': t.description, 'status': t.status, 'notes': t.notes, 'next_task_id': t.nextTaskId,
    'priority': t.priority, 'created_at': t.createdAt, 'updated_at': t.updatedAt,
    'due_at': t.dueAt, 'completed_at': t.completedAt, 'estimated_minutes': t.estimatedMinutes};
  AppTask taskFrom(Map<String, Object?> m) => AppTask(id: m['id'] as String, projectId: m['project_id'] as String?,
    title: m['title'] as String, description: m['description'] as String, status: m['status'] as String,
    notes: m['notes'] as String, nextTaskId: m['next_task_id'] as String?, priority: m['priority'] as int,
    createdAt: m['created_at'] as int, updatedAt: m['updated_at'] as int,
    dueAt: m['due_at'] as int?, completedAt: m['completed_at'] as int?,
    estimatedMinutes: m['estimated_minutes'] as int?);
  @override Future<List<Project>> projects({bool archived = false}) async {
    final rows = await (await db).query('projects', where: archived ? null : 'status != ?', whereArgs: archived ? null : ['archived'], orderBy: 'updated_at DESC');
    return rows.map(projectFrom).toList();
  }
  @override Future<List<AppTask>> tasks() async => (await (await db).query('tasks', orderBy: 'created_at DESC')).map(taskFrom).toList();
  Future<void> log(Transaction tx, String type, String id, String action) async =>
    tx.insert('history', {'entity_type': type, 'entity_id': id, 'action': action, 'at': DateTime.now().toUtc().millisecondsSinceEpoch});
  @override Future<void> saveProject(Project p) async {
    final database = await db;
    await database.transaction((tx) async {
      final old = await tx.query('projects', where: 'id = ?', whereArgs: [p.id]);
      if (old.isEmpty) { await tx.insert('projects', projectRow(p)); }
      else { await tx.update('projects', projectRow(p), where: 'id = ?', whereArgs: [p.id]); }
      await log(tx, 'project', p.id, old.isEmpty ? 'created' : p.status == 'archived' && old.first['status'] != p.status
        ? 'archived' : old.first['status'] != p.status ? 'status_changed' : 'updated');
    });
  }
  @override Future<void> saveTask(AppTask t) async {
    final database = await db;
    await database.transaction((tx) async {
      final old = await tx.query('tasks', where: 'id = ?', whereArgs: [t.id]);
      if (old.isEmpty) { await tx.insert('tasks', taskRow(t)); }
      else { await tx.update('tasks', taskRow(t), where: 'id = ?', whereArgs: [t.id]); }
      if (t.projectId != null) {
        await tx.update('projects', {'updated_at': t.updatedAt}, where: 'id = ?', whereArgs: [t.projectId]);
      }
      final action = old.isEmpty ? 'created' : old.first['status'] != t.status
        ? (t.status == 'done' ? 'completed' : old.first['status'] == 'done' ? 'reopened' : 'status_changed')
        : old.first['due_at'] != t.dueAt ? 'due_changed' : 'updated';
      await log(tx, 'task', t.id, action);
    });
  }
  @override Future<void> deleteProject(String id) async {
    final database = await db;
    await database.transaction((tx) async { await tx.delete('projects', where: 'id = ?', whereArgs: [id]); await log(tx, 'project', id, 'deleted'); });
  }
  @override Future<void> deleteTask(String id) async {
    final database = await db;
    await database.transaction((tx) async { await tx.delete('tasks', where: 'id = ?', whereArgs: [id]); await log(tx, 'task', id, 'deleted'); });
  }
  @override Future<List<Map<String, Object?>>> history() async => (await db).query('history', orderBy: 'at DESC', limit: 300);
  @override Future<Map<String, dynamic>> exportData() async {
    final database = await db;
    return {'schema': 1, 'projects': await database.query('projects'), 'tasks': await database.query('tasks'),
      'history': await database.query('history'), 'settings': await database.query('settings')};
  }
  @override Future<void> importData(Map<String, dynamic> data) async {
    if (data['schema'] != 1 || data['projects'] is! List || data['tasks'] is! List || data['history'] is! List) {
      throw const FormatException('ساختار پشتیبان معتبر نیست');
    }
    final ps = (data['projects'] as List).map((x) => projectFrom(Map<String, Object?>.from(x as Map))).toList();
    final ts = (data['tasks'] as List).map((x) => taskFrom(Map<String, Object?>.from(x as Map))).toList();
    final ids = ps.map((p) => p.id).toSet();
    if (ids.length != ps.length || ts.map((t) => t.id).toSet().length != ts.length ||
      ts.any((t) => t.projectId != null && !ids.contains(t.projectId))) {
      throw const FormatException('پشتیبان دارای شناسه یا رابطه نامعتبر است');
    }
    final hist = (data['history'] as List).map((x) => Map<String, Object?>.from(x as Map)).toList();
    final settings = data['settings'] is List
      ? (data['settings'] as List).map((x) => Map<String, Object?>.from(x as Map)).toList()
      : <Map<String, Object?>>[];
    final database = await db;
    await database.transaction((tx) async {
      await tx.delete('history'); await tx.delete('tasks'); await tx.delete('projects'); await tx.delete('settings');
      for (final p in ps) { await tx.insert('projects', projectRow(p)); }
      for (final t in ts) { await tx.insert('tasks', taskRow(t)); }
      for (final h in hist) {
        await tx.insert('history', {'entity_type': h['entity_type'], 'entity_id': h['entity_id'], 'action': h['action'], 'at': h['at']});
      }
      for (final s in settings) { await tx.insert('settings', {'key': s['key'], 'value': s['value']}); }
    });
  }
  Future<void> close() async { await _database?.close(); _database = null; }
}
