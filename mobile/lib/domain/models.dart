class Project {
  final String id, name, description, category, status, goal, nextAction, notes;
  final int priority, createdAt, updatedAt;
  final int? startAt, dueAt;
  const Project({required this.id, required this.name, this.description = '', this.category = '',
    this.status = 'planning', this.goal = '', this.nextAction = '', this.notes = '',
    this.priority = 2, required this.createdAt, required this.updatedAt, this.startAt, this.dueAt});
  Project copy({String? name, String? description, String? category, String? status, String? goal,
    String? nextAction, String? notes, int? priority, int? updatedAt, int? startAt, int? dueAt}) =>
    Project(id: id, name: name ?? this.name, description: description ?? this.description,
      category: category ?? this.category, status: status ?? this.status, goal: goal ?? this.goal,
      nextAction: nextAction ?? this.nextAction, notes: notes ?? this.notes,
      priority: priority ?? this.priority, createdAt: createdAt, updatedAt: updatedAt ?? this.updatedAt,
      startAt: startAt ?? this.startAt, dueAt: dueAt ?? this.dueAt);
}
class AppTask {
  final String id, title, description, status, notes;
  final String? projectId, nextTaskId;
  final int priority, createdAt, updatedAt;
  final int? dueAt, completedAt, estimatedMinutes;
  const AppTask({required this.id, required this.title, this.description = '',
    this.status = 'todo', this.notes = '', this.projectId, this.nextTaskId,
    this.priority = 2, required this.createdAt, required this.updatedAt,
    this.dueAt, this.completedAt, this.estimatedMinutes});
  AppTask copy({String? title, String? description, String? status, String? notes,
    String? projectId, String? nextTaskId, int? priority, int? updatedAt,
    int? dueAt, int? completedAt, int? estimatedMinutes, bool clearCompletion = false}) =>
    AppTask(id: id, title: title ?? this.title, description: description ?? this.description,
      status: status ?? this.status, notes: notes ?? this.notes, projectId: projectId ?? this.projectId,
      nextTaskId: nextTaskId ?? this.nextTaskId, priority: priority ?? this.priority,
      createdAt: createdAt, updatedAt: updatedAt ?? this.updatedAt,
      dueAt: dueAt ?? this.dueAt, completedAt: clearCompletion ? null : completedAt ?? this.completedAt,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes);
}
abstract class WorkRepository {
  Future<List<Project>> projects({bool archived = false});
  Future<List<AppTask>> tasks();
  Future<void> saveProject(Project project);
  Future<void> saveTask(AppTask task);
  Future<void> deleteProject(String id);
  Future<void> deleteTask(String id);
  Future<List<Map<String, Object?>>> history();
  Future<Map<String, dynamic>> exportData();
  Future<void> importData(Map<String, dynamic> data);
}
