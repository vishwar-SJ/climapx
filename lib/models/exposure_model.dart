/// Exposure Score Model - Personal Climate Health Score
class ExposureScore {
  final double totalScore;        // 0-100, higher = more danger
  final double aqiScore;          // Air pollution component
  final double heatScore;         // Heat stress component
  final double floodScore;        // Flood risk component
  final double wildfireScore;     // Wildfire risk component
  final double waterScore;        // Water pollution component
  final ExposureLevel level;
  final List<String> recommendations;
  final DateTime timestamp;

  ExposureScore({
    required this.totalScore,
    required this.aqiScore,
    required this.heatScore,
    required this.floodScore,
    required this.wildfireScore,
    required this.waterScore,
    required this.level,
    required this.recommendations,
    required this.timestamp,
  });

  factory ExposureScore.calculate({
    required int aqi,
    required double temperature,
    required double rainfall,
    required bool wildfireNearby,
    required bool waterContamination,
  }) {
    // Normalize each factor to 0-100
    final aqiNorm = (aqi / 500 * 100).clamp(0.0, 100.0);
    final heatNorm = temperature < 30 ? 0.0 : ((temperature - 30) / 20 * 100).clamp(0.0, 100.0);
    final floodNorm = (rainfall / 100 * 100).clamp(0.0, 100.0);
    final fireNorm = wildfireNearby ? 80.0 : 0.0;
    final waterNorm = waterContamination ? 70.0 : 0.0;

    // Weighted total
    final total = (aqiNorm * 0.35) +
                  (heatNorm * 0.25) +
                  (floodNorm * 0.20) +
                  (fireNorm * 0.10) +
                  (waterNorm * 0.10);

    final level = _getLevel(total);
    final recommendations = _getRecommendations(
      aqi: aqi,
      temp: temperature,
      rain: rainfall,
      fire: wildfireNearby,
      water: waterContamination,
      totalScore: total,
    );

    return ExposureScore(
      totalScore: total,
      aqiScore: aqiNorm,
      heatScore: heatNorm,
      floodScore: floodNorm,
      wildfireScore: fireNorm,
      waterScore: waterNorm,
      level: level,
      recommendations: recommendations,
      timestamp: DateTime.now(),
    );
  }

  static ExposureLevel _getLevel(double score) {
    if (score < 20) return ExposureLevel.safe;
    if (score < 40) return ExposureLevel.low;
    if (score < 60) return ExposureLevel.moderate;
    if (score < 80) return ExposureLevel.high;
    return ExposureLevel.critical;
  }

  static List<String> _getRecommendations({
    required int aqi,
    required double temp,
    required double rain,
    required bool fire,
    required bool water,
    required double totalScore,
  }) {
    final List<String> recs = [];

    if (totalScore > 60) {
      recs.add('⚠️ Consider delaying your journey. High overall risk detected.');
    }

    if (aqi > 200) {
      recs.add('🫁 Wear N95 mask outdoors. AQI is $aqi (${aqi > 300 ? "Very Poor" : "Poor"}).');
      recs.add('🏠 Prefer indoor activities. Use air purifier if available.');
    } else if (aqi > 100) {
      recs.add('😷 Consider wearing a mask. AQI is moderately high.');
    }

    if (temp > 40) {
      recs.add('🌡️ HEAT ALERT! Temperature is ${temp.toStringAsFixed(0)}°C. Avoid outdoor 11 AM - 4 PM.');
      recs.add('💧 Drink water every 15-20 minutes. Carry ORS solution.');
    } else if (temp > 35) {
      recs.add('☀️ High temperature. Stay hydrated and seek shade when possible.');
    }

    if (rain > 30) {
      recs.add('🌧️ Heavy rainfall! Avoid underpasses, low-lying areas, and rivers.');
      recs.add('🚗 Drive slowly. Watch for waterlogged roads.');
    } else if (rain > 15) {
      recs.add('🌦️ Moderate rain expected. Carry umbrella and plan accordingly.');
    }

    if (fire) {
      recs.add('🔥 Wildfire detected nearby! Stay indoors. Keep windows closed.');
      recs.add('🚨 Monitor local fire department updates. Be ready to evacuate.');
    }

    if (water) {
      recs.add('🚰 Water contamination alert! Use only purified/bottled water.');
      recs.add('⚠️ Avoid bathing in open water bodies in this area.');
    }

    if (recs.isEmpty) {
      recs.add('✅ Conditions are safe. Enjoy your day!');
      recs.add('💚 Air quality and weather are within safe limits.');
    }

    return recs;
  }

  String get levelText {
    switch (level) {
      case ExposureLevel.safe: return 'Safe';
      case ExposureLevel.low: return 'Low Risk';
      case ExposureLevel.moderate: return 'Moderate Risk';
      case ExposureLevel.high: return 'High Risk';
      case ExposureLevel.critical: return 'Critical';
    }
  }
}

enum ExposureLevel { safe, low, moderate, high, critical }
