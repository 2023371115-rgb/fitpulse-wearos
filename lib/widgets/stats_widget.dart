import 'package:flutter/material.dart';

/// StatsWidget - muestra tarjetas de métricas para el dashboard de FitPulse.
///
/// Uso:
///   StatsWidget(items: [
///     StatItem(title: 'Archivos', value: '12', progress: 0.6),
///   ])
class StatsWidget extends StatelessWidget {
  final List<StatItem> items;
  const StatsWidget({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth.clamp(120.0, 180.0).toDouble();

        return Wrap(
          alignment: WrapAlignment.center,
          spacing: 6,
          runSpacing: 6,
          children: items.map((it) => _buildCard(context, it, cardWidth)).toList(),
        );
      },
    );
  }

  Widget _buildCard(BuildContext context, StatItem it, double width) {
    return SizedBox(
      width: width,
      child: Card(
        elevation: 2,
        color: const Color(0xFF172033),
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(it.title,
                  style: const TextStyle(fontSize: 10, color: Colors.white54)),
              const SizedBox(height: 3),
              Text(it.value,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    color: Color(0xFF0F9D58))),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: it.progress,
                  minHeight: 4,
                  backgroundColor: Colors.white12,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(Color(0xFF0F9D58)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StatItem {
  final String title;
  final String value;
  final double progress; // 0.0 - 1.0
  const StatItem(
      {required this.title, required this.value, required this.progress});
}
