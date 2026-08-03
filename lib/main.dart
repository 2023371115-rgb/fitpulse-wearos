import 'package:flutter/material.dart';
import 'auth/pin_auth_service.dart';
import 'auth/session_manager.dart';
import 'screens/pin_setup_screen.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FitPulse Health Dashboard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F9D58)),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

/// Controla el flujo: crear PIN (primera vez) -> login (PIN/biometría) ->
/// pantalla principal protegida. Escucha [SessionManager] para regresar
/// automáticamente al login si la sesión expira o la app pasa a segundo plano.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final SessionManager _session = SessionManager();
  bool _loadingPinState = true;
  bool _hasPin = false;

  @override
  void initState() {
    super.initState();
    _session.addListener(_onSessionChanged);
    _checkPin();
  }

  Future<void> _checkPin() async {
    final has = await PinAuthService.instance.hasPin();
    setState(() {
      _hasPin = has;
      _loadingPinState = false;
    });
  }

  void _onSessionChanged() => setState(() {});

  @override
  void dispose() {
    _session.removeListener(_onSessionChanged);
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingPinState) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_hasPin) {
      return PinSetupScreen(onDone: () => setState(() => _hasPin = true));
    }

    if (!_session.isUnlocked) {
      return LoginScreen(onUnlocked: () => _session.unlock());
    }

    // Pantalla principal protegida: cualquier toque renueva la sesión.
    return Listener(
  onPointerDown: (_) => _session.keepAlive(),
  child: DashboardScreen(
    onLogout: _session.logout,
    token: const String.fromEnvironment('FITPULSE_TOKEN'),
  ),
);
  }
}
