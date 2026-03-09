/// Air Quality Data Model
class AirQualityData {
  final int aqi;
  final String station;
  final double lat;
  final double lng;
  final double pm25;
  final double pm10;
  final double no2;
  final double so2;
  final double co;
  final double o3;
  final String category;
  final String dominantPollutant;
  final DateTime timestamp;
  final String healthAdvice;

  AirQualityData({
    required this.aqi,
    required this.station,
    required this.lat,
    required this.lng,
    this.pm25 = 0,
    this.pm10 = 0,
    this.no2 = 0,
    this.so2 = 0,
    this.co = 0,
    this.o3 = 0,
    required this.category,
    this.dominantPollutant = 'PM2.5',
    required this.timestamp,
    required this.healthAdvice,
  });

  factory AirQualityData.fromAqicnJson(Map<String, dynamic> json) {
    final data = json['data'] ?? json;
    final int aqiVal = (data['aqi'] is int) ? data['aqi'] : int.tryParse(data['aqi'].toString()) ?? 0;
    final iaqi = data['iaqi'] ?? {};

    return AirQualityData(
      aqi: aqiVal,
      station: data['city']?['name'] ?? 'Unknown',
      lat: (data['city']?['geo']?[0] ?? 0).toDouble(),
      lng: (data['city']?['geo']?[1] ?? 0).toDouble(),
      pm25: (iaqi['pm25']?['v'] ?? 0).toDouble(),
      pm10: (iaqi['pm10']?['v'] ?? 0).toDouble(),
      no2: (iaqi['no2']?['v'] ?? 0).toDouble(),
      so2: (iaqi['so2']?['v'] ?? 0).toDouble(),
      co: (iaqi['co']?['v'] ?? 0).toDouble(),
      o3: (iaqi['o3']?['v'] ?? 0).toDouble(),
      category: _getCategory(aqiVal),
      dominantPollutant: data['dominentpol'] ?? 'PM2.5',
      timestamp: DateTime.now(),
      healthAdvice: _getHealthAdvice(aqiVal),
    );
  }

  static String _getCategory(int aqi) {
    if (aqi <= 50) return 'Good';
    if (aqi <= 100) return 'Satisfactory';
    if (aqi <= 200) return 'Moderate';
    if (aqi <= 300) return 'Poor';
    if (aqi <= 400) return 'Very Poor';
    return 'Severe';
  }

  static String _getHealthAdvice(int aqi) {
    if (aqi <= 50) return 'Air quality is good. Enjoy outdoor activities!';
    if (aqi <= 100) return 'Air quality is acceptable. Sensitive people should limit prolonged outdoor exertion.';
    if (aqi <= 200) return 'Moderate air quality. Reduce prolonged outdoor exertion. Use a mask if necessary.';
    if (aqi <= 300) return 'Poor air quality! Avoid outdoor activities. Wear N95 mask if going outside.';
    if (aqi <= 400) return 'Very Poor! Stay indoors. Close windows. Use air purifier if available.';
    return 'SEVERE! Health emergency. Do NOT go outside. Seek medical help if feeling unwell.';
  }

  Map<String, dynamic> toJson() => {
    'aqi': aqi,
    'station': station,
    'lat': lat,
    'lng': lng,
    'pm25': pm25,
    'pm10': pm10,
    'category': category,
    'timestamp': timestamp.toIso8601String(),
  };
}
