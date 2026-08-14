import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../widgets/stats_widget.dart';
import '../widgets/round_watch_layout.dart';

const String _kBackendBase = String.fromEnvironment(
  'FITPULSE_API_URL',
  defaultValue: 'https://fitpulse-backend-r77o.onrender.com',
);

class _Metric {
  final int? heartRate;
  final int? steps;
  final int? spo2;
  final double? temperature;
  final DateTime recordedAt;

  _Metric({this.heartRate, this.steps, this.spo2, this.temperature, required this.recordedAt});

  factory _Metric.fromJson(Map<String, dynamic> j) => _Metric(
        heartRate: j['heart_rate'] as int?,
        steps: j['steps'] as int?,
        spo2: j['spo2'] as int?,
        temperature: j['temperature'] != null ? double.tryParse(j['temperature'].toString()) : null,
        recordedAt: DateTime.tryParse(j['recorded_at'] ?? '') ?? DateTime.now(),
      );
}

class DashboardScreen extends StatefulWidget {
  final VoidCallback onLogout;
  final String token; // El token ahora se inyecta desde la sesión ya existente

  const DashboardScreen({super.key, required this.onLogout, required this.token});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _deviceIdKey = 'fitpulse_device_id';
  static const _deviceTokenKey = 'fitpulse_device_token';
  static const _deviceNameKey = 'fitpulse_device_name';

  final TextEditingController _pairCodeController = TextEditingController();
  String? _deviceId;
  String? _deviceToken;
  String? _deviceName;
  _Metric? _latestMetric;
  bool _loading = false;
  bool _sending = false;
  bool _pairing = false;
  String? _error;
  bool _demoMode = false;
  String _status = 'Listo para sincronizar';
  Timer? _pollTimer;
  Timer? _autoSendTimer;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _initDashboard();
  }

  @override
  void dispose() {
    _pairCodeController.dispose();
    _pollTimer?.cancel();
    _autoSendTimer?.cancel();
    super.dispose();
  }

  Future<void> _initDashboard() async {
    setState(() { _loading = true; _error = null; _demoMode = false; });
    try {
      await _loadPairedDevice();
      if (_deviceId != null && _deviceToken != null) {
        _useDemoMetrics(status: 'Sensores simulados');
        await _sendMetric(kind: 'auto');
        _startAutoSync();
        return;
      }

      if (widget.token.trim().isEmpty) {
        _useDemoMetrics(status: 'Enlaza con codigo web');
        return;
      }
      // Simplificado: Obtenemos el primer dispositivo directamente sin dropdowns
      final res = await http.get(
        Uri.parse('$_kBackendBase/api/devices'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body) as List<dynamic>;
        if (data.isNotEmpty) {
          final wearable = data.cast<Map<String, dynamic>?>().firstWhere(
            (item) => item?['type'] == 'wearable',
            orElse: () => data.first as Map<String, dynamic>,
          );
          _deviceId = wearable?['id'] as String?;
          await _loadMetric();
          _startPolling();
        } else {
          await _registerWearable();
          await _sendMetric(kind: 'conexion');
        }
      } else {
        setState(() => _error = 'Error ${res.statusCode}');
      }
    } catch (e) {
      // ignore: avoid_print
      print('FITPULSE_ERROR: $e');
      _useDemoMetrics(status: 'Demo local sin conexion');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadPairedDevice() async {
    _deviceId = await _storage.read(key: _deviceIdKey);
    _deviceToken = await _storage.read(key: _deviceTokenKey);
    _deviceName = await _storage.read(key: _deviceNameKey);
  }

  Future<void> _savePairedDevice({
    required String deviceId,
    required String deviceToken,
    required String deviceName,
  }) async {
    await _storage.write(key: _deviceIdKey, value: deviceId);
    await _storage.write(key: _deviceTokenKey, value: deviceToken);
    await _storage.write(key: _deviceNameKey, value: deviceName);
    _deviceId = deviceId;
    _deviceToken = deviceToken;
    _deviceName = deviceName;
  }

  Future<void> _clearPairedDevice() async {
    _autoSendTimer?.cancel();
    await _storage.delete(key: _deviceIdKey);
    await _storage.delete(key: _deviceTokenKey);
    await _storage.delete(key: _deviceNameKey);
    setState(() {
      _deviceId = null;
      _deviceToken = null;
      _deviceName = null;
      _status = 'Enlaza con codigo web';
    });
  }

  void _useDemoMetrics({String status = 'Demo local'}) {
    if (!mounted) return;
    setState(() {
      _error = null;
      _demoMode = true;
      _status = status;
      _latestMetric = _Metric(
        heartRate: 72,
        steps: 5284,
        spo2: 98,
        temperature: 36.5,
        recordedAt: DateTime.now(),
      );
    });
  }

  Future<void> _pairWithCode() async {
    final code = _pairCodeController.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() => _status = 'Codigo de 6 digitos');
      return;
    }

    setState(() {
      _pairing = true;
      _status = 'Enlazando reloj...';
    });

    try {
      final res = await http.post(
        Uri.parse('$_kBackendBase/api/devices/pair'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'code': code}),
      );

      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode}');
      }

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      await _savePairedDevice(
        deviceId: data['deviceId'] as String,
        deviceToken: data['deviceToken'] as String,
        deviceName: data['name'] as String? ?? 'FitPulse Wear OS',
      );
      _pairCodeController.clear();
      setState(() {
        _demoMode = false;
        _status = 'Reloj enlazado';
      });
      await _sendMetric(kind: 'auto');
      _startAutoSync();
    } catch (_) {
      setState(() => _status = 'Codigo vencido o incorrecto');
    } finally {
      if (mounted) setState(() => _pairing = false);
    }
  }

  Future<void> _registerWearable() async {
    final res = await http.post(
      Uri.parse('$_kBackendBase/api/devices'),
      headers: {
        'Authorization': 'Bearer ${widget.token}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'name': 'FitPulse Wear OS',
        'type': 'wearable',
      }),
    );

    if (res.statusCode == 201) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      _deviceId = data['id'] as String?;
      setState(() => _status = 'Wearable registrado');
    } else {
      throw Exception('No se pudo registrar wearable: ${res.statusCode}');
    }
  }

  Future<void> _sendMetric({required String kind}) async {
    if (_sending && kind == 'auto') return;
    final now = DateTime.now();
    final currentSteps = _latestMetric?.steps ?? 1200;
    final metric = _Metric(
      heartRate: kind == 'pasos' ? (_latestMetric?.heartRate ?? 72) : 68 + _random.nextInt(34),
      steps: kind == 'pulso' ? currentSteps : currentSteps + 60 + _random.nextInt(180),
      spo2: 96 + _random.nextInt(4),
      temperature: 36.1 + (_random.nextInt(8) / 10),
      recordedAt: now,
    );

    if (_deviceId != null && _deviceToken != null) {
      setState(() {
        _sending = true;
        _status = 'Enviando ${kind == 'pulso' ? 'pulso' : 'pasos'}...';
      });

      try {
        final res = await http.post(
          Uri.parse('$_kBackendBase/api/devices/$_deviceId/metrics'),
          headers: {
            'Authorization': 'Bearer $_deviceToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'heart_rate': metric.heartRate,
            'steps': metric.steps,
            'spo2': metric.spo2,
            'temperature': metric.temperature,
            'extra': {
              'source': 'wear_os_pair_code',
              'kind': kind,
            },
          }),
        );

        if (res.statusCode == 201) {
          setState(() {
            _demoMode = false;
            _latestMetric = metric;
            _status = kind == 'auto'
                ? 'Sincronizando cada 5s'
                : kind == 'pulso'
                    ? 'Pulso enviado'
                    : 'Pasos enviados';
          });
        } else if (res.statusCode == 401 || res.statusCode == 409 || res.statusCode == 404) {
          await _clearPairedDevice();
          setState(() {
            _demoMode = false;
            _latestMetric = null;
            _status = 'Reloj desenlazado';
          });
        } else {
          throw Exception('HTTP ${res.statusCode}');
        }
      } catch (_) {
        setState(() {
          _demoMode = true;
          _latestMetric = metric;
          _status = 'Demo local: sin backend';
        });
      } finally {
        if (mounted) setState(() => _sending = false);
      }
      return;
    }

    if (widget.token.trim().isEmpty || _deviceId == null) {
      setState(() {
        _demoMode = true;
        _latestMetric = metric;
        _status = kind == 'pulso' ? 'Pulso demo generado' : 'Pasos demo generados';
      });
      return;
    }

    setState(() {
      _sending = true;
      _status = 'Enviando ${kind == 'pulso' ? 'pulso' : 'pasos'}...';
    });

    try {
      final res = await http.post(
        Uri.parse('$_kBackendBase/api/devices/$_deviceId/metrics/user'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'heart_rate': metric.heartRate,
          'steps': metric.steps,
          'spo2': metric.spo2,
          'temperature': metric.temperature,
          'extra': {
            'source': 'wear_os_demo',
            'kind': kind,
          },
        }),
      );

        if (res.statusCode == 201) {
          setState(() {
            _demoMode = false;
            _latestMetric = metric;
            _status = kind == 'auto'
                ? 'Sincronizando cada 5s'
                : kind == 'pulso'
                    ? 'Pulso enviado a FitPulse'
                    : 'Pasos enviados a FitPulse';
          });
        } else {
        throw Exception('HTTP ${res.statusCode}');
      }
    } catch (e) {
      setState(() {
        _demoMode = true;
        _latestMetric = metric;
        _status = 'Demo local: backend no disponible';
      });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Widget _buildPairingCard() {
    final paired = _deviceId != null && _deviceToken != null;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF172033),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF0F9D58).withValues(alpha: .4)),
      ),
      child: paired
          ? Column(
              children: [
                const Icon(Icons.watch, color: Color(0xFF0F9D58), size: 18),
                const SizedBox(height: 4),
                Text(
                  _deviceName ?? 'Wear OS enlazado',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                ),
                TextButton(
                  onPressed: _clearPairedDevice,
                  child: const Text('Cambiar', style: TextStyle(fontSize: 10)),
                ),
              ],
            )
          : Column(
              children: [
                const Text(
                  'Codigo web',
                  style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _pairCodeController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 18, letterSpacing: 4, fontWeight: FontWeight.w900),
                  decoration: InputDecoration(
                    counterText: '',
                    isDense: true,
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _pairing ? null : _pairWithCode,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0F9D58),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      textStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
                    ),
                    child: Text(_pairing ? 'Enlazando...' : 'Enlazar'),
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _loadMetric() async {
    if (_deviceId == null) return;
    try {
      final res = await http.get(
        Uri.parse('$_kBackendBase/api/devices/$_deviceId/metrics/latest'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      if (res.statusCode == 200 && res.body != 'null') {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        setState(() => _latestMetric = _Metric.fromJson(data));
      }
    } catch (_) {}
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 1), (_) => _loadMetric());
  }

  void _startAutoSync() {
    _autoSendTimer?.cancel();
    if (_deviceId == null || _deviceToken == null) return;
    _autoSendTimer = Timer.periodic(const Duration(seconds: 5), (_) => _sendMetric(kind: 'auto'));
  }

  List<StatItem> get _statItems {
    if (_latestMetric == null) return [];
    return [
      if (_latestMetric!.heartRate != null)
        StatItem(title: 'Frecuencia', value: '${_latestMetric!.heartRate} bpm', progress: ((_latestMetric!.heartRate ?? 0) / 200).clamp(0.0, 1.0).toDouble()),
      if (_latestMetric!.spo2 != null)
        StatItem(title: 'SpO2', value: '${_latestMetric!.spo2}%', progress: ((_latestMetric!.spo2 ?? 0) / 100).clamp(0.0, 1.0).toDouble()),
      if (_latestMetric!.steps != null)
        StatItem(title: 'Pasos', value: '${_latestMetric!.steps}', progress: ((_latestMetric!.steps ?? 0) / 10000).clamp(0.0, 1.0).toDouble()),
      if (_latestMetric!.temperature != null)
        StatItem(title: 'Temp.', value: '${_latestMetric!.temperature} C', progress: (((_latestMetric!.temperature ?? 36) - 35) / 5).clamp(0.0, 1.0).toDouble()),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Fondo oscuro ideal para ahorrar batería en pantallas OLED
      body: RoundWatchLayout(
        paddingFactor: 0.075,
        child: _loading 
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F9D58)))
          : _error != null
            ? Center(child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)))
            : RefreshIndicator(
                onRefresh: _loadMetric,
                color: const Color(0xFF0F9D58),
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                  children: [
                    // Cabecera compacta integrada en el scroll
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.favorite, color: Color(0xFF0F9D58), size: 12),
                        SizedBox(width: 4),
                        Text('FitPulse', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_demoMode) ...[
                      Container(
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F9D58).withValues(alpha: .16),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: const Color(0xFF0F9D58).withValues(alpha: .55)),
                        ),
                        child: const Text(
                          'Demo sin conexion',
                          style: TextStyle(color: Color(0xFF86EFAC), fontSize: 9, fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Center(
                      child: Text(
                        _status,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 9, color: Colors.white54, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildPairingCard(),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            onPressed: _sending ? null : () => _sendMetric(kind: 'pulso'),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFEF4444),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              textStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
                            ),
                            child: const Text('Pulso'),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: FilledButton(
                            onPressed: _sending ? null : () => _sendMetric(kind: 'pasos'),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF0F9D58),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              textStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
                            ),
                            child: const Text('Pasos'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Lista de métricas en formato compacto para reloj
                    if (_latestMetric != null) ...[
                      StatsWidget(items: _statItems),
                      const SizedBox(height: 6),
                      Center(
                        child: Text(
                          'Act: ${_latestMetric!.recordedAt.toLocal().toString().substring(11, 16)}',
                          style: const TextStyle(fontSize: 9, color: Colors.white38),
                        ),
                      ),
                    ] else
                      const Center(
                        child: Text('Sin datos', style: TextStyle(color: Colors.white30, fontSize: 11))
                      ),
                    
                    // Botón de salir discreto al final del scroll para no estorbar
                    Center(
                      child: IconButton(
                        icon: const Icon(Icons.logout, color: Colors.white38, size: 16),
                        onPressed: () {
                          _pollTimer?.cancel();
                          widget.onLogout();
                        },
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
