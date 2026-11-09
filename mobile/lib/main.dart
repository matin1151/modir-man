import 'package:flutter/material.dart';
import 'data/local_repository.dart';
import 'ui/home.dart';

void main() => runApp(const ModirManApp());

class ModirManApp extends StatelessWidget {
  const ModirManApp({super.key});
  @override Widget build(BuildContext context) => MaterialApp(
    title: 'مدیر من', debugShowCheckedModeBanner: false,
    theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xff245d67),
      brightness: Brightness.light, fontFamily: 'Vazirmatn'),
    darkTheme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xff78bbc0),
      brightness: Brightness.dark, fontFamily: 'Vazirmatn'),
    themeMode: ThemeMode.system,
    home: Directionality(textDirection: TextDirection.rtl, child: HomePage(repo: LocalRepository())),
  );
}
