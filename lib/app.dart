import 'package:flutter/material.dart';

import 'core/api/pos_api_service.dart';
import 'core/local/local_workspace.dart';
import 'core/models/authenticated_user.dart';
import 'features/dashboard/screens/app_shell.dart';
import 'features/auth/screens/login_screen.dart';

class PosMonitoringApp extends StatefulWidget {
  const PosMonitoringApp({super.key, this.apiService});

  final PosApiService? apiService;

  @override
  State<PosMonitoringApp> createState() => _PosMonitoringAppState();
}

class _PosMonitoringAppState extends State<PosMonitoringApp> {
  late final PosApiService _apiService = widget.apiService ?? PosApiService();
  late final LocalWorkspace _localWorkspace = LocalWorkspace()..load();
  AuthenticatedUser? _user;

  void _onAuthenticated(AuthenticatedUser user) => setState(() => _user = user);

  void _reauthenticate() {
    _apiService.setToken('');
    setState(() => _user = null);
  }

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
      home: _user == null
          ? LoginScreen(
              apiService: _apiService,
              onAuthenticated: _onAuthenticated,
            )
          : AppShell(
              apiService: _apiService,
              onReauthenticate: _reauthenticate,
              localWorkspace: _localWorkspace,
            ),
    );
  }
}
