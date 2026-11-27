import 'package:material_ui/material_ui.dart';

import '../../core/models.dart';
import '../../shared/strings.dart';

class WeatherSummary extends StatelessWidget {
  const WeatherSummary({super.key, required this.weather});
  final Json weather;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Wrap(
        spacing: 18,
        runSpacing: 12,
        children: [
          for (final (key, unit, label, icon) in [
            (
              'temperatureC',
              '°C',
              context.tr('Temperature', 'Nhiệt độ'),
              Icons.thermostat_outlined,
            ),
            (
              'precipitationProbabilityPercent',
              '%',
              context.tr('Rain chance', 'Khả năng mưa'),
              Icons.water_drop_outlined,
            ),
            (
              'windSpeedKmh',
              'km/h',
              context.tr('Wind', 'Gió'),
              Icons.air_outlined,
            ),
          ])
            if (weather[key] case final num value)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                  Text(
                    '$value $unit',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  Text(
                    label,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
        ],
      ),
    );
  }
}
