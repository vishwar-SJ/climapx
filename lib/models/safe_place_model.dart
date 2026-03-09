import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Safe Place Model - Shelters, Hospitals, Relief Centers
class SafePlace {
  final String id;
  final String name;
  final String address;
  final SafePlaceType type;
  final double lat;
  final double lng;
  final double? distance;
  final bool isOpen;
  final String? phoneNumber;
  final double? rating;
  final String? photoReference;

  SafePlace({
    required this.id,
    required this.name,
    required this.address,
    required this.type,
    required this.lat,
    required this.lng,
    this.distance,
    this.isOpen = true,
    this.phoneNumber,
    this.rating,
    this.photoReference,
  });

  LatLng get latLng => LatLng(lat, lng);

  factory SafePlace.fromGooglePlacesJson(Map<String, dynamic> json, SafePlaceType type) {
    final location = json['geometry']?['location'] ?? {};
    return SafePlace(
      id: json['place_id'] ?? '',
      name: json['name'] ?? 'Unknown',
      address: json['vicinity'] ?? json['formatted_address'] ?? 'Address not available',
      type: type,
      lat: (location['lat'] ?? 0).toDouble(),
      lng: (location['lng'] ?? 0).toDouble(),
      isOpen: json['opening_hours']?['open_now'] ?? true,
      rating: (json['rating'] ?? 0).toDouble(),
      phoneNumber: json['formatted_phone_number'],
      photoReference: (json['photos'] as List?)?.isNotEmpty == true
          ? json['photos'][0]['photo_reference']
          : null,
    );
  }

  String get typeLabel {
    switch (type) {
      case SafePlaceType.hospital: return 'Hospital';
      case SafePlaceType.shelter: return 'Shelter';
      case SafePlaceType.fireStation: return 'Fire Station';
      case SafePlaceType.policeStation: return 'Police Station';
      case SafePlaceType.pharmacy: return 'Pharmacy';
      case SafePlaceType.reliefCenter: return 'Relief Center';
      case SafePlaceType.waterSource: return 'Clean Water';
      case SafePlaceType.foodDistribution: return 'Food Distribution';
    }
  }

  String get typeIcon {
    switch (type) {
      case SafePlaceType.hospital: return '🏥';
      case SafePlaceType.shelter: return '🏛️';
      case SafePlaceType.fireStation: return '🚒';
      case SafePlaceType.policeStation: return '🚔';
      case SafePlaceType.pharmacy: return '💊';
      case SafePlaceType.reliefCenter: return '⛑️';
      case SafePlaceType.waterSource: return '🚰';
      case SafePlaceType.foodDistribution: return '🍲';
    }
  }
}

enum SafePlaceType {
  hospital,
  shelter,
  fireStation,
  policeStation,
  pharmacy,
  reliefCenter,
  waterSource,
  foodDistribution,
}

/// Route Model
class SafeRoute {
  final String summary;
  final List<LatLng> polylinePoints;
  final String distance;
  final String duration;
  final double riskScore;
  final List<String> warnings;
  final List<RouteStep> steps;

  SafeRoute({
    required this.summary,
    required this.polylinePoints,
    required this.distance,
    required this.duration,
    this.riskScore = 0,
    this.warnings = const [],
    this.steps = const [],
  });
}

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
