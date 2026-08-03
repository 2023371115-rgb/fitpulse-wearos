import 'dart:async';
import 'package:flutter/widgets.dart';

/// Administra el ciclo de vida de la sesión "desbloqueada" de la app en Smartwatches.
///
/// Reglas estrictas de Wearable:
///  - Tras autenticarse (PIN o biometría) la sesión queda activa por [sessionTimeout].
///  - Cualquier interacción del usuario en la pantalla debe llamar a [keepAlive].
///  - Al girar la muñeca, apagar la pantalla o salir de la app, el sistema operativo
///    pasa el ciclo de vida a segundo plano. La sesión se invalida de forma inmediata
///    para evitar accesos no autorizados a datos de salud.
class SessionManager extends ChangeNotifier with WidgetsBindingObserver {
  
  // Implementación Singleton para garantizar que solo exista un gestor de sesión
  // y evitar observadores de ciclo de vida duplicados en el motor de Flutter.
  factory SessionManager({Duration sessionTimeout = const Duration(minutes: 3)}) {
    _instance ??= SessionManager._internal(sessionTimeout);
    return _instance!;
  }

  SessionManager._internal(this.sessionTimeout) {
    WidgetsBinding.instance.addObserver(this);
  }

  static SessionManager? _instance;

  final Duration sessionTimeout;

  bool _unlocked = false;
  Timer? _timer;
  String? _authToken; // JWT de sesión de cuenta (no confundir con el PIN local)

  bool get isUnlocked => _unlocked;
  String? get authToken => _authToken;

  void unlock({String? token}) {
    _unlocked = true;
    _authToken = token ?? _authToken;
    _resetTimer();
    notifyListeners();
  }

  /// Debe llamarse ante cualquier interacción del usuario (onTap, drag, scrolls)
  /// en las vistas protegidas para extender el tiempo de vida de la sesión actual.
  void keepAlive() {
    if (_unlocked) _resetTimer();
  }

  void _resetTimer() {
    _timer?.cancel();
    _timer = Timer(sessionTimeout, _expire);
  }

  void _expire() {
    if (_unlocked) {
      _timer?.cancel();
      _unlocked = false;
      notifyListeners();
    }
  }

  void logout() {
    _timer?.cancel();
    _unlocked = false;
    _authToken = null;
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // En smartwatches, 'inactive' o 'hidden' ocurren instantáneamente al bajar la muñeca 
    // o cuando entra la carátula del reloj (modo ambiente/ambient mode). 
    // Bloqueamos inmediatamente en cualquiera de estos escenarios de pérdida de foco.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _expire();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    if (_instance == this) _instance = null;
    super.dispose();
  }
}