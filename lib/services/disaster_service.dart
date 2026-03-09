import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/disaster_model.dart';
import '../core/constants.dart';

/// Disaster Alert Service - NDMA, NASA FIRMS (Wildfire), Floods
class DisasterService {
  static String get _nasaApiKey => dotenv.env['NASA_FIRMS_API_KEY'] ?? '';

  /// Fetch active disaster alerts from NDMA India
  static Future<List<DisasterAlert>> fetchNdmaAlerts() async {
    try {
      final response = await http.get(
        Uri.parse(AppConstants.ndmaAlertUrl),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return data
            .map((alert) => DisasterAlert.fromNdmaJson(alert))
            .where((alert) => alert.isActive)
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('NDMA alerts error: $e');
      return [];
    }
  }

  /// Fetch active wildfire hotspots from NASA FIRMS
  static Future<List<DisasterAlert>> fetchWildfireHotspots({
    double? lat,
    double? lng,
    double radiusKm = 50,
  }) async {
    // Skip if no valid API key configured
    if (_nasaApiKey.isEmpty || _nasaApiKey == 'NONE' || _nasaApiKey.startsWith('YOUR_')) {
      debugPrint('NASA FIRMS: No API key configured, skipping wildfire fetch');
      return [];
    }
    try {
      // Fetch India-wide fire data from NASA FIRMS (VIIRS)
      final url = '${AppConstants.nasaFirmsBaseUrl}'
          '/VIIRS_SNPP_NRT/IND/1/$_nasaApiKey';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final lines = response.body.split('\n');
        if (lines.length <= 1) return [];

        final headers = lines[0].split(',');
        final latIdx = headers.indexOf('latitude');
        final lngIdx = headers.indexOf('longitude');
        final brightIdx = headers.indexOf('bright_ti4');
        final confIdx = headers.indexOf('confidence');
        final dateIdx = headers.indexOf('acq_date');
        final timeIdx = headers.indexOf('acq_time');

        final List<DisasterAlert> fires = [];

        for (int i = 1; i < lines.length; i++) {
          if (lines[i].trim().isEmpty) continue;
          final cols = lines[i].split(',');
          if (cols.length < headers.length) continue;

          final fireLat = double.tryParse(cols[latIdx]) ?? 0;
          final fireLng = double.tryParse(cols[lngIdx]) ?? 0;
          final brightness = double.tryParse(cols[brightIdx]) ?? 0;
          final confidence = cols[confIdx];

          // Filter by proximity if location provided
          if (lat != null && lng != null) {
            final dist = _haversineDistance(lat, lng, fireLat, fireLng);
            if (dist > radiusKm) continue;
          }

          fires.add(DisasterAlert.wildfire(
            lat: fireLat,
            lng: fireLng,
            brightness: brightness,
            confidence: confidence == 'high' ? 90 : confidence == 'nominal' ? 60 : 30,
            timestamp: DateTime.tryParse('${cols[dateIdx]} ${cols[timeIdx]}') ?? DateTime.now(),
          ));
        }

        return fires;
      }
      return [];
    } catch (e) {
      debugPrint('NASA FIRMS error: $e');
      return [];
    }
  }

  /// Fetch all active disasters (combined)
  static Future<List<DisasterAlert>> fetchAllAlerts({
    double? lat,
    double? lng,
  }) async {
    try {
      final results = await Future.wait([
        fetchNdmaAlerts(),
        fetchWildfireHotspots(lat: lat, lng: lng),
      ]);

      final allAlerts = <DisasterAlert>[];
      for (final list in results) {
        allAlerts.addAll(list);
      }

      // Sort by severity
      allAlerts.sort((a, b) {
        final severityOrder = {'Extreme': 0, 'High': 1, 'Moderate': 2, 'Low': 3};
        return (severityOrder[a.severity] ?? 4)
            .compareTo(severityOrder[b.severity] ?? 4);
      });

      return allAlerts;
    } catch (e) {
      debugPrint('Fetch all alerts error: $e');
      return [];
    }
  }

  /// Check if user is in a disaster zone
  static Future<List<DisasterAlert>> getActiveAlertsNearUser(
    double lat, double lng, {double radiusKm = 50}
  ) async {
    final allAlerts = await fetchAllAlerts(lat: lat, lng: lng);

    return allAlerts.where((alert) {
      final dist = _haversineDistance(lat, lng, alert.lat, alert.lng);
      return dist <= radiusKm;
    }).toList();
  }

  /// Haversine distance calculation in km
  static double _haversineDistance(
    double lat1, double lon1, double lat2, double lon2
  ) {
    const r = 6371.0; // Earth radius in km
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
        sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return r * c;
  }

  static double _toRadians(double deg) => deg * (3.141592653589793 / 180);
}
