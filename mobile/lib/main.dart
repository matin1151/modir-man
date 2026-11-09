import 'package:flutter/material.dart';

void main() => runApp(const KartabelApp());

class KartabelApp extends StatelessWidget {
  const KartabelApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'کارتابل', debugShowCheckedModeBanner: false,
    locale: const Locale('fa'),
    theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xff315c9a), fontFamily: 'Vazirmatn'),
    home: const DashboardPage(),
  );
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});
  @override
  Widget build(BuildContext context) => Directionality(textDirection: TextDirection.rtl, child: Scaffold(
    appBar: AppBar(title: const Text('کارتابل'), actions: [IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_none))]),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      Text('سلام، آماده‌ای؟', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 6), const Text('نمای کلی کارهای امروز و تیم شما'),
      const SizedBox(height: 20),
      Row(children: [Expanded(child: _Stat(title: 'در حال انجام', value: '۸')), const SizedBox(width: 10), Expanded(child: _Stat(title: 'عقب‌افتاده', value: '۲'))]),
      const SizedBox(height: 20),
      Text('وظایف نزدیک', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      const _Task(title: 'بازبینی متن صفحه فرود', project: 'پروژه وب‌سایت', progress: 0.7),
      const _Task(title: 'تحویل سفارش مشتری', project: 'سفارش #۱۲۴', progress: 0.35),
    ]),
    bottomNavigationBar: const NavigationBar(selectedIndex: 0, destinations: [NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'داشبورد'), NavigationDestination(icon: Icon(Icons.folder_outlined), label: 'پروژه‌ها'), NavigationDestination(icon: Icon(Icons.task_alt), label: 'وظایف'), NavigationDestination(icon: Icon(Icons.groups_outlined), label: 'تیم')]),
  ));
}
class _Stat extends StatelessWidget { final String title, value; const _Stat({required this.title, required this.value}); @override Widget build(BuildContext c) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title), const SizedBox(height: 8), Text(value, style: Theme.of(c).textTheme.headlineMedium)]))); }
class _Task extends StatelessWidget { final String title, project; final double progress; const _Task({required this.title, required this.project, required this.progress}); @override Widget build(BuildContext c) => Card(child: ListTile(title: Text(title), subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(project), const SizedBox(height: 8), LinearProgressIndicator(value: progress)]), trailing: const Icon(Icons.chevron_left))); }
