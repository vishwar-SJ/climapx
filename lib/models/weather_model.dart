/// Weather & Heatwave Data Model
class WeatherData {
  final double temperature;
  final double feelsLike;
  final double humidity;
  final double windSpeed;
  final double windGust;
  final String description;
  final String icon;
  final double rain1h;
  final double rain3h;
  final double visibility;
  final double pressure;
  final int clouds;
  final String cityName;
  final double lat;
  final double lng;
  final DateTime timestamp;
  final HeatRiskLevel heatRisk;
  final FloodRiskLevel floodRisk;

  WeatherData({
    required this.temperature,
    required this.feelsLike,
    required this.humidity,
    required this.windSpeed,
    this.windGust = 0,
    required this.description,
    required this.icon,
    this.rain1h = 0,
    this.rain3h = 0,
    this.visibility = 10000,
    this.pressure = 1013,
    this.clouds = 0,
    required this.cityName,
    required this.lat,
    required this.lng,
    required this.timestamp,
    required this.heatRisk,
    required this.floodRisk,
  });

  factory WeatherData.fromOpenWeatherJson(Map<String, dynamic> json) {
    final main = json['main'] ?? {};
    final wind = json['wind'] ?? {};
    final weather = (json['weather'] as List?)?.first ?? {};
    final rain = json['rain'] ?? {};
    final coord = json['coord'] ?? {};

    final temp = (main['temp'] ?? 0).toDouble();
    final rainAmount = (rain['1h'] ?? rain['3h'] ?? 0).toDouble();

    return WeatherData(
      temperature: temp,
      feelsLike: (main['feels_like'] ?? 0).toDouble(),
      humidity: (main['humidity'] ?? 0).toDouble(),
      windSpeed: (wind['speed'] ?? 0).toDouble(),
      windGust: (wind['gust'] ?? 0).toDouble(),
      description: weather['description'] ?? 'N/A',
      icon: weather['icon'] ?? '01d',
      rain1h: rainAmount,
      rain3h: (rain['3h'] ?? 0).toDouble(),
      visibility: (json['visibility'] ?? 10000).toDouble(),
      pressure: (main['pressure'] ?? 1013).toDouble(),
      clouds: json['clouds']?['all'] ?? 0,
      cityName: json['name'] ?? 'Unknown',
      lat: (coord['lat'] ?? 0).toDouble(),
      lng: (coord['lon'] ?? 0).toDouble(),
      timestamp: json['dt'] != null
          ? DateTime.fromMillisecondsSinceEpoch((json['dt'] as int) * 1000)
          : DateTime.now(),
      heatRisk: _calculateHeatRisk(temp, (main['humidity'] ?? 0).toDouble()),
      floodRisk: _calculateFloodRisk(rainAmount),
    );
  }

  static HeatRiskLevel _calculateHeatRisk(double temp, double humidity) {
    // Heat Index calculation
    if (temp < 35) return HeatRiskLevel.safe;
    if (temp < 40) return HeatRiskLevel.caution;
    if (temp < 45) {
      return humidity > 50 ? HeatRiskLevel.danger : HeatRiskLevel.warning;
    }
    return HeatRiskLevel.extreme;
  }

  static FloodRiskLevel _calculateFloodRisk(double rainMm) {
    if (rainMm < 15) return FloodRiskLevel.safe;
    if (rainMm < 30) return FloodRiskLevel.moderate;
    if (rainMm < 65) return FloodRiskLevel.high;
    if (rainMm < 115) return FloodRiskLevel.veryHigh;
    return FloodRiskLevel.extreme;
  }

  String get heatAdvice {
    switch (heatRisk) {
      case HeatRiskLevel.safe:
        return 'Temperature is comfortable. Safe for outdoor activities.';
      case HeatRiskLevel.caution:
        return 'Heat caution! Stay hydrated. Avoid direct sun during 12-3 PM.';
      case HeatRiskLevel.warning:
        return 'Heat warning! Limit outdoor activities. Drink water frequently.';
      case HeatRiskLevel.danger:
        return 'HEAT DANGER! Avoid going outside. Risk of heatstroke. Stay in cool spaces.';
      case HeatRiskLevel.extreme:
        return 'EXTREME HEAT EMERGENCY! Do NOT go outside. Seek air-conditioned shelter immediately.';
    }
  }

  String get floodAdvice {
    switch (floodRisk) {
      case FloodRiskLevel.safe:
        return 'No flood risk. Normal conditions.';
      case FloodRiskLevel.moderate:
        return 'Moderate rainfall. Watch for waterlogging in low-lying areas.';
      case FloodRiskLevel.high:
        return 'Heavy rainfall! Avoid low-lying areas and underpasses.';
      case FloodRiskLevel.veryHigh:
        return 'FLOOD WARNING! Move to higher ground. Avoid travel near rivers/drains.';
      case FloodRiskLevel.extreme:
        return 'EXTREME FLOOD EMERGENCY! Evacuate immediately to higher ground!';
    }
  }

  String get weatherIconUrl => 'https://openweathermap.org/img/wn/$icon@2x.png';
}

enum HeatRiskLevel { safe, caution, warning, danger, extreme }
enum FloodRiskLevel { safe, moderate, high, veryHigh, extreme }
