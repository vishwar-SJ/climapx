import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/safe_place_model.dart';
import '../core/constants.dart';

/// Places & Navigation Service - Safe places, evacuation routes
class PlacesService {
  static String get _apiKey => dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';

  /// Search nearby safe places (hospitals, shelters, etc.)
  static Future<List<SafePlace>> searchNearbyPlaces({
    required double lat,
    required double lng,
    required SafePlaceType type,
    double radius = 5000,
  }) async {
    try {
      final placeType = _getGooglePlaceType(type);
      final url = '${AppConstants.googlePlacesUrl}'
          '?location=$lat,$lng'
          '&radius=$radius'
          '&type=$placeType'
          '&key=$_apiKey';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final List results = json['results'] ?? [];
        return results
            .map((place) => SafePlace.fromGooglePlacesJson(place, type))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('Places search error: $e');
      return [];
    }
  }

  /// Search for emergency shelters using keyword search
  static Future<List<SafePlace>> searchShelters({
    required double lat,
    required double lng,
    double radius = 10000,
  }) async {
    try {
      final List<SafePlace> shelters = [];

      for (final keyword in AppConstants.shelterKeywords) {
        final url = '${AppConstants.googlePlacesUrl}'
            '?location=$lat,$lng'
            '&radius=$radius'
            '&keyword=$keyword'
            '&key=$_apiKey';

        final response = await http.get(Uri.parse(url));

        if (response.statusCode == 200) {
          final json = jsonDecode(response.body);
          final List results = json['results'] ?? [];
          shelters.addAll(
            results.map((p) => SafePlace.fromGooglePlacesJson(p, SafePlaceType.shelter)),
          );
        }
      }

      // Remove duplicates by ID
      final seen = <String>{};
      return shelters.where((s) => seen.add(s.id)).toList();
    } catch (e) {
      debugPrint('Shelter search error: $e');
      return [];
    }
  }

  /// Get all emergency resources near user
  static Future<Map<SafePlaceType, List<SafePlace>>> getAllEmergencyPlaces({
    required double lat,
    required double lng,
  }) async {
    final results = await Future.wait([
      searchNearbyPlaces(lat: lat, lng: lng, type: SafePlaceType.hospital, radius: 10000),
      searchNearbyPlaces(lat: lat, lng: lng, type: SafePlaceType.fireStation, radius: 10000),
      searchNearbyPlaces(lat: lat, lng: lng, type: SafePlaceType.policeStation, radius: 10000),
      searchNearbyPlaces(lat: lat, lng: lng, type: SafePlaceType.pharmacy, radius: 5000),
      searchShelters(lat: lat, lng: lng),
    ]);

    return {
      SafePlaceType.hospital: results[0],
      SafePlaceType.fireStation: results[1],
      SafePlaceType.policeStation: results[2],
      SafePlaceType.pharmacy: results[3],
      SafePlaceType.shelter: results[4],
    };
  }

  /// Get safe evacuation route
  static Future<SafeRoute?> getEvacuationRoute({
    required LatLng origin,
    required LatLng destination,
    String mode = 'driving',
  }) async {
    try {
      final url = '${AppConstants.googleDirectionsUrl}'
          '?origin=${origin.latitude},${origin.longitude}'
          '&destination=${destination.latitude},${destination.longitude}'
          '&mode=$mode'
          '&alternatives=true'
          '&key=$_apiKey';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final List routes = json['routes'] ?? [];

        if (routes.isEmpty) return null;

        // Use the first route
        final route = routes.first;
        final leg = route['legs']?.first;
        final points = _decodePolyline(route['overview_polyline']?['points'] ?? '');

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

        return SafeRoute(
          summary: route['summary'] ?? 'Route',
          polylinePoints: points,
          distance: leg['distance']?['text'] ?? 'N/A',
          duration: leg['duration']?['text'] ?? 'N/A',
          steps: steps,
        );
      }
      return null;
    } catch (e) {
      debugPrint('Directions error: $e');
      return null;
    }
  }

  /// Decode Google polyline encoding
  static List<LatLng> _decodePolyline(String encoded) {
    final List<LatLng> points = [];
    int index = 0;
    int lat = 0;
    int lng = 0;

    while (index < encoded.length) {
      int result = 0;
      int shift = 0;
      int b;
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

  /// Strip HTML tags from directions text
  static String _stripHtml(String html) {
    return html.replaceAll(RegExp(r'<[^>]*>'), '');
  }

  static String _getGooglePlaceType(SafePlaceType type) {
    switch (type) {
      case SafePlaceType.hospital: return 'hospital';
      case SafePlaceType.fireStation: return 'fire_station';
      case SafePlaceType.policeStation: return 'police';
      case SafePlaceType.pharmacy: return 'pharmacy';
      default: return 'point_of_interest';
    }
  }
}
