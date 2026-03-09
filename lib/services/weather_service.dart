import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/weather_model.dart';
import '../core/constants.dart';

/// Weather Service - Fetches weather, heatwave, and flood risk data
class WeatherService {
  static String get _apiKey => dotenv.env['OPENWEATHER_API_KEY'] ?? '';

  /// Fetch current weather by coordinates
  static Future<WeatherData?> fetchCurrentWeather(double lat, double lng) async {
    try {
      if (_apiKey.isEmpty || _apiKey.startsWith('YOUR_')) {
        debugPrint('WeatherService: No API key configured');
        return null;
      }
      final url = '${AppConstants.openWeatherBaseUrl}/weather'
          '?lat=$lat&lon=$lng&appid=$_apiKey&units=metric';
      debugPrint('WeatherService: Fetching $url');
      final response = await http.get(Uri.parse(url));
      debugPrint('WeatherService: Status ${response.statusCode}');

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return WeatherData.fromOpenWeatherJson(json);
      } else {
        debugPrint('WeatherService: Error body: ${response.body}');
      }
      return null;
    } catch (e) {
      debugPrint('WeatherService Error: $e');
      return null;
    }
  }

  /// Fetch 5-day weather forecast
  static Future<List<WeatherData>> fetchForecast(double lat, double lng) async {
    try {
      final url = '${AppConstants.openWeatherBaseUrl}/forecast'
          '?lat=$lat&lon=$lng&appid=$_apiKey&units=metric';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final List items = json['list'] ?? [];
        return items.map((item) => WeatherData.fromOpenWeatherJson(item)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Forecast Error: $e');
      return [];
    }
  }

  /// Check if heatwave conditions exist
  static Future<bool> isHeatwaveActive(double lat, double lng) async {
    final weather = await fetchCurrentWeather(lat, lng);
    if (weather == null) return false;
    return weather.temperature >= AppConstants.heatWarning;
  }

  /// Check flood risk based on rainfall
  static Future<FloodRiskLevel> getFloodRisk(double lat, double lng) async {
    final weather = await fetchCurrentWeather(lat, lng);
    if (weather == null) return FloodRiskLevel.safe;
    return weather.floodRisk;
  }

  /// Get weather alerts for a region
  static Future<List<Map<String, dynamic>>> fetchWeatherAlerts(double lat, double lng) async {
    try {
      // Using OneCall API for alerts (requires subscription)
      final url = 'https://api.openweathermap.org/data/3.0/onecall'
          '?lat=$lat&lon=$lng&appid=$_apiKey&exclude=minutely,hourly';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final List alerts = json['alerts'] ?? [];
        return alerts.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      debugPrint('Weather alerts error: $e');
      return [];
    }
  }

  /// Fetch weather for multiple Indian cities
  static Future<List<WeatherData>> fetchMultiCityWeather() async {
    final List<WeatherData> results = [];
    for (final city in AppConstants.majorCities) {
      final data = await fetchCurrentWeather(city['lat'], city['lng']);
      if (data != null) results.add(data);
    }
    return results;
  }
}
