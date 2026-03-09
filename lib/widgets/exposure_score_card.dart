import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/theme.dart';
import '../../models/exposure_model.dart';

/// Exposure Score Card - Personal Climate Health Score Display
class ExposureScoreCard extends StatelessWidget {
  final ExposureScore? score;
  final VoidCallback? onTap;

  const ExposureScoreCard({super.key, this.score, this.onTap});

  @override
  Widget build(BuildContext context) {
    if (score == null) {
      return Shimmer.fromColors(
        baseColor: Colors.grey.shade300,
        highlightColor: Colors.grey.shade100,
        child: Container(
          height: 200,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      );
    }

    // Check if all component scores are essentially zero (no real data)
    final bool hasRealData = score!.aqiScore > 0 ||
        score!.heatScore > 0 ||
        score!.floodScore > 0 ||
        score!.wildfireScore > 0 ||
        score!.waterScore > 0;

    final color = AppTheme.getRiskColor(score!.totalScore);

    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withValues(alpha: 0.15),
                Colors.white,
                Colors.white,
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.shield, color: color, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Personal Exposure Score',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          score!.levelText,
                          style: TextStyle(
                            fontSize: 13,
                            color: color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Score circle
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: color, width: 3),
                      color: color.withValues(alpha: 0.1),
                    ),
                    child: Center(
                      child: Text(
                        score!.totalScore.toStringAsFixed(0),
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: color,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Risk Breakdown Bars
              _riskBar('Air Pollution', score!.aqiScore, AppTheme.airPollution),
              const SizedBox(height: 8),
              _riskBar('Heat Stress', score!.heatScore, AppTheme.heatwave),
              const SizedBox(height: 8),
              _riskBar('Flood Risk', score!.floodScore, AppTheme.flood),
              const SizedBox(height: 8),
              _riskBar('Wildfire', score!.wildfireScore, AppTheme.wildfire),
              const SizedBox(height: 8),
              _riskBar('Water Quality', score!.waterScore, AppTheme.waterPollution),
              if (!hasRealData) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.orange.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Waiting for live data. Pull down to refresh.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              // Recommendations
              const Text(
                'Recommendations',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              ...score!.recommendations.take(3).map(
                (rec) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    rec,
                    style: const TextStyle(fontSize: 13, height: 1.4),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _riskBar(String label, double value, Color color) {
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (value / 100).clamp(0.0, 1.0),
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 8,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 30,
          child: Text(
            value.toStringAsFixed(0),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
