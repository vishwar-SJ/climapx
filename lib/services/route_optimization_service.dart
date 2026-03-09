import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/air_quality_model.dart';
import '../models/weather_model.dart';
import '../core/constants.dart';
import 'air_quality_service.dart';
import 'weather_service.dart';

/// A scored route with environmental risk data along its path
class ScoredRoute {
  final String summary;
  final List<LatLng> polylinePoints;
  final String distance;
  final String duration;
  final int durationSeconds;
  final List<RouteRiskPoint> riskPoints;
  final double pollutionScore;   // 0-100
  final double heatScore;        // 0-100
  final double floodScore;       // 0-100
  final double overallRiskScore; // 0-100 weighted
  final List<String> warnings;
  final List<RouteStep> steps;

  ScoredRoute({
    required this.summary,
    required this.polylinePoints,
    required this.distance,
    required this.duration,
    required this.durationSeconds,
    required this.riskPoints,
    required this.pollutionScore,
    required this.heatScore,
    required this.floodScore,
    required this.overallRiskScore,
    required this.warnings,
    required this.steps,
  });

  String get riskLevel {
    if (overallRiskScore < 25) return 'Safe';
    if (overallRiskScore < 50) return 'Moderate';
    if (overallRiskScore < 75) return 'Risky';
    return 'Dangerous';
  }
}

/// A point along a route with its environmental risk data
class RouteRiskPoint {
  final LatLng location;
  final int? aqi;
  final double? temperature;
  final double? rainfall;

  RouteRiskPoint({
    required this.location,
    this.aqi,
    this.temperature,
    this.rainfall,
  });
}

/// Step-by-step navigation instruction
class RouteStep {
  final String instruction;
  final String distance;
  final String duration;
  final LatLng startLocation;
  final LatLng endLocation;

  RouteStep({
    required this.instruction,
    required this.distance,
    required this.duration,
    required this.startLocation,
    required this.endLocation,
  });
}

/// Optimal departure time recommendation
class DepartureRecommendation {
  final int hour;            // 0-23
  final String timeLabel;    // e.g. "6:00 AM"
  final double riskScore;    // 0-100
  final String reason;
  final int expectedAqi;
  final double expectedTemp;
  final double expectedRain;

  DepartureRecommendation({
    required this.hour,
    required this.timeLabel,
    required this.riskScore,
    required this.reason,
    required this.expectedAqi,
    required this.expectedTemp,
    required this.expectedRain,
  });
}

/// Route Optimization Service — Pollution-aware routing with time suggestions
class RouteOptimizationService {
  static String get _apiKey => dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';

  // ───────────────────────────────────────────────────────────────
  //  1.  FETCH & SCORE MULTIPLE ROUTES
  // ───────────────────────────────────────────────────────────────

  /// Fetch alternative routes and rank them by environmental safety
  static Future<List<ScoredRoute>> getOptimizedRoutes({
    required LatLng origin,
    required LatLng destination,
    String mode = 'driving',
    AirQualityData? currentAqi,
    WeatherData? currentWeather,
  }) async {
    try {
      // 1. Fetch routes with alternatives from Google Directions (with timeout)
      final rawRoutes = await _fetchRoutes(origin, destination, mode)
          .timeout(const Duration(seconds: 15), onTimeout: () => []);
      if (rawRoutes.isEmpty) return [];

      // 2. Fetch AQI at destination ONCE (origin already known from currentAqi)
      //    This avoids 15+ API calls that were crashing the device
      int? destAqi;
      try {
        final destAqiData = await AirQualityService.fetchAqiByLocation(
          destination.latitude, destination.longitude,
        ).timeout(const Duration(seconds: 8), onTimeout: () => null);
        destAqi = destAqiData?.aqi;
      } catch (_) {}
      destAqi ??= currentAqi?.aqi;

      // 3. Score each route using interpolated AQI (no per-waypoint API calls)
      final List<ScoredRoute> scoredRoutes = [];
      for (final route in rawRoutes) {
        final scored = _scoreRouteLocal(
          route,
          originAqi: currentAqi?.aqi,
          destAqi: destAqi,
          currentWeather: currentWeather,
        );
        scoredRoutes.add(scored);
      }

      // 4. Sort by overall risk (lowest first = safest)
      scoredRoutes.sort((a, b) => a.overallRiskScore.compareTo(b.overallRiskScore));

      return scoredRoutes;
    } catch (e) {
      debugPrint('RouteOptimization error: $e');
      return [];
    }
  }

  /// Fetch raw routes from Google Directions API
  static Future<List<_RawRoute>> _fetchRoutes(
    LatLng origin, LatLng destination, String mode,
  ) async {
    try {
      if (_apiKey.isEmpty || _apiKey.startsWith('YOUR_')) return [];

      final url = '${AppConstants.googleDirectionsUrl}'
          '?origin=${origin.latitude},${origin.longitude}'
          '&destination=${destination.latitude},${destination.longitude}'
          '&mode=$mode'
          '&alternatives=true'
          '&key=$_apiKey';

      debugPrint('Directions URL: $url');
      final response = await http.get(Uri.parse(url))
          .timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final List routes = json['routes'] ?? [];

        return routes.map((r) {
          final leg = r['legs']?.first;
          final points = _decodePolyline(r['overview_polyline']?['points'] ?? '');
          final steps = (leg['steps'] as List? ?? []).map((step) {
            return RouteStep(
              instruction: _stripHtml(step['html_instructions'] ?? ''),
              distance: step['distance']?['text'] ?? '',
              duration: step['duration']?['text'] ?? '',
              startLocation: LatLng(
                step['start_location']?['lat'] ?? 0,
                step['start_location']?['lng'] ?? 0,
              ),
              endLocation: LatLng(
                step['end_location']?['lat'] ?? 0,
                step['end_location']?['lng'] ?? 0,
              ),
            );
          }).toList();

          return _RawRoute(
            summary: r['summary'] ?? 'Route',
            polylinePoints: points,
            distance: leg?['distance']?['text'] ?? 'N/A',
            duration: leg?['duration']?['text'] ?? 'N/A',
            durationSeconds: leg?['duration']?['value'] ?? 0,
            steps: steps,
          );
        }).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Fetch routes error: $e');
      return [];
    }
  }

  /// Score a route locally using interpolated AQI between origin & destination.
  /// No network calls — all computation is local, preventing OOM crashes.
  static ScoredRoute _scoreRouteLocal(
    _RawRoute route, {
    int? originAqi,
    int? destAqi,
    WeatherData? currentWeather,
  }) {
    final riskPoints = <RouteRiskPoint>[];
    final warnings = <String>[];

    final oAqi = originAqi ?? 100;
    final dAqi = destAqi ?? oAqi;

    // Sample 5 evenly-spaced points and interpolate AQI between origin → dest
    final samplePoints = _samplePoints(route.polylinePoints, 5);
    for (int i = 0; i < samplePoints.length; i++) {
      final t = samplePoints.length <= 1 ? 0.0 : i / (samplePoints.length - 1);
      // Linear interpolation + small random variation based on route distance
      final interpolatedAqi = (oAqi + (dAqi - oAqi) * t).round();
      // Add slight variance for longer routes (simulates mid-route pollution)
      final durationFactor = route.durationSeconds > 1800 ? 1.08 : 1.0;
      final midBoost = (i == 2) ? durationFactor : 1.0; // midpoint slightly higher
      final aqi = (interpolatedAqi * midBoost).round();

      riskPoints.add(RouteRiskPoint(
        location: samplePoints[i],
        aqi: aqi,
        temperature: currentWeather?.temperature,
        rainfall: currentWeather?.rain1h,
      ));
    }

    // Calculate component scores
    final avgAqi = riskPoints.map((p) => p.aqi ?? 0).fold<int>(0, (a, b) => a + b) /
        max(1, riskPoints.length);

    final maxAqi = riskPoints.map((p) => p.aqi ?? 0).fold<int>(0, max);

    final pollutionScore = (avgAqi / 500 * 100).clamp(0.0, 100.0);
    final temp = currentWeather?.temperature ?? 25.0;
    final heatScore = temp < 30 ? 0.0 : ((temp - 30) / 20 * 100).clamp(0.0, 100.0);
    final rain = currentWeather?.rain1h ?? 0.0;
    final floodScore = (rain / 100 * 100).clamp(0.0, 100.0);

    // Longer routes get a duration penalty (more pollution exposure)
    final durationPenalty = (route.durationSeconds / 7200).clamp(0.0, 0.15);

    // Weighted overall score + duration penalty
    final overall = (pollutionScore * 0.50 + heatScore * 0.25 + floodScore * 0.25
        + durationPenalty * 100 * 0.10).clamp(0.0, 100.0);

    // Generate warnings
    if (maxAqi > 300) {
      warnings.add('⚠️ Severe air pollution expected along this route (AQI ~$maxAqi)');
    } else if (maxAqi > 200) {
      warnings.add('😷 High pollution expected along this route (AQI ~$maxAqi)');
    } else if (maxAqi > 150) {
      warnings.add('🌫️ Moderate pollution along this route (AQI ~$maxAqi)');
    }
    if (temp > 40) {
      warnings.add('🌡️ Extreme heat (${temp.toStringAsFixed(0)}°C). Carry water, use AC.');
    } else if (temp > 35) {
      warnings.add('🌡️ Hot weather (${temp.toStringAsFixed(0)}°C). Stay hydrated.');
    }
    if (rain > 30) {
      warnings.add('🌧️ Heavy rain — possible waterlogging on this route.');
    }
    if (route.durationSeconds > 3600 && avgAqi > 150) {
      warnings.add('⏱️ Long exposure (${route.duration}) in polluted air. Consider mask.');
    }

    return ScoredRoute(
      summary: route.summary,
      polylinePoints: route.polylinePoints,
      distance: route.distance,
      duration: route.duration,
      durationSeconds: route.durationSeconds,
      riskPoints: riskPoints,
      pollutionScore: pollutionScore,
      heatScore: heatScore,
      floodScore: floodScore,
      overallRiskScore: overall,
      warnings: warnings,
      steps: route.steps,
    );
  }

  // ───────────────────────────────────────────────────────────────
  //  2.  OPTIMAL DEPARTURE TIME SUGGESTIONS
  // ───────────────────────────────────────────────────────────────

  /// Suggest the best departure times based on forecast data
  static Future<List<DepartureRecommendation>> getOptimalDepartureTimes({
    required double lat,
    required double lng,
    int? currentAqi,
  }) async {
    final List<DepartureRecommendation> recommendations = [];

    try {
      // Fetch 5-day / 3-hour forecast from OpenWeatherMap (with timeout)
      final forecast = await WeatherService.fetchForecast(lat, lng)
          .timeout(const Duration(seconds: 10), onTimeout: () => []);

      // Get current hour
      final now = DateTime.now();
      final currentHour = now.hour;

      // Build hourly risk profile for next 24 hours
      // We use known AQI patterns for India + forecast weather
      for (int h = 0; h < 24; h++) {
        final targetHour = (currentHour + h) % 24;
        final targetTime = now.add(Duration(hours: h));

        // Find the nearest forecast entry
        WeatherData? nearestForecast;
        int closestDiff = 999;
        for (final f in forecast) {
          final diff = (f.timestamp.difference(targetTime).inMinutes).abs();
          if (diff < closestDiff) {
            closestDiff = diff;
            nearestForecast = f;
          }
        }

        final temp = nearestForecast?.temperature ?? 25.0;
        final rain = nearestForecast?.rain1h ?? 0.0;
        final wind = nearestForecast?.windSpeed ?? 0.0;

        // Estimate AQI by hour using known Indian city patterns:
        //   - AQI lowest: 5-8 AM (wind picks up, mixing height rises)
        //   - AQI moderate: 9-11 AM, 5-7 PM (rush-hour traffic spikes)
        //   - AQI highest: 10 PM - 3 AM (inversion layer traps pollutants)
        //   - Rain significantly reduces AQI
        final baseAqi = currentAqi ?? 150;
        final hourlyAqiFactor = _getHourlyAqiFactor(targetHour);
        final rainReduction = rain > 5 ? 0.6 : (rain > 1 ? 0.8 : 1.0);
        final windReduction = wind > 5 ? 0.85 : 1.0;
        final estimatedAqi = (baseAqi * hourlyAqiFactor * rainReduction * windReduction).round();

        // Score this time slot
        final aqiRisk = (estimatedAqi / 500 * 100).clamp(0.0, 100.0);
        final heatRisk = temp < 30 ? 0.0 : ((temp - 30) / 20 * 100).clamp(0.0, 100.0);
        final rainRisk = (rain / 50 * 100).clamp(0.0, 100.0);

        final riskScore = aqiRisk * 0.50 + heatRisk * 0.30 + rainRisk * 0.20;

        // Build reason text
        String reason;
        if (riskScore < 25) {
          reason = _getGoodReason(targetHour, estimatedAqi, temp, rain);
        } else if (riskScore < 50) {
          reason = _getModerateReason(targetHour, estimatedAqi, temp, rain);
        } else {
          reason = _getBadReason(targetHour, estimatedAqi, temp, rain);
        }

        recommendations.add(DepartureRecommendation(
          hour: targetHour,
          timeLabel: _formatHour(targetHour),
          riskScore: riskScore,
          reason: reason,
          expectedAqi: estimatedAqi,
          expectedTemp: temp,
          expectedRain: rain,
        ));
      }

      // Sort by risk score (lowest first = best time)
      recommendations.sort((a, b) => a.riskScore.compareTo(b.riskScore));
    } catch (e) {
      debugPrint('Departure time analysis error: $e');
    }

    return recommendations;
  }

  /// Hourly AQI multiplier based on known Indian pollution patterns
  /// Research: CPCB data shows AQI follows diurnal cycle due to
  /// boundary layer dynamics, traffic, and meteorological inversions.
  static double _getHourlyAqiFactor(int hour) {
    // Factors relative to the daily average (1.0)
    const hourFactors = {
      0: 1.15,  // Late night — inversion traps pollutants
      1: 1.20,
      2: 1.20,
      3: 1.15,
      4: 1.05,  // Pre-dawn — slight improvement
      5: 0.85,  // Early morning — mixing height rising
      6: 0.75,  // Best window — fresh morning air
      7: 0.70,  // Lowest AQI typically
      8: 0.80,  // Still good
      9: 0.90,  // Rush hour starting
      10: 1.00, // Mid-morning
      11: 0.95,
      12: 0.90,
      13: 0.85, // Afternoon — good mixing height
      14: 0.85,
      15: 0.90,
      16: 0.95,
      17: 1.05, // Evening rush hour
      18: 1.10,
      19: 1.15,
      20: 1.15, // Evening — inversion forming
      21: 1.15,
      22: 1.15,
      23: 1.15,
    };
    return hourFactors[hour] ?? 1.0;
  }

  static String _getGoodReason(int hour, int aqi, double temp, double rain) {
    if (hour >= 5 && hour <= 8) {
      return '🌅 Early morning — cleanest air, cooler temperature. Best time to travel.';
    }
    if (hour >= 13 && hour <= 15) {
      return '☀️ Afternoon — good atmospheric mixing disperses pollutants.';
    }
    if (rain > 5) {
      return '🌧️ Rain is washing pollutants away. Air will be cleaner.';
    }
    return '✅ Low overall risk. Good conditions for travel.';
  }

  static String _getModerateReason(int hour, int aqi, double temp, double rain) {
    if (hour >= 9 && hour <= 10 || hour >= 17 && hour <= 19) {
      return '🚗 Rush hour — traffic emissions spike. Consider a mask.';
    }
    if (temp > 35) {
      return '🌡️ High temperature (${temp.toStringAsFixed(0)}°C). Stay hydrated.';
    }
    return '⚠️ Moderate risk. Carry water and mask if sensitive.';
  }

  static String _getBadReason(int hour, int aqi, double temp, double rain) {
    if (hour >= 22 || hour <= 3) {
      return '🌙 Night inversion traps pollutants near ground. Avoid if possible.';
    }
    if (temp > 40) {
      return '🔥 Extreme heat + pollution. Delay travel or use AC transport.';
    }
    if (aqi > 300) {
      return '😷 AQI ~$aqi (Very Poor). Strongly recommend delaying travel.';
    }
    return '🚫 High risk conditions. Delay non-essential travel.';
  }

  static String _formatHour(int hour) {
    if (hour == 0) return '12:00 AM';
    if (hour < 12) return '$hour:00 AM';
    if (hour == 12) return '12:00 PM';
    return '${hour - 12}:00 PM';
  }

  // ───────────────────────────────────────────────────────────────
  //  UTILITY
  // ───────────────────────────────────────────────────────────────

  /// Sample N evenly spaced points from a polyline
  static List<LatLng> _samplePoints(List<LatLng> points, int n) {
    if (points.length <= n) return points;
    final step = points.length / n;
    return List.generate(n, (i) => points[(i * step).floor()]);
  }

  /// Decode Google's encoded polyline string
  static List<LatLng> _decodePolyline(String encoded) {
    final List<LatLng> points = [];
    int index = 0, lat = 0, lng = 0;

    while (index < encoded.length) {
      int result = 0, shift = 0, b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      lat += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      result = 0;
      shift = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      lng += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }

  static String _stripHtml(String html) =>
      html.replaceAll(RegExp(r'<[^>]*>'), '');
}

/// Internal raw route before scoring
class _RawRoute {
  final String summary;
  final List<LatLng> polylinePoints;
  final String distance;
  final String duration;
  final int durationSeconds;
  final List<RouteStep> steps;

  _RawRoute({
    required this.summary,
    required this.polylinePoints,
    required this.distance,
    required this.duration,
    required this.durationSeconds,
    required this.steps,
  });
}
