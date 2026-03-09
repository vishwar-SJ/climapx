import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../core/theme.dart';
import '../providers/climate_provider.dart';
import '../models/disaster_model.dart';

/// Alerts Screen - Dedicated alert history & notifications center
class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ClimateProvider>(
      builder: (context, provider, child) {
        return RefreshIndicator(
          onRefresh: () => provider.refreshAllData(),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // Quick Risk Summary
              SliverToBoxAdapter(
                child: _buildRiskSummary(provider),
              ),

              // Active Alerts Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.warning_amber_rounded,
                            color: Colors.red.shade700, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Active Alerts',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: provider.activeAlerts.isNotEmpty
                              ? Colors.red.shade50
                              : Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${provider.activeAlerts.length} active',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: provider.activeAlerts.isNotEmpty
                                ? Colors.red.shade700
                                : Colors.green.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Alert Items
              if (provider.activeAlerts.isEmpty)
                SliverFillRemaining(
                  child: _buildNoAlerts(),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final alert = provider.activeAlerts[index];
                      return _AlertCard(alert: alert, index: index);
                    },
                    childCount: provider.activeAlerts.length,
                  ),
                ),

              // Current Conditions Section
              SliverToBoxAdapter(
                child: _buildCurrentConditions(provider),
              ),

              const SliverToBoxAdapter(
                child: SizedBox(height: 100),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRiskSummary(ClimateProvider provider) {
    final aqi = provider.airQuality?.aqi ?? 0;
    final temp = provider.weather?.temperature ?? 25.0;
    final rain = provider.weather?.rain1h ?? 0;
    final score = provider.exposureScore?.totalScore ?? 0;
    final scoreColor = AppTheme.getRiskColor(score);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            scoreColor.withValues(alpha: 0.08),
            Colors.white,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scoreColor.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics_outlined, color: scoreColor, size: 22),
              const SizedBox(width: 8),
              Text(
                'Environment Status',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade800,
                ),
              ),
              const Spacer(),
              if (provider.lastUpdated != null)
                Text(
                  DateFormat('HH:mm').format(provider.lastUpdated!),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _miniStat('AQI', aqi.toString(), AppTheme.getAqiColor(aqi)),
              _miniStat('Temp', '${temp.toStringAsFixed(0)}°', AppTheme.getHeatColor(temp)),
              _miniStat('Rain', '${rain.toStringAsFixed(1)}mm', AppTheme.flood),
              _miniStat('Risk', score.toStringAsFixed(0), scoreColor),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _miniStat(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoAlerts() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_circle_outline,
                size: 50, color: Colors.green.shade400),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scale(
                begin: const Offset(1, 1),
                end: const Offset(1.05, 1.05),
                duration: 2.seconds,
              ),
          const SizedBox(height: 20),
          Text(
            'All Clear! 🌿',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.green.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No active disaster alerts in your area.\nStay safe, stay aware.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentConditions(ClimateProvider provider) {
    final conditions = <_ConditionItem>[];

    // AQI Condition
    final aqi = provider.airQuality?.aqi ?? 0;
    if (aqi > 100) {
      conditions.add(_ConditionItem(
        icon: Icons.air,
        title: 'Poor Air Quality',
        description: 'AQI is $aqi — ${AppTheme.getAqiLabel(aqi)}. Consider wearing a mask outdoors.',
        color: AppTheme.getAqiColor(aqi),
        severity: aqi > 300 ? 'High' : 'Moderate',
      ));
    }

    // Heat Condition
    final temp = provider.weather?.temperature ?? 25.0;
    if (temp > 35) {
      conditions.add(_ConditionItem(
        icon: Icons.whatshot,
        title: 'Heat Advisory',
        description: 'Temperature is ${temp.toStringAsFixed(0)}°C. Stay hydrated, avoid direct sunlight.',
        color: AppTheme.getHeatColor(temp),
        severity: temp > 42 ? 'High' : 'Moderate',
      ));
    }

    // Flood Condition
    final rain = provider.weather?.rain1h ?? 0;
    if (rain > 15) {
      conditions.add(_ConditionItem(
        icon: Icons.flood,
        title: 'Heavy Rainfall Warning',
        description: 'Rainfall at ${rain.toStringAsFixed(1)}mm/hr. Possible waterlogging.',
        color: AppTheme.flood,
        severity: rain > 65 ? 'High' : 'Moderate',
      ));
    }

    if (conditions.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.info_outline,
                    color: Colors.orange.shade700, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Condition Advisories',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
        ),
        ...conditions.map((c) => _ConditionCard(item: c)),
      ],
    );
  }
}

class _AlertCard extends StatelessWidget {
  final DisasterAlert alert;
  final int index;

  const _AlertCard({required this.alert, required this.index});

  @override
  Widget build(BuildContext context) {
    final color = _getColor();
    final icon = _getIcon();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [color, color.withValues(alpha: 0.85)],
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showAlertDetails(context),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
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
                              const Spacer(),
                              Text(
                                DateFormat('dd MMM, HH:mm')
                                    .format(alert.timestamp),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            alert.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  alert.description,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 13,
                    height: 1.4,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.source,
                        color: Colors.white.withValues(alpha: 0.6), size: 14),
                    const SizedBox(width: 4),
                    Text(
                      alert.source,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 11,
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.location_on,
                        color: Colors.white.withValues(alpha: 0.6), size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '${alert.lat.toStringAsFixed(2)}, ${alert.lng.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(delay: (index * 100).ms, duration: 400.ms).slideX(begin: 0.1, end: 0);
  }

  void _showAlertDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Icon(_getIcon(), color: _getColor(), size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    alert.title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: _getColor(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              alert.description,
              style: const TextStyle(fontSize: 14, height: 1.6),
            ),
            const SizedBox(height: 20),
            _detailRow('Severity', alert.severity),
            _detailRow('Type', alert.type.name.toUpperCase()),
            _detailRow('Source', alert.source),
            _detailRow('Time', DateFormat('dd MMMM yyyy, HH:mm').format(alert.timestamp)),
            _detailRow('Location', '${alert.lat.toStringAsFixed(4)}, ${alert.lng.toStringAsFixed(4)}'),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Color _getColor() {
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

  IconData _getIcon() {
    switch (alert.type) {
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

class _ConditionItem {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final String severity;

  const _ConditionItem({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.severity,
  });
}

class _ConditionCard extends StatelessWidget {
  final _ConditionItem item;

  const _ConditionCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: item.color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: item.color.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Icon(item.icon, color: item.color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: item.color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              item.severity,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: item.color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
