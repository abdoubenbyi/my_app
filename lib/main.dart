import 'package:flutter/material.dart';
import 'screens/catalogue_screen.dart';
import 'utils/theme_utils.dart';
import 'utils/ad_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await adService.init();
  runApp(const DevSheetsApp());
}

class DevSheetsApp extends StatefulWidget {
  const DevSheetsApp({super.key});

  @override
  State<DevSheetsApp> createState() => _DevSheetsAppState();
}

class _DevSheetsAppState extends State<DevSheetsApp> {
  ThemeMode _themeMode = ThemeMode.system;

  void toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.dark
          ? ThemeMode.light
          : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DevSheets',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: CatalogueScreen(onThemeToggle: toggleTheme),
    );
  }
}
