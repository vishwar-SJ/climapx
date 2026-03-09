/// ClimapX App Constants
/// Centralized configuration for the entire application
library;

class AppConstants {
  // ─── App Info ───
  static const String appName = 'ClimapX';
  static const String appTagline = 'Climate Safety for India';
  static const String appVersion = '1.0.0';

  // ─── API Endpoints ───
  static const String openWeatherBaseUrl = 'https://api.openweathermap.org/data/2.5';
  static const String aqicnBaseUrl = 'https://api.waqi.info';
  static const String nasaFirmsBaseUrl = 'https://firms.modaps.eosdis.nasa.gov/api/area/csv';
  static const String googleAirQualityUrl = 'https://airquality.googleapis.com/v1/currentConditions:lookup';
  static const String googleDirectionsUrl = 'https://maps.googleapis.com/maps/api/directions/json';
  static const String googlePlacesUrl = 'https://maps.googleapis.com/maps/api/place/nearbysearch/json';
  static const String ndmaAlertUrl = 'https://sachet.ndma.gov.in/cap_public_website/FetchAllAlertDetails';

  // ─── AQI Thresholds (India NAQI Standard) ───
  static const int aqiGood = 50;
  static const int aqiSatisfactory = 100;
  static const int aqiModerate = 200;
  static const int aqiPoor = 300;
  static const int aqiVeryPoor = 400;
  static const int aqiSevere = 500;

  // ─── Temperature Thresholds (°C) ───
  static const double heatCaution = 35.0;
  static const double heatWarning = 40.0;
  static const double heatDanger = 45.0;
  static const double heatExtreme = 48.0;

  // ─── Flood Risk Rainfall (mm/hr) ───
  static const double rainModerate = 15.0;
  static const double rainHeavy = 30.0;
  static const double rainVeryHeavy = 65.0;
  static const double rainExtreme = 115.0;

  // ─── Location Update Settings ───
  static const int locationUpdateIntervalMs = 10000;
  static const int locationFastestIntervalMs = 5000;
  static const double locationMinDisplacementM = 50.0;

  // ─── Risk Zone Radius (meters) ───
  static const double nearbySearchRadius = 5000.0;
  static const double emergencySearchRadius = 10000.0;
  static const double wildfireAlertRadius = 50000.0;

  // ─── Exposure Score Weights ───
  static const double aqiWeight = 0.35;
  static const double heatWeight = 0.25;
  static const double floodWeight = 0.20;
  static const double wildfireWeight = 0.10;
  static const double waterPollutionWeight = 0.10;

  // ─── Indian Cities for Monitoring ───
  static const List<Map<String, dynamic>> majorCities = [
    {'name': 'Delhi', 'lat': 28.6139, 'lng': 77.2090},
    {'name': 'Mumbai', 'lat': 19.0760, 'lng': 72.8777},
    {'name': 'Bangalore', 'lat': 12.9716, 'lng': 77.5946},
    {'name': 'Chennai', 'lat': 13.0827, 'lng': 80.2707},
    {'name': 'Kolkata', 'lat': 22.5726, 'lng': 88.3639},
    {'name': 'Hyderabad', 'lat': 17.3850, 'lng': 78.4867},
    {'name': 'Pune', 'lat': 18.5204, 'lng': 73.8567},
    {'name': 'Patna', 'lat': 25.6093, 'lng': 85.1376},
    {'name': 'Lucknow', 'lat': 26.8467, 'lng': 80.9462},
    {'name': 'Noida', 'lat': 28.5355, 'lng': 77.3910},
  ];

  // ─── Emergency Place Types ───
  static const List<String> emergencyPlaceTypes = [
    'hospital',
    'fire_station',
    'police',
    'pharmacy',
  ];

  static const List<String> shelterKeywords = [
    'shelter',
    'relief camp',
    'community hall',
    'school',
    'stadium',
  ];
}
