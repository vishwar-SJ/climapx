import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/air_quality_model.dart';
import '../core/constants.dart';

/// Air Quality Service - Fetches AQI data from multiple sources
class AirQualityService {
  static String get _aqicnApiKey => dotenv.env['AQICN_API_KEY'] ?? '';
  static String get _googleApiKey => dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';

  /// Fetch AQI data by geographic coordinates
  static Future<AirQualityData?> fetchAqiByLocation(double lat, double lng) async {
    try {
      // Try AQICN first (only if key is configured)
      if (_aqicnApiKey.isNotEmpty && !_aqicnApiKey.startsWith('YOUR_')) {
        final data = await _fetchFromAqicn(lat, lng);
        if (data != null) return data;
      }

      // Fallback to Google Air Quality API
      if (_googleApiKey.isNotEmpty && !_googleApiKey.startsWith('YOUR_')) {
        return await _fetchFromGoogle(lat, lng);
      }

      return null;
    } catch (e) {
      debugPrint('AirQualityService Error: $e');
      return null;
    }
  }

  /// Fetch AQI for a specific city name
  static Future<AirQualityData?> fetchAqiByCity(String city) async {
    try {
      final url = '${AppConstants.aqicnBaseUrl}/feed/$city/?token=$_aqicnApiKey';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['status'] == 'ok') {
          return AirQualityData.fromAqicnJson(json);
        }
      }
      return null;
    } catch (e) {
      debugPrint('Fetch AQI by city error: $e');
      return null;
    }
  }

  /// Fetch AQI data for all major Indian cities
  static Future<List<AirQualityData>> fetchAllCitiesAqi() async {
    final List<AirQualityData> results = [];

    for (final city in AppConstants.majorCities) {
      final data = await fetchAqiByLocation(city['lat'], city['lng']);
      if (data != null) {
        results.add(data);
      }
    }

    return results;
  }

  /// Fetch from AQICN (World Air Quality Index)
  static Future<AirQualityData?> _fetchFromAqicn(double lat, double lng) async {
    try {
      final url = '${AppConstants.aqicnBaseUrl}/feed/geo:$lat;$lng/?token=$_aqicnApiKey';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['status'] == 'ok') {
          return AirQualityData.fromAqicnJson(json);
        }
      }
      return null;
    } catch (e) {
      debugPrint('AQICN fetch error: $e');
      return null;
    }
  }

  /// Fetch from Google Air Quality API
  static Future<AirQualityData?> _fetchFromGoogle(double lat, double lng) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.googleAirQualityUrl}?key=$_googleApiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'location': {'latitude': lat, 'longitude': lng},
          'extraComputations': ['HEALTH_RECOMMENDATIONS', 'DOMINANT_POLLUTANT_CONCENTRATION'],
          'languageCode': 'en',
        }),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final indexes = json['indexes'] as List? ?? [];
        if (indexes.isNotEmpty) {
          final uaqi = indexes.first;
          return AirQualityData(
            aqi: (uaqi['aqi'] ?? 0).toInt(),
            station: 'Google Air Quality',
            lat: lat,
            lng: lng,
            category: uaqi['category'] ?? 'Unknown',
            dominantPollutant: uaqi['dominantPollutant'] ?? 'PM2.5',
            timestamp: DateTime.now(),
            healthAdvice: json['healthRecommendations']?['generalPopulation'] ?? '',
          );
        }
      }
      return null;
    } catch (e) {
      debugPrint('Google AQI fetch error: $e');
      return null;
    }
  }

  /// Search for nearby air quality stations
  static Future<List<AirQualityData>> fetchNearbyStations(double lat, double lng) async {
    // Skip if no AQICN key configured
    if (_aqicnApiKey.isEmpty || _aqicnApiKey.startsWith('YOUR_')) {
      return [];
    }
    try {
      final url = '${AppConstants.aqicnBaseUrl}/map/bounds/'
          '?latlng=${lat - 0.5},${lng - 0.5},${lat + 0.5},${lng + 0.5}'
          '&token=$_aqicnApiKey';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['status'] == 'ok') {
          final List data = json['data'] ?? [];
          return data.map((station) {
            return AirQualityData(
              aqi: int.tryParse(station['aqi']?.toString() ?? '0') ?? 0,
              station: station['station']?['name'] ?? 'Unknown',
              lat: station['lat']?.toDouble() ?? lat,
              lng: station['lon']?.toDouble() ?? lng,
              category: AirQualityData.fromAqicnJson({'data': {'aqi': station['aqi']}}).category,
              timestamp: DateTime.now(),
              healthAdvice: '',
            );
          }).toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('Nearby stations error: $e');
      return [];
    }
  }
}
