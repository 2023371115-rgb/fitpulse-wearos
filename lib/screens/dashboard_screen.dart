import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../widgets/stats_widget.dart';
import '../widgets/round_watch_layout.dart';

const String _kBackendBase = 'http://10.0.2.2:3000';

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
  String? _error;
  bool _demoMode = false;
  Timer? _pollTimer;

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
          _deviceId = data.first['id'] as String;
          await _loadMetric();
          _startPolling();
        } else {
          _useDemoMetrics();
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
      _latestMetric = _Metric(
        heartRate: 72,
        steps: 5284,
        spo2: 98,
        temperature: 36.5,
        recordedAt: DateTime.now(),
      );
    });
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
