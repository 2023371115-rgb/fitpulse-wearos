import 'package:flutter/material.dart';

import '../auth/pin_auth_service.dart';
import '../widgets/pin_keypad.dart';
import '../widgets/round_watch_layout.dart';

/// Pantalla de desbloqueo optimizada para relojes redondos.
class LoginScreen extends StatefulWidget {
  final void Function() onUnlocked;

  const LoginScreen({super.key, required this.onUnlocked});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String _pin = '';
  String? _message;
  bool _checking = false;
  bool _biometricAvailable = false;
  DateTime? _lockedUntil;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    final available = await PinAuthService.instance.isBiometricAvailable();
    if (mounted) setState(() => _biometricAvailable = available);
    if (available) _tryBiometric();
  }

  Future<void> _tryBiometric() async {
    final ok = await PinAuthService.instance.authenticateWithBiometrics();
    if (ok) widget.onUnlocked();
  }

  Future<void> _submitPin() async {
    setState(() {
      _checking = true;
      _message = null;
    });
    final result = await PinAuthService.instance.verifyPin(_pin);

    if (!mounted) return;
    setState(() => _checking = false);

    if (result.success) {
      widget.onUnlocked();
      return;
    }

    setState(() {
      _pin = '';
      if (result.lockedUntil != null) {
        _lockedUntil = result.lockedUntil;
        _message = 'Bloqueado';
      } else {
        _message = result.attemptsLeft != null ? 'Error (${result.attemptsLeft} disp)' : 'PIN incorrecto';
      }
    });
  }

  void _onDigit(String d) {
    if (_lockedUntil != null && DateTime.now().isBefore(_lockedUntil!)) return;
    if (_pin.length >= 4) return;

    setState(() {
      _pin += d;
      _message = null;
    });

    if (_pin.length == 4) {
      _submitPin();
    }
  }

  void _onBackspace() {
    if (_pin.isEmpty || _checking) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final locked = _lockedUntil != null && DateTime.now().isBefore(_lockedUntil!);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: RoundWatchLayout(
        paddingFactor: 0.075,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 24,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.favorite, color: Color(0xFF0F9D58), size: 13),
                      SizedBox(width: 4),
                      Text(
                        'FitPulse',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ],
                  ),
                  if (_biometricAvailable)
                    Align(
                      alignment: Alignment.centerRight,
                      child: SizedBox.square(
                        dimension: 24,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          onPressed: _tryBiometric,
                          icon: const Icon(Icons.fingerprint, color: Color(0xFF0F9D58), size: 17),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            PinDots(length: _pin.length),
            SizedBox(
              height: 14,
              child: Center(
                child: _checking
                    ? const SizedBox.square(
                        dimension: 10,
                        child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white54),
                      )
                    : Text(
                        _message ?? '',
                        style: const TextStyle(color: Colors.redAccent, fontSize: 9, fontWeight: FontWeight.w500),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
              ),
            ),
            Flexible(
              child: NumericKeypad(
                onDigit: _onDigit,
                onBackspace: _onBackspace,
                disabled: locked || _checking,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
