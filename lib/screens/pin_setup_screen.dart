import 'package:flutter/material.dart';

import '../auth/pin_auth_service.dart';
import '../widgets/pin_keypad.dart';
import '../widgets/round_watch_layout.dart';

/// Configuracion del PIN optimizada para pantallas redondas de smartwatch.
class PinSetupScreen extends StatefulWidget {
  final VoidCallback onDone;

  const PinSetupScreen({super.key, required this.onDone});

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

enum _Step { choosePin, confirmPin }

class _PinSetupScreenState extends State<PinSetupScreen> {
  _Step _step = _Step.choosePin;
  String _firstPin = '';
  String _current = '';
  String? _error;
  bool _saving = false;

  void _onDigit(String d) {
    if (_saving || _current.length >= 4) return;

    setState(() {
      _current += d;
      _error = null;
    });

    if (_current.length == 4) {
      _processPinWorkflow();
    }
  }

  void _onBackspace() {
    if (_current.isEmpty || _saving) return;
    setState(() => _current = _current.substring(0, _current.length - 1));
  }

  Future<void> _processPinWorkflow() async {
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;

    if (_step == _Step.choosePin) {
      if (!PinAuthService.instance.isValidPinFormat(_current)) {
        setState(() {
          _error = 'PIN invalido';
          _current = '';
        });
        return;
      }
      setState(() {
        _firstPin = _current;
        _current = '';
        _step = _Step.confirmPin;
        _error = null;
      });
      return;
    }

    if (_current != _firstPin) {
      setState(() {
        _current = '';
        _error = 'No coincide';
        _step = _Step.choosePin;
        _firstPin = '';
      });
      return;
    }

    setState(() => _saving = true);
    await PinAuthService.instance.setPin(_current);
    if (!mounted) return;
    setState(() => _saving = false);
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final title = _step == _Step.choosePin ? 'Crea PIN' : 'Confirma';

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: RoundWatchLayout(
        paddingFactor: 0.075,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 22,
              child: Center(
                child: _saving
                    ? const SizedBox.square(
                        dimension: 15,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F9D58)),
                      )
                    : Icon(
                        _step == _Step.choosePin ? Icons.lock_outline : Icons.check_circle_outline,
                        color: const Color(0xFF0F9D58),
                        size: 16,
                      ),
              ),
            ),
            Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            PinDots(length: _current.length),
            SizedBox(
              height: 13,
              child: Center(
                child: Text(
                  _error ?? '',
                  style: const TextStyle(color: Colors.redAccent, fontSize: 9, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            Flexible(
              child: Opacity(
                opacity: _saving ? 0.5 : 1.0,
                child: NumericKeypad(
                  onDigit: _onDigit,
                  onBackspace: _onBackspace,
                  disabled: _saving,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
