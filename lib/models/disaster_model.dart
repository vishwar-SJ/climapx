/// Disaster Alert Model (NDMA, Wildfires, Floods)
class DisasterAlert {
  final String id;
  final DisasterType type;
  final String title;
  final String description;
  final String severity;
  final double lat;
  final double lng;
  final double radius;
  final DateTime timestamp;
  final DateTime? expiresAt;
  final String source;
  final String advice;
  final bool isActive;

  DisasterAlert({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.severity,
    required this.lat,
    required this.lng,
    this.radius = 5000,
    required this.timestamp,
    this.expiresAt,
    required this.source,
    required this.advice,
    this.isActive = true,
  });

  factory DisasterAlert.fromNdmaJson(Map<String, dynamic> json) {
    return DisasterAlert(
      id: json['alert_id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      type: _parseDisasterType(json['event_type'] ?? ''),
      title: json['event_type'] ?? 'Unknown Alert',
      description: json['description'] ?? 'Disaster alert issued',
      severity: json['severity'] ?? 'Moderate',
      lat: (json['latitude'] ?? 0).toDouble(),
      lng: (json['longitude'] ?? 0).toDouble(),
      timestamp: DateTime.tryParse(json['effective'] ?? '') ?? DateTime.now(),
      expiresAt: DateTime.tryParse(json['expires'] ?? ''),
      source: 'NDMA India',
      advice: json['instruction'] ?? 'Follow local authority guidelines.',
    );
  }

  factory DisasterAlert.wildfire({
    required double lat,
    required double lng,
    required double brightness,
    required double confidence,
    required DateTime timestamp,
  }) {
    final severity = brightness > 400 ? 'Extreme' :
                     brightness > 350 ? 'High' :
                     brightness > 300 ? 'Moderate' : 'Low';
    return DisasterAlert(
      id: 'fire_${lat}_${lng}_${timestamp.millisecondsSinceEpoch}',
      type: DisasterType.wildfire,
      title: 'Active Fire Detected',
      description: 'Wildfire hotspot detected via NASA FIRMS satellite. '
          'Brightness: ${brightness.toStringAsFixed(0)}K, '
          'Confidence: ${confidence.toStringAsFixed(0)}%',
      severity: severity,
      lat: lat,
      lng: lng,
      radius: 10000,
      timestamp: timestamp,
      source: 'NASA FIRMS',
      advice: 'Stay away from the area. If nearby, evacuate immediately. '
          'Follow fire department instructions.',
    );
  }

  static DisasterType _parseDisasterType(String type) {
    final lower = type.toLowerCase();
    if (lower.contains('flood')) return DisasterType.flood;
    if (lower.contains('cyclone') || lower.contains('storm')) return DisasterType.cyclone;
    if (lower.contains('heat')) return DisasterType.heatwave;
    if (lower.contains('fire')) return DisasterType.wildfire;
    if (lower.contains('earthquake')) return DisasterType.earthquake;
    if (lower.contains('landslide')) return DisasterType.landslide;
    if (lower.contains('tsunami')) return DisasterType.tsunami;
    return DisasterType.other;
  }
}

enum DisasterType {
  flood,
  cyclone,
  heatwave,
  wildfire,
  earthquake,
  landslide,
  tsunami,
  waterPollution,
  other,
}
