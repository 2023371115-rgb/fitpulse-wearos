import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// Servicio de Autenticación por PIN optimizado para Smartwatches.
/// Forzado a 4 dígitos para una UX fluida y sin botones de confirmación estorbosos.
class PinAuthService {
  PinAuthService._internal();
  static final PinAuthService instance = PinAuthService._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  final LocalAuthentication _localAuth = LocalAuthentication();

  static const _kPinHashKey = 'pin_hash_v1';
  static const _kPinSaltKey = 'pin_salt_v1';
  static const _kFailedAttemptsKey = 'pin_failed_attempts';
  static const _kLockUntilKey = 'pin_lock_until';

  // En un reloj el margen de error táctil es alto. 
  // Mantener los 5 intentos es buena idea, pero bajamos el bloqueo base a 15s.
  static const int maxAttempts = 5;
  static const Duration baseLockout = Duration(seconds: 15);

  /// ¿Ya existe un PIN configurado en este dispositivo?
  Future<bool> hasPin() async {
    final hash = await _storage.read(key: _kPinHashKey);
    return hash != null && hash.isNotEmpty;
  }

  String _generateSalt([int length = 16]) {
    final rand = Random.secure();
    final bytes = List<int>.generate(length, (_) => rand.nextInt(256));
    return base64Url.encode(bytes);
  }

  String _hashPin(String pin, String salt) {
    final bytes = utf8.encode('$salt::$pin');
    return sha256.convert(bytes).toString();
  }

  /// Valida formato: Exclusivamente 4 dígitos para agilizar el auto-envío del reloj.
  bool isValidPinFormat(String pin) {
    return RegExp(r'^\d{4}$').hasMatch(pin);
  }

  /// Crea o reemplaza el PIN. Solo se guarda hash + salt.
  Future<void> setPin(String pin) async {
    if (!isValidPinFormat(pin)) {
      throw ArgumentError('El PIN debe tener exactamente 4 dígitos numéricos en reloj');
    }
    final salt = _generateSalt();
    final hash = _hashPin(pin, salt);
    await _storage.write(key: _kPinSaltKey, value: salt);
    await _storage.write(key: _kPinHashKey, value: hash);
    await _resetAttempts();
  }

  /// Verifica el PIN ingresado contra el hash almacenado.
  Future<PinVerifyResult> verifyPin(String pin) async {
    final lockUntil = await _getLockUntil();
    if (lockUntil != null && DateTime.now().isBefore(lockUntil)) {
      return PinVerifyResult(
        success: false,
        lockedUntil: lockUntil,
      );
    }

    final storedHash = await _storage.read(key: _kPinHashKey);
    final salt = await _storage.read(key: _kPinSaltKey);
    if (storedHash == null || salt == null) {
      return PinVerifyResult(success: false, error: 'No hay PIN');
    }

    final candidateHash = _hashPin(pin, salt);
    final ok = _constantTimeEquals(candidateHash, storedHash);

    if (ok) {
      await _resetAttempts();
      return PinVerifyResult(success: true);
    }

    final attempts = await _incrementAttempts();
    if (attempts >= maxAttempts) {
      // Bloqueo con backoff exponencial. El primer bloqueo será de 15 segundos.
      final multiplier = 1 << (attempts - maxAttempts).clamp(0, 5);
      final lockDuration = baseLockout * multiplier;
      final until = DateTime.now().add(lockDuration);
      await _storage.write(key: _kLockUntilKey, value: until.toIso8601String());
      return PinVerifyResult(success: false, lockedUntil: until, attemptsLeft: 0);
    }

    return PinVerifyResult(success: false, attemptsLeft: maxAttempts - attempts);
  }

  bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }

  Future<int> _incrementAttempts() async {
    final current = int.tryParse(await _storage.read(key: _kFailedAttemptsKey) ?? '0') ?? 0;
    final next = current + 1;
    await _storage.write(key: _kFailedAttemptsKey, value: next.toString());
    return next;
  }

  Future<void> _resetAttempts() async {
    await _storage.write(key: _kFailedAttemptsKey, value: '0');
    await _storage.delete(key: _kLockUntilKey);
  }

  Future<DateTime?> _getLockUntil() async {
    final raw = await _storage.read(key: _kLockUntilKey);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  /// Elimina el PIN.
  Future<void> clearPin() async {
    await _storage.delete(key: _kPinHashKey);
    await _storage.delete(key: _kPinSaltKey);
    await _resetAttempts();
  }

  // ---------------- Biometría ----------------

  Future<bool> isBiometricAvailable() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      return canCheck && isSupported;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticateWithBiometrics() async {
    try {
      return await _localAuth.authenticate(
        // Razón súper corta por si el sistema operativo del reloj decide mostrarla en un cuadro mini
        localizedReason: 'Desbloquear FitPulse',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}

class PinVerifyResult {
  final bool success;
  final int? attemptsLeft;
  final DateTime? lockedUntil;
  final String? error;

  PinVerifyResult({
    required this.success,
    this.attemptsLeft,
    this.lockedUntil,
    this.error,
  });
}