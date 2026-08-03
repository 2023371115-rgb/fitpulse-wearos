import 'package:flutter/material.dart';

/// WearableLinkWidget - permite enlazar FitPulse con un wearable o Smart TV.
///
/// Widgets del catálogo Flutter usados:
///   - DropdownButtonFormField  (catálogo: Input & selections)
///   - Card, ElevatedButton     (catálogo: Material components)
///   - LinearProgressIndicator  (catálogo: Progress indicators)
///   - SingleChildScrollView    (catálogo: Scrolling)
///
/// Parámetros:
///   siteUrl: URL del sitio web (FitPulse) que se enlazará al dispositivo.
class WearableLinkWidget extends StatefulWidget {
  final String siteUrl;
  const WearableLinkWidget({super.key, required this.siteUrl});

  @override
  State<WearableLinkWidget> createState() => _WearableLinkWidgetState();
}

class _WearableLinkWidgetState extends State<WearableLinkWidget> {
  /// Lista de dispositivos wearable/smart TV simulados.
  /// En producción reemplazar con una llamada HTTP al backend.
  final List<Map<String, String>> _devices = [
    {'id': 'w-001', 'name': 'Smartwatch (Wear OS)'},
    {'id': 'w-002', 'name': 'Galaxy Watch'},
    {'id': 'tv-001', 'name': 'Smart TV Sala (Android TV)'},
    {'id': 'tv-002', 'name': 'Smart TV Habitación'},
  ];

  String? _selectedId;
  String _status = 'Esperando acción';
  bool _pairing = false;
  final List<String> _log = [];

  Future<void> _pair() async {
    if (_selectedId == null) return;
    final name = _devices.firstWhere((d) => d['id'] == _selectedId)['name']!;
    setState(() {
      _pairing = true;
      _status = 'Iniciando enlace con "$name"...';
      _log.insert(0, _status);
    });
    await Future.delayed(const Duration(milliseconds: 1200));
    setState(() {
      _log.insert(0, 'Código de emparejamiento generado');
      _status = 'Autenticando...';
    });
    await Future.delayed(const Duration(milliseconds: 1200));
    setState(() {
      _pairing = false;
      _status = '✔ "$name" enlazado con ${widget.siteUrl}';
      _log.insert(0, _status);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Dispositivo destino',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _selectedId,
              hint: const Text('Selecciona un wearable o Smart TV'),
              items: _devices
                  .map((d) => DropdownMenuItem(
                      value: d['id'], child: Text(d['name']!)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedId = v),
              decoration: InputDecoration(
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
            const SizedBox(height: 12),
            if (_pairing) const LinearProgressIndicator(),
            if (!_pairing)
              ElevatedButton.icon(
                onPressed: _selectedId == null ? null : _pair,
                icon: const Icon(Icons.link, size: 16),
                label: const Text('Enlazar con FitPulse'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F9D58),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            const SizedBox(height: 10),
            Text('Estado: $_status',
                style: const TextStyle(fontSize: 12, color: Colors.black87)),
            if (_log.isNotEmpty) ...[
              const Divider(height: 20),
              const Text('Registro',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              SizedBox(
                height: 80,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _log
                        .map((e) => Text(e,
                            style: const TextStyle(
                                fontSize: 11, color: Colors.black54)))
                        .toList(),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
