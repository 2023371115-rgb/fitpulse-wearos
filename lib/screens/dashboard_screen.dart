import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
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
  String? _deviceId;
  _Metric? _latestMetric;
  bool _loading = false;
  bool _sending = false;
  String? _error;
  bool _demoMode = false;
  String _status = 'Listo para sincronizar';
  Timer? _pollTimer;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _initDashboard();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _initDashboard() async {
    setState(() { _loading = true; _error = null; _demoMode = false; });
    try {
      if (widget.token.trim().isEmpty) {
        _useDemoMetrics();
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
      _useDemoMetrics();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _useDemoMetrics() {
    if (!mounted) return;
    setState(() {
      _error = null;
      _demoMode = true;
      _status = 'Demo local sin token';
      _latestMetric = _Metric(
        heartRate: 72,
        steps: 5284,
        spo2: 98,
        temperature: 36.5,
        recordedAt: DateTime.now(),
      );
    });
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
    final now = DateTime.now();
    final currentSteps = _latestMetric?.steps ?? 1200;
    final metric = _Metric(
      heartRate: kind == 'pasos' ? (_latestMetric?.heartRate ?? 72) : 68 + _random.nextInt(34),
      steps: kind == 'pulso' ? currentSteps : currentSteps + 200 + _random.nextInt(900),
      spo2: 96 + _random.nextInt(4),
      temperature: 36.1 + (_random.nextInt(8) / 10),
      recordedAt: now,
    );

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
          _status = kind == 'pulso' ? 'Pulso enviado a FitPulse' : 'Pasos enviados a FitPulse';
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
                    const SizedBox(height: 4),
                    
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
