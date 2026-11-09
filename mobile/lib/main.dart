import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shamsi_date/shamsi_date.dart';

void main() => runApp(const KartabelApp());

class Api {
  String base;
  String? token, tenant, name;
  Api(this.base);
  Future<dynamic> call(String method, String path, [Map<String, dynamic>? body]) async {
    final uri = Uri.parse('$base/api/v1$path');
    final headers = {'Content-Type': 'application/json', if (token != null) 'Authorization': 'Bearer $token'};
    http.Response response;
    try {
      switch (method) {
        case 'POST': response = await http.post(uri, headers: headers, body: jsonEncode(body)); break;
        case 'PATCH': response = await http.patch(uri, headers: headers, body: jsonEncode(body)); break;
        default: response = await http.get(uri, headers: headers);
      }
    } catch (_) { throw Exception('اتصال به سرور برقرار نشد. آدرس API را بررسی کنید.'); }
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode >= 400) throw Exception(data is Map ? data['detail'].toString() : 'خطای سرور');
    return data;
  }
  String route(String resource) => '/$resource?tenant_id=$tenant';
}

class KartabelApp extends StatefulWidget {
  const KartabelApp({super.key});
  @override State<KartabelApp> createState() => _KartabelAppState();
}
class _KartabelAppState extends State<KartabelApp> {
  final api = Api('http://10.0.2.2:8000');
  bool ready = false;
  @override void initState() { super.initState(); restore(); }
  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    api.base = prefs.getString('base') ?? api.base;
    api.token = prefs.getString('token');
    if (api.token != null) {
      try { final me = await api.call('GET', '/me'); api.tenant = me['personal_tenant_id']; api.name = me['full_name']; }
      catch (_) { api.token = null; }
    }
    setState(() => ready = true);
  }
  Future<void> login(String base, String email, String password, String name, bool register) async {
    api.base = base.replaceFirst(RegExp(r'/$'), '');
    final result = await api.call('POST', register ? '/auth/register' : '/auth/login',
      {'email': email, 'password': password, if (register) 'full_name': name});
    api.token = result['access_token'];
    final me = await api.call('GET', '/me');
    api.tenant = me['personal_tenant_id']; api.name = me['full_name'];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('base', api.base); await prefs.setString('token', api.token!);
    setState(() {});
  }
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance(); await prefs.remove('token');
    setState(() { api.token = null; api.tenant = null; });
  }
  @override Widget build(BuildContext context) => MaterialApp(
    title: 'کارتابل', debugShowCheckedModeBanner: false,
    theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xff315c9a)),
    home: Directionality(textDirection: TextDirection.rtl,
      child: !ready ? const Scaffold(body: Center(child: CircularProgressIndicator()))
        : api.token == null ? LoginPage(api: api, onSubmit: login) : HomePage(api: api, onLogout: logout)),
  );
}

class LoginPage extends StatefulWidget {
  final Api api;
  final Future<void> Function(String, String, String, String, bool) onSubmit;
  const LoginPage({super.key, required this.api, required this.onSubmit});
  @override State<LoginPage> createState() => _LoginPageState();
}
class _LoginPageState extends State<LoginPage> {
  late final base = TextEditingController(text: widget.api.base);
  final email = TextEditingController(), password = TextEditingController(), name = TextEditingController();
  bool register = false, busy = false;
  @override Widget build(BuildContext context) => Scaffold(body: SafeArea(child: Center(
    child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440),
      child: ListView(shrinkWrap: true, padding: const EdgeInsets.all(24), children: [
        const Icon(Icons.assignment_turned_in_outlined, size: 60, color: Color(0xff315c9a)),
        const SizedBox(height: 12), Text('کارتابل', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineLarge),
        const Text('مدیریت پروژه و کارهای شما', textAlign: TextAlign.center), const SizedBox(height: 24),
        TextField(controller: base, textDirection: TextDirection.ltr, decoration: const InputDecoration(labelText: 'آدرس سرور API', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        if (register) ...[TextField(controller: name, decoration: const InputDecoration(labelText: 'نام و نام خانوادگی', border: OutlineInputBorder())), const SizedBox(height: 12)],
        TextField(controller: email, textDirection: TextDirection.ltr, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'ایمیل', border: OutlineInputBorder())),
        const SizedBox(height: 12), TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'رمز عبور', border: OutlineInputBorder())),
        const SizedBox(height: 20), FilledButton(onPressed: busy ? null : () async {
          setState(() => busy = true);
          try { await widget.onSubmit(base.text.trim(), email.text.trim(), password.text, name.text.trim(), register); }
          catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'.replaceFirst('Exception: ', '')))); }
          finally { if (mounted) setState(() => busy = false); }
        }, child: Text(busy ? 'لطفاً صبر کنید...' : register ? 'ساخت حساب' : 'ورود')),
        TextButton(onPressed: () => setState(() => register = !register), child: Text(register ? 'حساب دارم؛ ورود' : 'حساب ندارم؛ ثبت‌نام')),
      ])))));
}

class HomePage extends StatefulWidget {
  final Api api; final Future<void> Function() onLogout;
  const HomePage({super.key, required this.api, required this.onLogout});
  @override State<HomePage> createState() => _HomePageState();
}
class _HomePageState extends State<HomePage> {
  List<dynamic> projects = [], tasks = [];
  bool busy = true; String? error; int tab = 0;
  @override void initState() { super.initState(); refresh(); }
  Future<void> refresh() async {
    setState(() { busy = true; error = null; });
    try {
      final p = await widget.api.call('GET', widget.api.route('projects'));
      final t = await widget.api.call('GET', widget.api.route('tasks'));
      if (mounted) setState(() { projects = p; tasks = t; });
    } catch (e) { if (mounted) setState(() => error = '$e'); }
    finally { if (mounted) setState(() => busy = false); }
  }
  Future<String?> ask(String label) async {
    final c = TextEditingController();
    return showDialog<String>(context: context, builder: (context) => AlertDialog(title: Text(label),
      content: TextField(controller: c, autofocus: true), actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('انصراف')),
        FilledButton(onPressed: () => Navigator.pop(context, c.text.trim().isEmpty ? null : c.text.trim()), child: const Text('ثبت'))
      ]));
  }
  void showError(Object e) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))));
  Future<void> createProject() async {
    final name = await ask('نام پروژه'); if (name == null) return;
    try { await widget.api.call('POST', widget.api.route('projects'), {'name': name}); await refresh(); }
    catch (e) { showError(e); }
  }
  Future<void> createTask() async {
    if (projects.isEmpty) { showError('ابتدا یک پروژه بسازید'); return; }
    final title = await ask('عنوان وظیفه'); if (title == null) return;
    final project = await showDialog<String>(context: context, builder: (context) => SimpleDialog(
      title: const Text('پروژه را انتخاب کنید'),
      children: projects.map((p) => SimpleDialogOption(onPressed: () => Navigator.pop(context, p['id'] as String), child: Text(p['name'] as String))).toList(),
    ));
    if (project == null) return;
    try { await widget.api.call('POST', widget.api.route('tasks'), {'title': title, 'project_id': project}); await refresh(); }
    catch (e) { showError(e); }
  }
  String date(dynamic value) {
    final d = DateTime.tryParse(value?.toString() ?? ''); if (d == null) return 'بدون موعد';
    final j = Jalali.fromDateTime(d);
    return '${j.year}/${j.month.toString().padLeft(2, '0')}/${j.day.toString().padLeft(2, '0')}';
  }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('سلام ${widget.api.name ?? ''}'), actions: [IconButton(tooltip: 'خروج', onPressed: widget.onLogout, icon: const Icon(Icons.logout))]),
    body: busy ? const Center(child: CircularProgressIndicator()) :
      error != null ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(error!), TextButton(onPressed: refresh, child: const Text('تلاش دوباره'))])) :
      RefreshIndicator(onRefresh: refresh, child: ListView(padding: const EdgeInsets.all(16), children: [
        if (tab == 0) ...[
          Text('نمای کلی', style: Theme.of(context).textTheme.headlineSmall),
          Card(child: ListTile(title: const Text('کارهای باز'), trailing: Text('${tasks.where((t) => t['status'] != 'done').length}', style: Theme.of(context).textTheme.headlineMedium))),
          const SizedBox(height: 12)
        ],
        Text(tab == 1 ? 'پروژه‌ها' : 'وظایف', style: Theme.of(context).textTheme.titleLarge),
        if (tab == 1) ...projects.map((p) => Card(child: ListTile(leading: const Icon(Icons.folder_outlined), title: Text(p['name']), subtitle: Text(p['description'] ?? ''))))
        else ...tasks.map((t) => Card(child: ListTile(title: Text(t['title']), subtitle: Text('${date(t['due_date'])} • ${t['progress']}٪'),
          trailing: PopupMenuButton<String>(onSelected: (s) async {
            try { await widget.api.call('PATCH', '/tasks/${t['id']}?tenant_id=${widget.api.tenant}', {'status': s, 'progress': s == 'done' ? 100 : t['progress']}); await refresh(); }
            catch (e) { showError(e); }
          }, itemBuilder: (_) => const [
            PopupMenuItem(value: 'todo', child: Text('برای انجام')),
            PopupMenuItem(value: 'doing', child: Text('در حال انجام')),
            PopupMenuItem(value: 'done', child: Text('انجام شد')),
          ])))),
        if ((tab == 1 ? projects : tasks).isEmpty) const Padding(padding: EdgeInsets.all(24), child: Text('هنوز موردی ثبت نشده است.', textAlign: TextAlign.center)),
      ])),
    floatingActionButton: FloatingActionButton(onPressed: tab == 1 ? createProject : createTask, child: const Icon(Icons.add)),
    bottomNavigationBar: NavigationBar(selectedIndex: tab, onDestinationSelected: (i) => setState(() => tab = i),
      destinations: const [NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'داشبورد'),
        NavigationDestination(icon: Icon(Icons.folder_outlined), label: 'پروژه‌ها'),
        NavigationDestination(icon: Icon(Icons.task_alt), label: 'وظایف')]),
  );
}
