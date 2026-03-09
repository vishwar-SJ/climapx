import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/air_quality_model.dart';
import '../models/weather_model.dart';
import '../models/disaster_model.dart';
import '../models/exposure_model.dart';
import '../models/safe_place_model.dart';
import '../services/location_service.dart';
import '../services/air_quality_service.dart';
import '../services/weather_service.dart';
import '../services/disaster_service.dart';
import '../services/places_service.dart';

/// Main Climate Data Provider - Manages all environmental data
class ClimateProvider extends ChangeNotifier {
  // ─── State ───
  Position? _currentPosition;
  AirQualityData? _airQuality;
  WeatherData? _weather;
  ExposureScore? _exposureScore;
  List<DisasterAlert> _activeAlerts = [];
  Map<SafePlaceType, List<SafePlace>> _nearbyPlaces = {};
  List<AirQualityData> _nearbyStations = [];

  bool _isLoading = true;
  bool _isEmergencyMode = false;
  bool _locationReady = false;
  String? _errorMessage;
  DateTime? _lastUpdated;

  Timer? _refreshTimer;
  StreamSubscription<Position>? _locationSubscription;

  // ─── Getters ───
  Position? get currentPosition => _currentPosition;
  AirQualityData? get airQuality => _airQuality;
  WeatherData? get weather => _weather;
  ExposureScore? get exposureScore => _exposureScore;
  List<DisasterAlert> get activeAlerts => _activeAlerts;
  Map<SafePlaceType, List<SafePlace>> get nearbyPlaces => _nearbyPlaces;
  List<AirQualityData> get nearbyStations => _nearbyStations;
  bool get isLoading => _isLoading;
  bool get isEmergencyMode => _isEmergencyMode;
  bool get locationReady => _locationReady;
  String? get errorMessage => _errorMessage;
  DateTime? get lastUpdated => _lastUpdated;

  double get latitude => _currentPosition?.latitude ?? 28.6139;
  double get longitude => _currentPosition?.longitude ?? 77.2090;

  bool get hasActiveDisaster => _activeAlerts.isNotEmpty;
  bool get isCriticalRisk =>
      _exposureScore != null && _exposureScore!.totalScore >= 75;

  /// Set location from gate screen and initialize all data
  void setLocationAndInitialize(Position position) {
    _currentPosition = position;
    _locationReady = true;
    notifyListeners();
    initialize();
  }

  /// Initialize the provider - call on app start
  Future<void> initialize() async {
    if (_lastUpdated != null) return; // Already initialized

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // If location wasn't set by gate screen, try to get it now
      if (!_locationReady) {
        final position = await LocationService.getCurrentLocation();
        if (position != null) {
          _currentPosition = position;
          _locationReady = true;
        } else {
          _errorMessage = 'Location unavailable. Please enable GPS.';
        }
      }

      // Fetch data with real location (or skip if no location)
      if (_locationReady) {
        await refreshAllData();
      }

      // Start periodic refresh (every 5 minutes)
      _refreshTimer?.cancel();
      _refreshTimer = Timer.periodic(
        const Duration(minutes: 5),
        (_) => refreshAllData(),
      );

      // Listen for location changes
      _locationSubscription?.cancel();
      _locationSubscription = LocationService.getLocationStream().listen(
        (position) {
          final wasNotReady = !_locationReady;
          _currentPosition = position;
          _locationReady = true;
          notifyListeners();
          // If this is the first location fix, refresh with real location
          if (wasNotReady) {
            _errorMessage = null;
            refreshAllData();
          }
        },
        onError: (e) {
          debugPrint('Location stream error: $e');
        },
      );
    } catch (e) {
      _errorMessage = 'Failed to initialize: $e';
      debugPrint('Initialize error: $e');
      // Still try to load data with default location
      await refreshAllData();
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Retry initialization (e.g. after user enables GPS)
  Future<void> retryLocation() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final position = await LocationService.getCurrentLocation();
    if (position != null) {
      _currentPosition = position;
      _locationReady = true;
      _errorMessage = null;
      await refreshAllData();
    } else {
      if (LocationService.lastServiceDisabled) {
        _errorMessage = 'GPS is still off. Please enable location services.';
      } else if (LocationService.lastDeniedForever) {
        _errorMessage = 'Location permission denied. Open settings to allow.';
      } else {
        _errorMessage = 'Location unavailable. Showing data for default location.';
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Refresh all environmental data
  Future<void> refreshAllData() async {
    try {
      final lat = latitude;
      final lng = longitude;
      debugPrint('Refreshing data for location: $lat, $lng');

      // Fetch each data source independently so one failure doesn't crash all
      try {
        _airQuality = await AirQualityService.fetchAqiByLocation(lat, lng);
      } catch (e) {
        debugPrint('AQI fetch failed: $e');
      }

      try {
        _weather = await WeatherService.fetchCurrentWeather(lat, lng);
      } catch (e) {
        debugPrint('Weather fetch failed: $e');
      }

      try {
        _activeAlerts = await DisasterService.getActiveAlertsNearUser(lat, lng);
      } catch (e) {
        debugPrint('Disaster alerts fetch failed: $e');
        _activeAlerts = [];
      }

      try {
        _nearbyStations = await AirQualityService.fetchNearbyStations(lat, lng);
      } catch (e) {
        debugPrint('Nearby stations fetch failed: $e');
        _nearbyStations = [];
      }

      // Calculate exposure score only with real data
      _calculateExposureScore();

      // Track which data sources failed
      final List<String> failedSources = [];
      if (_airQuality == null) failedSources.add('Air Quality');
      if (_weather == null) failedSources.add('Weather');

      // Use fallback demo data if APIs returned null
      _airQuality ??= _fallbackAirQuality(lat, lng);
      _weather ??= _fallbackWeather(lat, lng);

      // Recalculate exposure with whatever data we have
      _calculateExposureScore();

      // Check if emergency mode should activate
      _checkEmergencyConditions();

      _lastUpdated = DateTime.now();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to refresh data: $e';
      debugPrint('refreshAllData error: $e');
    }

    notifyListeners();
  }

  /// Fallback AQI data when APIs are unavailable
  static AirQualityData _fallbackAirQuality(double lat, double lng) {
    return AirQualityData(
      aqi: 0,
      station: 'Data unavailable',
      lat: lat,
      lng: lng,
      category: 'Unavailable',
      timestamp: DateTime.now(),
      healthAdvice: 'AQI data unavailable. Add AQICN API key in .env for live air quality data.',
    );
  }

  /// Fallback Weather data when APIs are unavailable
  static WeatherData _fallbackWeather(double lat, double lng) {
    return WeatherData(
      temperature: 0,
      feelsLike: 0,
      humidity: 0,
      windSpeed: 0,
      description: 'Data unavailable',
      icon: '01d',
      cityName: 'Unavailable',
      lat: lat,
      lng: lng,
      timestamp: DateTime.now(),
      heatRisk: HeatRiskLevel.safe,
      floodRisk: FloodRiskLevel.safe,
    );
  }

  /// Calculate personal exposure score
  void _calculateExposureScore() {
    _exposureScore = ExposureScore.calculate(
      aqi: _airQuality?.aqi ?? 0,
      temperature: _weather?.temperature ?? 25.0,
      rainfall: _weather?.rain1h ?? 0,
      wildfireNearby: _activeAlerts.any((a) => a.type == DisasterType.wildfire),
      waterContamination: _activeAlerts.any((a) => a.type == DisasterType.waterPollution),
    );
  }

  /// Check if emergency mode should be activated
  void _checkEmergencyConditions() {
    final shouldActivate = _activeAlerts.any((a) =>
        a.severity == 'Extreme' || a.severity == 'High') ||
        (_weather?.floodRisk == FloodRiskLevel.extreme) ||
        (_weather?.heatRisk == HeatRiskLevel.extreme) ||
        (_airQuality != null && _airQuality!.aqi > 400);

    if (shouldActivate && !_isEmergencyMode) {
      activateEmergencyMode();
    }
  }

  /// Manually activate emergency mode
  Future<void> activateEmergencyMode() async {
    _isEmergencyMode = true;
    notifyListeners();

    // Fetch all emergency resources
    _nearbyPlaces = await PlacesService.getAllEmergencyPlaces(
      lat: latitude,
      lng: longitude,
    );

    notifyListeners();
  }

  /// Deactivate emergency mode
  void deactivateEmergencyMode() {
    _isEmergencyMode = false;
    notifyListeners();
  }

  /// Fetch nearby places of a specific type
  Future<List<SafePlace>> fetchNearbyPlaces(SafePlaceType type) async {
    final places = await PlacesService.searchNearbyPlaces(
      lat: latitude,
      lng: longitude,
      type: type,
    );
    _nearbyPlaces[type] = places;
    notifyListeners();
    return places;
  }

  /// Get safe evacuation route to a destination
  Future<SafeRoute?> getEvacuationRoute(SafePlace destination) async {
    if (_currentPosition == null) return null;

    return PlacesService.getEvacuationRoute(
      origin: _currentPosition!.toLatLng(),
      destination: destination.latLng,
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _locationSubscription?.cancel();
    super.dispose();
  }
}

/// Extension to convert Position to LatLng
extension PositionExtension on Position {
  LatLng toLatLng() {
    return LatLng(latitude, longitude);
  }
}
