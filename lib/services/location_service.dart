import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Location Service - GPS location management with proper permission handling
class LocationService {
  /// Track last failure reason
  static bool lastDeniedForever = false;
  static bool lastServiceDisabled = false;

  /// Get current location — requests permission & prompts to enable GPS
  static Future<Position?> getCurrentLocation() async {
    lastDeniedForever = false;
    lastServiceDisabled = false;

    try {
      // 1. Check if location services (GPS) are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        lastServiceDisabled = true;
        debugPrint('Location services disabled. Opening settings...');
        await Geolocator.openLocationSettings();
        // Wait for user to enable, then re-check
        await Future.delayed(const Duration(seconds: 4));
        serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          debugPrint('Location still disabled after prompt.');
          return null;
        }
      }

      // 2. Check and request permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('Requesting location permission...');
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('Location permission denied by user.');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        lastDeniedForever = true;
        debugPrint('Location permission permanently denied.');
        return null;
      }

      // 3. Get current position with timeout
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 50,
        ),
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          debugPrint('Location timed out, trying last known...');
          throw Exception('GPS timeout');
        },
      );
    } catch (e) {
      debugPrint('Location error: $e');
      // Fallback to last known position
      try {
        final lastPos = await Geolocator.getLastKnownPosition();
        if (lastPos != null) {
          debugPrint('Using last known: ${lastPos.latitude}, ${lastPos.longitude}');
          return lastPos;
        }
      } catch (_) {}
      return null;
    }
  }

  /// Stream location updates
  static Stream<Position> getLocationStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 50,
      ),
    );
  }

  /// Calculate distance between two points in meters
  static double calculateDistance(
    double startLat, double startLng,
    double endLat, double endLng,
  ) {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
  }

  /// Open location settings
  static Future<bool> openLocationSettings() async {
    return await Geolocator.openLocationSettings();
  }

  /// Open app settings for permissions
  static Future<bool> openAppSettings() async {
    return await Geolocator.openAppSettings();
  }
}
