import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/climate_provider.dart';
import '../../core/theme.dart';
import '../../widgets/aqi_gauge_card.dart';
import '../../widgets/weather_card.dart';
import '../../widgets/exposure_score_card.dart';
import '../../widgets/disaster_alert_banner.dart';
import '../../services/location_service.dart';
import 'journey_planner_screen.dart';

/// Dashboard Screen - Professional climate safety overview
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ClimateProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return _buildShimmerLoading();
        }

        // Show error/location prompt if there's an issue
        if (provider.errorMessage != null && provider.lastUpdated == null) {
          return _buildErrorState(context, provider);
        }

        return RefreshIndicator(
          onRefresh: () => provider.refreshAllData(),
          color: AppTheme.primaryGreen,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Location warning banner (if using default location)
                if (!provider.locationReady)
                  _buildLocationWarning(context, provider)
                      .animate()
                      .fadeIn(duration: 300.ms),

                // Error banner (non-blocking)
                if (provider.errorMessage != null && provider.lastUpdated != null)
                  _buildErrorBanner(provider)
                      .animate()
                      .fadeIn(duration: 300.ms),

                // Last Updated & Location
                if (provider.lastUpdated != null)
                  _buildStatusBar(provider)
                      .animate()
                      .fadeIn(duration: 300.ms),
                const SizedBox(height: 12),

                // Disaster Alerts (if any)
                if (provider.activeAlerts.isNotEmpty) ...[
                  _sectionHeader(context, '🚨 Active Alerts', Colors.red),
                  const SizedBox(height: 8),
                  DisasterAlertBanner(
                    alerts: provider.activeAlerts,
                    onEmergencyTap: () {},
                  ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.05, end: 0),
                  const SizedBox(height: 20),
                ],

                // Exposure Score
                _sectionHeader(context, '🛡️ Your Safety Score', Colors.green.shade800),
                const SizedBox(height: 8),
                ExposureScoreCard(score: provider.exposureScore)
                    .animate()
                    .fadeIn(delay: 100.ms, duration: 400.ms)
                    .slideY(begin: 0.05, end: 0),
                const SizedBox(height: 20),

                // Journey Advisory
                _buildJourneyAdvisory(provider)
                    .animate()
                    .fadeIn(delay: 200.ms, duration: 400.ms)
                    .slideY(begin: 0.05, end: 0),
                const SizedBox(height: 20),

                // Journey Planner CTA
                _buildJourneyPlannerCta(context)
                    .animate()
                    .fadeIn(delay: 250.ms, duration: 400.ms)
                    .slideY(begin: 0.05, end: 0),
                const SizedBox(height: 20),

                // Air Quality
                _sectionHeader(context, '🌫️ Air Quality', Colors.blueGrey),
                const SizedBox(height: 8),
                AqiGaugeCard(data: provider.airQuality)
                    .animate()
                    .fadeIn(delay: 300.ms, duration: 400.ms)
                    .slideY(begin: 0.05, end: 0),
                const SizedBox(height: 20),

                // Weather & Heat/Flood
                _sectionHeader(context, '🌤️ Weather Conditions', Colors.blue),
                const SizedBox(height: 8),
                WeatherCard(data: provider.weather)
                    .animate()
                    .fadeIn(delay: 400.ms, duration: 400.ms)
                    .slideY(begin: 0.05, end: 0),
                const SizedBox(height: 20),

                // Daily Tips
                _sectionHeader(context, '💡 Climate Safety Tips', Colors.amber.shade800),
                const SizedBox(height: 8),
                _buildDailyTips(provider)
                    .animate()
                    .fadeIn(delay: 500.ms, duration: 400.ms)
                    .slideY(begin: 0.05, end: 0),
                const SizedBox(height: 20),

                // Emergency Numbers
                _buildEmergencyNumbers(context)
                    .animate()
                    .fadeIn(delay: 600.ms, duration: 400.ms)
                    .slideY(begin: 0.05, end: 0),
                const SizedBox(height: 30),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusBar(ClimateProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.5),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Updated ${_formatTime(provider.lastUpdated!)}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          if (provider.currentPosition != null) ...[
            Icon(Icons.location_on, size: 14, color: Colors.grey.shade500),
            const SizedBox(width: 2),
            Text(
              '${provider.latitude.toStringAsFixed(3)}, ${provider.longitude.toStringAsFixed(3)}',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildJourneyPlannerCta(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const JourneyPlannerScreen()),
        );
      },
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.primaryGreen.withValues(alpha: 0.08),
                AppTheme.accentTeal.withValues(alpha: 0.05),
                Colors.white,
              ],
            ),
            border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.route, color: AppTheme.primaryGreen, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Plan Safe Journey',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primaryDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Get pollution-optimized routes & best departure time',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildJourneyAdvisory(ClimateProvider provider) {
    final score = provider.exposureScore?.totalScore ?? 0;
    final aqi = provider.airQuality?.aqi ?? 0;
    final temp = provider.weather?.temperature ?? 25;

    // Determine journey safety
    String journeyStatus;
    String journeyAdvice;
    IconData journeyIcon;
    Color journeyColor;
    String? delayUntil;

    if (score >= 75 || aqi > 400 || temp > 45) {
      journeyStatus = '🚫 UNSAFE TO TRAVEL';
      journeyAdvice = 'Extremely hazardous conditions. Delay all non-essential travel.';
      journeyIcon = Icons.do_not_disturb;
      journeyColor = AppTheme.riskEmergency;
      delayUntil = _suggestDelay(temp, aqi);
    } else if (score >= 50 || aqi > 200 || temp > 40) {
      journeyStatus = '⚠️ Travel with Caution';
      journeyAdvice = 'Conditions are risky. Use AC transport, carry water & mask.';
      journeyIcon = Icons.warning_amber;
      journeyColor = AppTheme.riskPoor;
      delayUntil = _suggestDelay(temp, aqi);
    } else if (score >= 25 || aqi > 100 || temp > 35) {
      journeyStatus = '🟡 Moderate Risk';
      journeyAdvice = 'Carry a mask, stay hydrated, avoid prolonged outdoor exposure.';
      journeyIcon = Icons.info_outline;
      journeyColor = AppTheme.riskModerate;
    } else {
      journeyStatus = '✅ Safe to Travel';
      journeyAdvice = 'Conditions are favorable. Enjoy your journey safely!';
      journeyIcon = Icons.check_circle_outline;
      journeyColor = AppTheme.riskGood;
    }

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            colors: [journeyColor.withValues(alpha: 0.08), Colors.white],
          ),
          border: Border.all(color: journeyColor.withValues(alpha: 0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: journeyColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(journeyIcon, color: journeyColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Journey Advisory',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        journeyStatus,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: journeyColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              journeyAdvice,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
                height: 1.4,
              ),
            ),
            if (delayUntil != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: journeyColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: journeyColor.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.schedule, color: journeyColor, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '⏰ Suggested delay: $delayUntil',
                        style: TextStyle(
                          fontSize: 12,
                          color: journeyColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String? _suggestDelay(double temp, int aqi) {
    final hour = DateTime.now().hour;

    if (temp > 40 && hour >= 10 && hour <= 16) {
      return 'Wait until after 5:00 PM when temperatures drop';
    }
    if (aqi > 300) {
      return 'AQI may improve by early morning (5-7 AM)';
    }
    if (temp > 35 && hour >= 11 && hour <= 15) {
      return 'Avoid travel between 11 AM - 4 PM (peak heat hours)';
    }
    return null;
  }

  Widget _sectionHeader(BuildContext context, String title, Color color) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 22,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }

  /// Full-screen error state when initialization failed and no data loaded
  Widget _buildErrorState(BuildContext context, ClimateProvider provider) {
    final bool isGpsOff = LocationService.lastServiceDisabled;
    final bool isDeniedForever = LocationService.lastDeniedForever;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: isGpsOff
                    ? Colors.orange.shade50
                    : Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isGpsOff ? Icons.location_off : Icons.error_outline,
                size: 50,
                color: isGpsOff ? Colors.orange : Colors.red.shade400,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              isGpsOff
                  ? 'Location Services Disabled'
                  : isDeniedForever
                      ? 'Location Permission Required'
                      : 'Unable to Load Data',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.grey.shade800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              provider.errorMessage ?? 'Something went wrong.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                if (isDeniedForever) {
                  LocationService.openAppSettings();
                } else if (isGpsOff) {
                  LocationService.openLocationSettings();
                }
                Future.delayed(const Duration(seconds: 2), () {
                  provider.retryLocation();
                });
              },
              icon: Icon(
                isGpsOff
                    ? Icons.location_on
                    : isDeniedForever
                        ? Icons.settings
                        : Icons.refresh,
              ),
              label: Text(
                isGpsOff
                    ? 'Enable GPS'
                    : isDeniedForever
                        ? 'Open Settings'
                        : 'Retry',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => provider.retryLocation(),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry Now'),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primaryGreen,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'ClimapX needs your location to show live weather, air quality, and safety alerts for your area.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade700,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Warning banner when using default location
  Widget _buildLocationWarning(BuildContext context, ClimateProvider provider) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.location_off, color: Colors.orange.shade700, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Using default location (Delhi). Enable GPS for your area data.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.orange.shade800,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          SizedBox(
            height: 30,
            child: TextButton(
              onPressed: () => provider.retryLocation(),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                foregroundColor: Colors.orange.shade800,
              ),
              child: const Text('Enable', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }

  /// Non-blocking error banner (data loaded but there's a note)
  Widget _buildErrorBanner(ClimateProvider provider) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: Colors.amber.shade800),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              provider.errorMessage!,
              style: TextStyle(fontSize: 11, color: Colors.amber.shade900),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status bar shimmer
            Container(
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(height: 20),
            // Score card shimmer
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            const SizedBox(height: 20),
            // Journey advisory shimmer
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            const SizedBox(height: 20),
            // AQI card shimmer
            Container(
              height: 280,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            const SizedBox(height: 20),
            // Weather card shimmer
            Container(
              height: 180,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyTips(ClimateProvider provider) {
    final tips = _generateTips(provider);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: tips.map((tip) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tip['icon']!, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tip['title']!,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          tip['desc']!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  List<Map<String, String>> _generateTips(ClimateProvider provider) {
    final List<Map<String, String>> tips = [];
    final aqi = provider.airQuality?.aqi ?? 0;
    final temp = provider.weather?.temperature ?? 25;

    if (aqi > 200) {
      tips.add({
        'icon': '😷',
        'title': 'Wear N95 Mask',
        'desc': 'AQI is $aqi. Use N95/KN95 mask when going outside.',
      });
    }

    if (temp > 38) {
      tips.add({
        'icon': '💧',
        'title': 'Stay Hydrated',
        'desc': 'Drink water every 20 mins. Carry ORS. Avoid 11 AM - 4 PM outdoor activity.',
      });
    }

    tips.add({
      'icon': '🌿',
      'title': 'Use Indoor Plants',
      'desc': 'Snake plants, peace lilies help purify indoor air naturally.',
    });

    tips.add({
      'icon': '📱',
      'title': 'Keep ClimapX Active',
      'desc': 'Enable notifications for real-time alerts and safe guidance.',
    });

    return tips;
  }

  Widget _buildEmergencyNumbers(BuildContext context) {
    final numbers = [
      {'name': 'National Emergency', 'number': '112', 'icon': '🚨'},
      {'name': 'NDMA Helpline', 'number': '1078', 'icon': '⛑️'},
      {'name': 'Ambulance', 'number': '108', 'icon': '🚑'},
      {'name': 'Fire Service', 'number': '101', 'icon': '🚒'},
      {'name': 'Police', 'number': '100', 'icon': '🚔'},
      {'name': 'Flood Control', 'number': '1070', 'icon': '🌊'},
    ];

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📞 Emergency Numbers (India)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: numbers.map((n) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.shade100),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(n['icon']!, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            n['name']!,
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                          Text(
                            n['number']!,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
}
