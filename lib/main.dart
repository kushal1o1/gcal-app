import 'package:flutter/material.dart';

import 'screens/root_screen.dart';
import 'services/settings_store.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SettingsStore.instance.load();
  runApp(const GcalApp());
}

class GcalApp extends StatelessWidget {
  const GcalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'gcal',
      debugShowCheckedModeBanner: false,
      theme: buildGcalTheme(Brightness.light),
      darkTheme: buildGcalTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: const RootScreen(),
    );
  }
}