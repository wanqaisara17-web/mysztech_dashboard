import 'package:flutter/material.dart';

import 'core/api/pos_api_service.dart';
import 'features/dashboard/screens/app_shell.dart';

class PosMonitoringApp extends StatelessWidget {
  const PosMonitoringApp({super.key});

  static const _green = Color(0xFF17834B);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mysztech Store Assistant',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _green,
          primary: _green,
          surface: const Color(0xFFF6F8F6),
        ),
        scaffoldBackgroundColor: const Color(0xFFF6F8F6),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF6F8F6),
          surfaceTintColor: Colors.transparent,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFFE9EEEA)),
          ),
        ),
      ),
      home: AppShell(apiService: PosApiService()),
    );
  }
}
