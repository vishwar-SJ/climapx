import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/theme.dart';
import '../../models/weather_model.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Weather & Heat Risk Card Widget
class WeatherCard extends StatelessWidget {
  final WeatherData? data;

  const WeatherCard({super.key, this.data});

  @override
  Widget build(BuildContext context) {
    if (data == null) {
      return Shimmer.fromColors(
        baseColor: Colors.grey.shade300,
        highlightColor: Colors.grey.shade100,
        child: Container(
          height: 180,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      );
    }

    // Show a proper "unavailable" card when using fallback data
    if (data!.cityName == 'Unavailable' || data!.description == 'Data unavailable') {
      return Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.grey.shade50,
          ),
          child: Column(
            children: [
              Icon(Icons.cloud_off, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              Text(
                'Weather Data Unavailable',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Could not fetch weather data. Pull down to refresh.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final heatColor = AppTheme.getHeatColor(data!.temperature);
    final isHeatRisk = data!.heatRisk != HeatRiskLevel.safe;
    final isFloodRisk = data!.floodRisk != FloodRiskLevel.safe;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isHeatRisk
                ? [AppTheme.heatwave.withValues(alpha: 0.1), Colors.white]
                : isFloodRisk
                    ? [AppTheme.flood.withValues(alpha: 0.1), Colors.white]
                    : [Colors.blue.shade50, Colors.white],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                CachedNetworkImage(
                  imageUrl: data!.weatherIconUrl,
                  width: 50,
                  height: 50,
                  errorWidget: (_, __, ___) =>
                      const Icon(Icons.wb_sunny, size: 50, color: Colors.orange),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data!.cityName,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        data!.description.toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${data!.temperature.toStringAsFixed(0)}°C',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: heatColor,
                      ),
                    ),
                    Text(
                      'Feels ${data!.feelsLike.toStringAsFixed(0)}°C',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Weather Stats Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _statItem(Icons.water_drop, '${data!.humidity.toStringAsFixed(0)}%', 'Humidity'),
                _statItem(Icons.air, '${data!.windSpeed.toStringAsFixed(1)} m/s', 'Wind'),
                _statItem(Icons.visibility, '${(data!.visibility / 1000).toStringAsFixed(1)} km', 'Visibility'),
                _statItem(Icons.compress, '${data!.pressure.toStringAsFixed(0)} hPa', 'Pressure'),
              ],
            ),
            // Heat Risk Warning
            if (isHeatRisk) ...[
              const SizedBox(height: 16),
              _riskBanner(
                icon: Icons.whatshot,
                title: 'HEAT ${data!.heatRisk.name.toUpperCase()}',
                message: data!.heatAdvice,
                color: AppTheme.heatwave,
              ),
            ],
            // Flood Risk Warning
            if (isFloodRisk) ...[
              const SizedBox(height: 12),
              _riskBanner(
                icon: Icons.flood,
                title: 'FLOOD ${data!.floodRisk.name.toUpperCase()}',
                message: data!.floodAdvice,
                color: AppTheme.flood,
              ),
            ],
            // Rainfall Info
            if (data!.rain1h > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.grain, color: Colors.blue, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Rainfall: ${data!.rain1h.toStringAsFixed(1)} mm/hr',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue,
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

  Widget _statItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade700),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _riskBanner({
    required IconData icon,
    required String title,
    required String message,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: color,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(fontSize: 12, color: color, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
