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
    final visibleItems = items.take(4).toList();
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF172033),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: GridView.builder(
        itemCount: visibleItems.length,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 6,
          mainAxisSpacing: 6,
          childAspectRatio: 1.24,
        ),
        itemBuilder: (context, index) => _buildMetricTile(visibleItems[index]),
      ),
    );
  }

  Widget _buildMetricTile(StatItem it) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
      decoration: BoxDecoration(
        color: it.color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: it.color.withValues(alpha: .32)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(it.icon, size: 13, color: it.color),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              it.value,
              maxLines: 1,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: it.color,
              ),
            ),
          ),
          const SizedBox(height: 1),
          Text(
            it.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 8,
              color: Colors.white70,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class StatItem {
  final String title;
  final String value;
  final double progress;
  final Color color;
  final IconData icon;

  const StatItem({
    required this.title,
    required this.value,
    required this.progress,
    this.color = const Color(0xFF0F9D58),
    this.icon = Icons.insights,
  });

  factory StatItem.heart(String value, double progress) => StatItem(
        title: 'Pulso',
        value: value,
        progress: progress,
        color: const Color(0xFFEF4444),
        icon: Icons.favorite,
      );

  factory StatItem.oxygen(String value, double progress) => StatItem(
        title: 'SpO2',
        value: value,
        progress: progress,
        color: const Color(0xFF38BDF8),
        icon: Icons.water_drop,
      );

  factory StatItem.steps(String value, double progress) => StatItem(
        title: 'Pasos',
        value: value,
        progress: progress,
        color: const Color(0xFF22C55E),
        icon: Icons.directions_walk,
      );

  factory StatItem.temperature(String value, double progress) => StatItem(
        title: 'Temp.',
        value: value,
        progress: progress,
        color: const Color(0xFFF59E0B),
        icon: Icons.thermostat,
      );
}
