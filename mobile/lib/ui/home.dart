import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:uuid/uuid.dart';
import '../data/backup.dart';
import '../data/reminders.dart';
import '../domain/models.dart';
import '../domain/rules.dart';

String jalali(int? millis) {
  if (millis == null) return 'بدون موعد';
  final j = Jalali.fromDateTime(DateTime.fromMillisecondsSinceEpoch(millis));
  return '${j.year}/${j.month.toString().padLeft(2, '0')}/${j.day.toString().padLeft(2, '0')}';
}

class HomePage extends StatefulWidget {
  final WorkRepository repo;
  final Reminders? reminderService;
  const HomePage({super.key, required this.repo, this.reminderService});
  @override State<HomePage> createState() => _HomePageState();
}
class _HomePageState extends State<HomePage> {
  List<Project> projects = [];
  List<AppTask> tasks = [];
  List<Map<String, Object?>> events = [];
  late final Reminders reminders;
  bool loading = true;
  String? error;
  int tab = 0;
  String query = '';
  String filter = 'all';
  Jalali month = Jalali.now();
  @override void initState() { super.initState(); reminders = widget.reminderService ?? Reminders(); reminders.initialize(); refresh(); }
  Future<void> refresh() async {
    try {
      final p = await widget.repo.projects();
      final t = await widget.repo.tasks();
      final h = await widget.repo.history();
      if (mounted) setState(() { projects = p; tasks = t; events = h; loading = false; error = null; });
    } catch (_) { if (mounted) setState(() { loading = false; error = 'خواندن داده‌ها ممکن نشد. دوباره تلاش کنید.'; }); }
  }
  void message(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  Future<String?> passwordDialog(String title) async {
    final c = TextEditingController();
    return showDialog<String>(context: context, builder: (ctx) => AlertDialog(
      title: Text(title), content: TextField(controller: c, obscureText: true,
        decoration: const InputDecoration(labelText: 'گذرواژه پشتیبان (حداقل ۱۲ نویسه)')),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
        FilledButton(onPressed: () { if (c.text.length >= 12) Navigator.pop(ctx, c.text); },
          child: const Text('ادامه'))]));
  }
  Future<void> exportBackup() async {
    final password = await passwordDialog('تهیه پشتیبان رمزنگاری‌شده');
    if (password == null) return;
    try {
      final bytes = await BackupCodec().encrypt(await widget.repo.exportData(), password);
      final path = await FilePicker.platform.saveFile(fileName: 'modir-man-backup.mmb', bytes: bytes);
      if (path != null) message('پشتیبان ذخیره شد.');
    } catch (_) { message('تهیه پشتیبان ممکن نشد.'); }
  }
  Future<void> importBackup() async {
    final picked = await FilePicker.platform.pickFiles(type: FileType.any, withData: true);
    final bytes = picked?.files.single.bytes;
    if (bytes == null) return;
    final password = await passwordDialog('بازیابی پشتیبان');
    if (password == null) return;
    try {
      final data = await BackupCodec().decrypt(bytes, password);
      if (!await confirm('داده‌های فعلی با پشتیبان جایگزین شوند؟')) return;
      await widget.repo.importData(data);
      await refresh();
      for (final task in tasks) { try { await reminders.sync(task); } catch (_) {} }
      message('بازیابی انجام شد.');
    } catch (_) { message('بازیابی ممکن نشد؛ گذرواژه یا فایل را بررسی کنید.'); }
  }
  Future<bool> confirm(String title) async => await showDialog<bool>(context: context, builder: (c) => AlertDialog(
    title: Text(title), content: const Text('این کار قابل بازگشت نیست.'),
    actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('انصراف')),
      FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('تأیید'))])) ?? false;
  Future<void> quickAdd() async {
    final c = TextEditingController();
    final title = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('ثبت سریع وظیفه'), content: TextField(controller: c, autofocus: true,
        maxLength: 180, decoration: const InputDecoration(hintText: 'عنوان کار')),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
        FilledButton(onPressed: () { if (validateTitle(c.text) == null) Navigator.pop(ctx, c.text.trim()); },
          child: const Text('ثبت'))]));
    if (title == null) return;
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    try { await widget.repo.saveTask(AppTask(id: const Uuid().v4(), title: title, createdAt: now, updatedAt: now)); await refresh(); }
    catch (_) { message('ذخیره وظیفه ممکن نشد.'); }
  }
  Future<void> projectForm([Project? old]) async {
    final name = TextEditingController(text: old?.name);
    final desc = TextEditingController(text: old?.description);
    final category = TextEditingController(text: old?.category);
    final goal = TextEditingController(text: old?.goal);
    final nextAction = TextEditingController(text: old?.nextAction);
    final notes = TextEditingController(text: old?.notes);
    String status = old?.status ?? 'planning';
    int priority = old?.priority ?? 2;
    DateTime? start = old?.startAt == null ? null : DateTime.fromMillisecondsSinceEpoch(old!.startAt!);
    DateTime? dueProject = old?.dueAt == null ? null : DateTime.fromMillisecondsSinceEpoch(old!.dueAt!);
    final saved = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, update) => AlertDialog(
      title: Text(old == null ? 'پروژه جدید' : 'ویرایش پروژه'),
      content: SizedBox(width: 440, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: name, maxLength: 180, decoration: const InputDecoration(labelText: 'نام پروژه *')),
        TextField(controller: desc, decoration: const InputDecoration(labelText: 'توضیحات')),
        TextField(controller: category, decoration: const InputDecoration(labelText: 'دسته‌بندی')),
        TextField(controller: goal, decoration: const InputDecoration(labelText: 'هدف')),
        TextField(controller: nextAction, decoration: const InputDecoration(labelText: 'اقدام بعدی')),
        TextField(controller: notes, decoration: const InputDecoration(labelText: 'یادداشت')),
        TextButton.icon(onPressed: () async { final d = await pickJalaliDate(start); if (d != null) update(() => start = d); },
          icon: const Icon(Icons.event), label: Text(start == null ? 'تاریخ شروع' : 'شروع: ${jalali(start!.millisecondsSinceEpoch)}')),
        TextButton.icon(onPressed: () async { final d = await pickJalaliDate(dueProject); if (d != null) update(() => dueProject = d); },
          icon: const Icon(Icons.event), label: Text(dueProject == null ? 'مهلت پروژه' : 'مهلت: ${jalali(dueProject!.millisecondsSinceEpoch)}')),
        DropdownButtonFormField<String>(value: status, decoration: const InputDecoration(labelText: 'وضعیت'),
          items: projectStatuses.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
          onChanged: (v) => update(() => status = v!)),
        DropdownButtonFormField<int>(value: priority, decoration: const InputDecoration(labelText: 'اولویت'),
          items: const [DropdownMenuItem(value: 1, child: Text('کم')), DropdownMenuItem(value: 2, child: Text('متوسط')), DropdownMenuItem(value: 3, child: Text('زیاد'))],
          onChanged: (v) => update(() => priority = v!)),
      ]))),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('انصراف')),
        FilledButton(onPressed: () { final err = validateTitle(name.text); if (err != null) { message(err); return; } Navigator.pop(ctx, true); }, child: const Text('ذخیره'))],
    )));
    if (saved != true) return;
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final p = old == null ? Project(id: const Uuid().v4(), name: name.text.trim(), description: desc.text.trim(),
      category: category.text.trim(), goal: goal.text.trim(), nextAction: nextAction.text.trim(),
      notes: notes.text.trim(), status: status, priority: priority, createdAt: now, updatedAt: now,
      startAt: start?.millisecondsSinceEpoch, dueAt: dueProject?.millisecondsSinceEpoch)
      : old.copy(name: name.text.trim(), description: desc.text.trim(), category: category.text.trim(),
        goal: goal.text.trim(), nextAction: nextAction.text.trim(), notes: notes.text.trim(),
        status: status, priority: priority, updatedAt: now,
        startAt: start?.millisecondsSinceEpoch, dueAt: dueProject?.millisecondsSinceEpoch);
    try { await widget.repo.saveProject(p); await refresh(); } catch (_) { message('ذخیره پروژه ممکن نشد.'); }
  }
  Future<void> taskForm([AppTask? old]) async {
    final title = TextEditingController(text: old?.title);
    final desc = TextEditingController(text: old?.description);
    final notes = TextEditingController(text: old?.notes);
    final estimate = TextEditingController(text: old?.estimatedMinutes?.toString());
    String? projectId = old?.projectId;
    String status = old?.status ?? 'todo';
    int priority = old?.priority ?? 2;
    DateTime? due = old?.dueAt == null ? null : DateTime.fromMillisecondsSinceEpoch(old!.dueAt!);
    final saved = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, update) => AlertDialog(
      title: Text(old == null ? 'وظیفه جدید' : 'ویرایش وظیفه'),
      content: SizedBox(width: 440, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: title, maxLength: 180, decoration: const InputDecoration(labelText: 'عنوان *')),
        TextField(controller: desc, decoration: const InputDecoration(labelText: 'توضیحات')),
        TextField(controller: notes, decoration: const InputDecoration(labelText: 'یادداشت')),
        TextField(controller: estimate, keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'زمان تخمینی (دقیقه)')),
        DropdownButtonFormField<String?>(value: projectId, decoration: const InputDecoration(labelText: 'پروژه'),
          items: [const DropdownMenuItem<String?>(value: null, child: Text('مستقل')),
            ...projects.map((p) => DropdownMenuItem<String?>(value: p.id, child: Text(p.name)))],
          onChanged: (v) => update(() => projectId = v)),
        DropdownButtonFormField<String>(value: status, decoration: const InputDecoration(labelText: 'وضعیت'),
          items: taskStatuses.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
          onChanged: (v) => update(() => status = v!)),
        DropdownButtonFormField<int>(value: priority, decoration: const InputDecoration(labelText: 'اولویت'),
          items: const [DropdownMenuItem(value: 1, child: Text('کم')), DropdownMenuItem(value: 2, child: Text('متوسط')), DropdownMenuItem(value: 3, child: Text('زیاد'))],
          onChanged: (v) => update(() => priority = v!)),
        TextButton.icon(icon: const Icon(Icons.event), label: Text(due == null ? 'انتخاب موعد شمسی' : 'موعد: ${jalali(due!.millisecondsSinceEpoch)}'),
          onPressed: () async { final d = await pickJalaliDate(due); if (d != null) update(() => due = d); }),
      ]))),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('انصراف')),
        FilledButton(onPressed: () { final err = validateTitle(title.text); if (err != null) { message(err); return; } Navigator.pop(ctx, true); }, child: const Text('ذخیره'))],
    )));
    if (saved != true) return;
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final minutes = estimate.text.trim().isEmpty ? null : int.tryParse(estimate.text.trim());
    if (estimate.text.trim().isNotEmpty && (minutes == null || minutes <= 0)) {
      message('زمان تخمینی باید عدد مثبت باشد.'); return;
    }
    final t = AppTask(id: old?.id ?? const Uuid().v4(), title: title.text.trim(), description: desc.text.trim(),
      notes: notes.text.trim(), projectId: projectId, status: status, priority: priority,
      createdAt: old?.createdAt ?? now, updatedAt: now,
      dueAt: due == null ? null : DateTime(due!.year, due!.month, due!.day, 9).millisecondsSinceEpoch,
      completedAt: status == 'done' ? old?.completedAt ?? now : null, estimatedMinutes: minutes);
    try {
      await widget.repo.saveTask(t); await refresh();
      try { await reminders.sync(t); } catch (_) { message('ذخیره شد؛ یادآوری تنظیم نشد.'); }
    } catch (_) { message('ذخیره وظیفه ممکن نشد.'); }
  }
  Future<DateTime?> pickJalaliDate(DateTime? initial) async {
    final start = Jalali.fromDateTime(initial ?? DateTime.now());
    int year = start.year, monthValue = start.month, day = start.day;
    return showDialog<DateTime>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, update) {
      final maxDay = Jalali(year, monthValue, 1).monthLength;
      if (day > maxDay) day = maxDay;
      return AlertDialog(title: const Text('موعد شمسی'), content: SizedBox(width: 350, child: Row(children: [
        Expanded(child: DropdownButton<int>(value: year, items: List.generate(21, (i) => DropdownMenuItem(
          value: start.year - 10 + i, child: Text('${start.year - 10 + i}'))), onChanged: (v) => update(() => year = v!))),
        Expanded(child: DropdownButton<int>(value: monthValue, items: List.generate(12, (i) => DropdownMenuItem(
          value: i + 1, child: Text('${i + 1}'))), onChanged: (v) => update(() => monthValue = v!))),
        Expanded(child: DropdownButton<int>(value: day, items: List.generate(maxDay, (i) => DropdownMenuItem(
          value: i + 1, child: Text('${i + 1}'))), onChanged: (v) => update(() => day = v!))),
      ])), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
        FilledButton(onPressed: () => Navigator.pop(ctx, Jalali(year, monthValue, day).toDateTime()),
          child: const Text('انتخاب'))]);
    }));
  }
  Future<void> toggleTask(AppTask t) async {
    final done = t.status != 'done';
    try { final changed = t.copy(status: done ? 'done' : 'todo',
      completedAt: done ? DateTime.now().toUtc().millisecondsSinceEpoch : null,
      clearCompletion: !done,
      updatedAt: DateTime.now().toUtc().millisecondsSinceEpoch);
      await widget.repo.saveTask(changed); await refresh();
      try { await reminders.sync(changed); } catch (_) { message('یادآوری به‌روز نشد.'); }
    }
    catch (_) { message('تغییر وضعیت ممکن نشد.'); }
  }
  @override Widget build(BuildContext context) {
    final now = DateTime.now();
    final visibleTasks = tasks.where((t) => (filter == 'all' || t.status == filter) &&
      ('${t.title} ${t.description} ${t.notes} ${projects.where((p) => p.id == t.projectId).map((p) => p.name).join(' ')}'.toLowerCase().contains(query.toLowerCase()))).toList();
    final visibleProjects = projects.where((p) => '${p.name} ${p.description} ${p.notes}'.toLowerCase().contains(query.toLowerCase())).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('مدیر من'), actions: [IconButton(tooltip: 'تازه‌سازی', onPressed: refresh, icon: const Icon(Icons.refresh))]),
      body: loading ? const Center(child: CircularProgressIndicator()) : error != null
        ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(error!), TextButton(onPressed: refresh, child: const Text('تلاش دوباره'))]))
        : SafeArea(child: Column(children: [
            if (tab == 1 || tab == 2) Padding(padding: const EdgeInsets.all(12), child: TextField(
              onChanged: (v) => setState(() => query = v), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'جست‌وجو', border: OutlineInputBorder()))),
            Expanded(child: ListView(padding: const EdgeInsets.all(16), children: [
              if (tab == 0) ...dashboard(now),
              if (tab == 1) ...projectList(visibleProjects),
              if (tab == 2) ...taskList(visibleTasks),
              if (tab == 3) ...calendar(),
              if (tab == 4) ...settings(),
            ])),
          ])),
      floatingActionButton: FloatingActionButton.extended(onPressed: quickAdd, icon: const Icon(Icons.add), label: const Text('کار سریع')),
      bottomNavigationBar: NavigationBar(selectedIndex: tab, onDestinationSelected: (i) => setState(() { tab = i; query = ''; }),
        destinations: const [NavigationDestination(icon: Icon(Icons.home_outlined), label: 'خانه'),
          NavigationDestination(icon: Icon(Icons.folder_outlined), label: 'پروژه‌ها'),
          NavigationDestination(icon: Icon(Icons.checklist), label: 'وظایف'),
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), label: 'تقویم'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'تنظیمات')]),
    );
  }
  List<Widget> dashboard(DateTime now) {
    final active = projects.where((p) => p.status != 'done' && p.status != 'archived').length;
    final overdue = tasks.where((t) => isOverdue(t, now)).length;
    final done = tasks.where((t) => t.status == 'done').length;
    final today = tasks.where((t) => t.dueAt != null && !isOverdue(t, now) &&
      DateTime.fromMillisecondsSinceEpoch(t.dueAt!).day == now.day &&
      DateTime.fromMillisecondsSinceEpoch(t.dueAt!).month == now.month &&
      t.status != 'done').length;
    final stale = projects.where((p) => p.status != 'done' && p.status != 'archived' &&
      now.difference(DateTime.fromMillisecondsSinceEpoch(p.updatedAt)).inDays >= 7).length;
    final weekDone = tasks.where((t) => t.completedAt != null &&
      now.difference(DateTime.fromMillisecondsSinceEpoch(t.completedAt!)).inDays < 7).length;
    final suggested = todaySuggestions(tasks, now);
    return [
      Text('نمای کلی', style: Theme.of(context).textTheme.headlineSmall),
      Wrap(spacing: 8, children: [Chip(label: Text('پروژه فعال: $active')),
        Chip(label: Text('امروز: $today')), Chip(label: Text('عقب‌افتاده: $overdue')),
        Chip(label: Text('انجام‌شده: $done')), Chip(label: Text('بی‌پیشرفت: $stale')),
        Chip(label: Text('تکمیل هفتگی: $weekDone'))]),
      const SizedBox(height: 12), Text('امروز چه کار کنم؟', style: Theme.of(context).textTheme.titleLarge),
      if (suggested.isEmpty) const _Empty('هنوز کار بازی ندارید.')
      else ...suggested.map(taskTile),
      const SizedBox(height: 18), Text('پیشرفت پروژه‌ها', style: Theme.of(context).textTheme.titleLarge),
      if (projects.isEmpty) const _Empty('اولین پروژه را بسازید.')
      else ...projects.map((p) {
        final pct = progress(tasks.where((t) => t.projectId == p.id).toList());
        return Card(child: ListTile(title: Text(p.name), subtitle: LinearProgressIndicator(value: pct / 100),
          trailing: Text('$pct٪')));
      }),
      const SizedBox(height: 16), Text('فعالیت اخیر', style: Theme.of(context).textTheme.titleLarge),
      ...events.take(5).map((e) => ListTile(title: Text('${e['entity_type'] == 'project' ? 'پروژه' : 'وظیفه'}: ${e['action']}'),
        subtitle: Text(jalali(e['at'] as int?)))),
    ];
  }
  List<Widget> projectList(List<Project> items) => [
    Row(children: [Expanded(child: Text('پروژه‌ها', style: Theme.of(context).textTheme.titleLarge)),
      FilledButton.icon(onPressed: () => projectForm(), icon: const Icon(Icons.add), label: const Text('پروژه'))]),
    if (items.isEmpty) const _Empty('پروژه‌ای پیدا نشد.')
    else ...items.map((p) => Card(child: ListTile(
      title: Text(p.name), subtitle: Text('${projectStatuses[p.status]} • پیشرفت ${progress(tasks.where((t) => t.projectId == p.id).toList())}٪'),
      onTap: () => projectForm(p),
      trailing: PopupMenuButton<String>(onSelected: (value) async {
        if (value == 'edit') { await projectForm(p); return; }
        if (value == 'archive') { await widget.repo.saveProject(p.copy(status: 'archived', updatedAt: DateTime.now().millisecondsSinceEpoch)); await refresh(); return; }
        if (await confirm('حذف پروژه و جدا کردن وظایف؟')) { await widget.repo.deleteProject(p.id); await refresh(); }
      }, itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('ویرایش')),
        PopupMenuItem(value: 'archive', child: Text('آرشیو')),
        PopupMenuItem(value: 'delete', child: Text('حذف'))])))),
  ];
  Widget taskTile(AppTask t) => Card(child: ListTile(
    leading: Checkbox(value: t.status == 'done', onChanged: (_) => toggleTask(t)),
    title: Text(t.title), subtitle: Text('${taskStatuses[t.status]} • ${jalali(t.dueAt)}'),
    onTap: () => taskForm(t),
    trailing: PopupMenuButton<String>(onSelected: (v) async {
      if (v == 'edit') { await taskForm(t); return; }
      if (await confirm('وظیفه حذف شود؟')) { await widget.repo.deleteTask(t.id); await reminders.cancel(t.id); await refresh(); }
    }, itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('ویرایش')),
      PopupMenuItem(value: 'delete', child: Text('حذف'))]),
  ));
  List<Widget> taskList(List<AppTask> items) => [
    Row(children: [Expanded(child: Text('وظایف', style: Theme.of(context).textTheme.titleLarge)),
      IconButton(onPressed: () => taskForm(), icon: const Icon(Icons.add_circle_outline), tooltip: 'وظیفه جدید')]),
    SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
      for (final f in {'all': 'همه', ...taskStatuses}.entries)
        Padding(padding: const EdgeInsets.only(left: 6), child: ChoiceChip(label: Text(f.value),
          selected: filter == f.key, onSelected: (_) => setState(() => filter = f.key))),
    ])),
    if (items.isEmpty) const _Empty('وظیفه‌ای پیدا نشد.') else ...items.map(taskTile),
  ];
  List<Widget> calendar() {
    final first = Jalali(month.year, month.month, 1).toDateTime();
    final next = month.month == 12 ? Jalali(month.year + 1, 1, 1).toDateTime() : Jalali(month.year, month.month + 1, 1).toDateTime();
    final due = tasks.where((t) => t.dueAt != null && !DateTime.fromMillisecondsSinceEpoch(t.dueAt!).isBefore(first) &&
      DateTime.fromMillisecondsSinceEpoch(t.dueAt!).isBefore(next)).toList();
    return [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        IconButton(onPressed: () => setState(() => month = month.addMonths(-1)), icon: const Icon(Icons.chevron_right)),
        Text('${month.year}/${month.month}', style: Theme.of(context).textTheme.titleLarge),
        IconButton(onPressed: () => setState(() => month = month.addMonths(1)), icon: const Icon(Icons.chevron_left)),
      ]),
      const Row(mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [Text('ش'), Text('ی'), Text('د'), Text('س'), Text('چ'), Text('پ'), Text('ج')]),
      GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 7,
        children: [
          for (var i = 1; i < Jalali(month.year, month.month, 1).weekDay; i++) const SizedBox(),
          for (var day = 1; day <= Jalali(month.year, month.month, 1).monthLength; day++)
            Builder(builder: (context) {
              final count = due.where((t) => Jalali.fromDateTime(DateTime.fromMillisecondsSinceEpoch(t.dueAt!)).day == day).length;
              return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('$day'), if (count > 0) CircleAvatar(radius: 9, child: Text('$count', style: const TextStyle(fontSize: 10)))
              ]));
            }),
        ]),
      if (due.isEmpty) const _Empty('برای این ماه موعدی ثبت نشده است.') else ...due.map(taskTile),
    ];
  }
  List<Widget> settings() => [
    Text('تنظیمات', style: Theme.of(context).textTheme.titleLarge),
    const ListTile(leading: Icon(Icons.phone_android), title: Text('داده‌ها فقط روی این دستگاه ذخیره می‌شوند.')),
    ListTile(leading: const Icon(Icons.save_alt), title: const Text('گرفتن پشتیبان رمزنگاری‌شده'), onTap: exportBackup),
    ListTile(leading: const Icon(Icons.settings_backup_restore), title: const Text('بازیابی پشتیبان'), onTap: importBackup),
    ListTile(leading: const Icon(Icons.history), title: const Text('تاریخچه فعالیت'), onTap: () => showDialog<void>(
      context: context, builder: (c) => AlertDialog(title: const Text('تاریخچه'), content: SizedBox(width: 440, height: 400,
        child: ListView(children: events.map((e) => ListTile(title: Text('${e['action']} • ${e['entity_type']}'),
          subtitle: Text(jalali(e['at'] as int?)))).toList())), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('بستن'))]))),
  ];
}
class _Empty extends StatelessWidget {
  final String text;
  const _Empty(this.text);
  @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.all(28),
    child: Center(child: Text(text, textAlign: TextAlign.center)));
}
