import 'dart:async';

import 'package:flutter/material.dart';

import 'core/api/pos_api_service.dart';
import 'core/local/local_workspace.dart';
import 'core/models/authenticated_user.dart';
import 'core/notifications/low_stock_notification_service.dart';
import 'features/dashboard/screens/app_shell.dart';
import 'features/auth/screens/login_screen.dart';

class PosMonitoringApp extends StatefulWidget {
  const PosMonitoringApp({
    super.key,
    this.apiService,
    this.notificationService,
  });

  final PosApiService? apiService;
  final LowStockNotificationService? notificationService;

  @override
  State<PosMonitoringApp> createState() => _PosMonitoringAppState();
}

class _PosMonitoringAppState extends State<PosMonitoringApp> {
  late final PosApiService _apiService = widget.apiService ?? PosApiService();
  late final LowStockNotificationService _notificationService =
      widget.notificationService ?? LowStockNotificationService();
  late final LocalWorkspace _localWorkspace = LocalWorkspace()..load();
  AuthenticatedUser? _user;
  LowStockNotificationTarget? _notificationTarget;
  LowStockNotificationTarget? _queuedNotificationTarget;
  LowStockNotificationTarget? _queuedHandledTarget;
  bool _notificationTapFrameScheduled = false;
  bool _handledFrameScheduled = false;
  bool _ignoreTapsUntilAuthentication = false;
  int _notificationLifecycleGeneration = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_notificationService.initialize(_onNotificationTap));
  }

  void _onAuthenticated(AuthenticatedUser user) {
    _ignoreTapsUntilAuthentication = false;
    _notificationService.resume();
    setState(() => _user = user);
  }

  void _onNotificationTap(LowStockNotificationTarget target) {
    if (!mounted ||
        (_ignoreTapsUntilAuthentication && _user == null) ||
        _sameTarget(_notificationTarget, target) ||
        _sameTarget(_queuedNotificationTarget, target)) {
      return;
    }
    _queuedNotificationTarget = target;
    if (_notificationTapFrameScheduled) return;
    _notificationTapFrameScheduled = true;
    final generation = _notificationLifecycleGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (generation != _notificationLifecycleGeneration) return;
      _notificationTapFrameScheduled = false;
      if (!mounted) return;
      final queued = _queuedNotificationTarget;
      _queuedNotificationTarget = null;
      if (queued == null || _sameTarget(_notificationTarget, queued)) return;
      setState(() => _notificationTarget = queued);
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  void _onNotificationTargetHandled(LowStockNotificationTarget target) {
    if (!mounted ||
        !_sameTarget(_notificationTarget, target) ||
        _sameTarget(_queuedHandledTarget, target)) {
      return;
    }
    _queuedHandledTarget = target;
    if (_handledFrameScheduled) return;
    _handledFrameScheduled = true;
    final generation = _notificationLifecycleGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (generation != _notificationLifecycleGeneration) return;
      _handledFrameScheduled = false;
      final handled = _queuedHandledTarget;
      _queuedHandledTarget = null;
      if (!mounted ||
          handled == null ||
          !_sameTarget(_notificationTarget, handled)) {
        return;
      }
      setState(() => _notificationTarget = null);
    });
  }

  bool _sameTarget(
    LowStockNotificationTarget? left,
    LowStockNotificationTarget? right,
  ) =>
      left != null &&
      right != null &&
      left.accountIdentity == right.accountIdentity &&
      left.outletId == right.outletId;

  void _reauthenticate() {
    _apiService.setToken('');
    _notificationLifecycleGeneration++;
    _notificationTapFrameScheduled = false;
    _handledFrameScheduled = false;
    _queuedNotificationTarget = null;
    _queuedHandledTarget = null;
    _notificationTarget = null;
    _ignoreTapsUntilAuthentication = true;
    unawaited(_notificationService.cancelAll());
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
              authenticatedUser: _user,
              notificationService: _notificationService,
              notificationTarget: _notificationTarget,
              onNotificationTargetHandled: _onNotificationTargetHandled,
            ),
    );
  }
}
