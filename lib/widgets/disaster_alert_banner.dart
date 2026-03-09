import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../models/disaster_model.dart';

/// Disaster Alert Banner - Shows active disaster warnings
class DisasterAlertBanner extends StatelessWidget {
  final List<DisasterAlert> alerts;
  final VoidCallback? onEmergencyTap;

  const DisasterAlertBanner({
    super.key,
    required this.alerts,
    this.onEmergencyTap,
  });

  @override
  Widget build(BuildContext context) {
    if (alerts.isEmpty) return const SizedBox.shrink();

    return Column(
      children: alerts.take(3).map((alert) {
        final color = _getAlertColor(alert);
        final icon = _getAlertIcon(alert.type);

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.4),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onEmergencyTap,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Alert Icon
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 12),
                    // Alert Text
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  alert.severity.toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  alert.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            alert.description,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 12,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Source: ${alert.source}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.white.withValues(alpha: 0.7),
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Color _getAlertColor(DisasterAlert alert) {
    switch (alert.severity) {
      case 'Extreme':
        return AppTheme.riskEmergency;
      case 'High':
        return AppTheme.riskVeryPoor;
      case 'Moderate':
        return AppTheme.riskPoor;
      default:
        return AppTheme.riskModerate;
    }
  }

  IconData _getAlertIcon(DisasterType type) {
    switch (type) {
      case DisasterType.flood:
        return Icons.flood;
      case DisasterType.cyclone:
        return Icons.cyclone;
      case DisasterType.heatwave:
        return Icons.whatshot;
      case DisasterType.wildfire:
        return Icons.local_fire_department;
      case DisasterType.earthquake:
        return Icons.vibration;
      case DisasterType.landslide:
        return Icons.landslide;
      case DisasterType.tsunami:
        return Icons.tsunami;
      case DisasterType.waterPollution:
        return Icons.water;
      case DisasterType.other:
        return Icons.warning_amber;
    }
  }
}
