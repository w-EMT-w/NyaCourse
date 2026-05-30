import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/home_screen.dart';
import 'services/gdut_jw_client.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const GdutScheduleApp());
}

class GdutScheduleApp extends StatefulWidget {
  const GdutScheduleApp({super.key});

  @override
  State<GdutScheduleApp> createState() => _GdutScheduleAppState();
}

class _GdutScheduleAppState extends State<GdutScheduleApp> {
  final GdutJwClient _client = GdutJwClient();
  Color _themeSeed = const Color(0xff006b5b);
  ThemeMode _themeMode = ThemeMode.system;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NyaCourse',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: AppTheme.build(
        brightness: Brightness.light,
        seedColor: _themeSeed,
      ),
      darkTheme: AppTheme.build(
        brightness: Brightness.dark,
        seedColor: _themeSeed,
      ),
      home: HomeScreen(
        client: _client,
        themeSeed: _themeSeed,
        onThemeSeedChanged: (color) => setState(() => _themeSeed = color),
        themeMode: _themeMode,
        onThemeModeChanged: (mode) => setState(() => _themeMode = mode),
      ),
    );
  }
}
