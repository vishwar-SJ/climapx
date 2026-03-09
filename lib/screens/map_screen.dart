import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme.dart';
import '../../providers/climate_provider.dart';
import '../../models/safe_place_model.dart';
import '../../models/disaster_model.dart';

/// Map Screen - Interactive risk visualization map
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  MapType _mapType = MapType.normal;
  bool _showAqiOverlay = true;
  bool _showHeatOverlay = false;
  bool _showFloodOverlay = false;
  bool _hasCenteredOnUser = false;

  // Route state
  SafeRoute? _activeRoute;
  SafePlace? _selectedDestination;
  bool _isLoadingRoute = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<ClimateProvider>(
      builder: (context, provider, child) {
        // Animate camera to user's real location once GPS is ready
        if (provider.locationReady && !_hasCenteredOnUser && _mapController != null) {
          _hasCenteredOnUser = true;
          Future.microtask(() {
            _mapController?.animateCamera(
              CameraUpdate.newLatLngZoom(
                LatLng(provider.latitude, provider.longitude),
                14,
              ),
            );
          });
        }

        final lat = provider.locationReady ? provider.latitude : 20.5937;
        final lng = provider.locationReady ? provider.longitude : 78.9629;

        return Stack(
          children: [
            // Google Map
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(lat, lng),
                zoom: provider.locationReady ? 14 : 5,
              ),
              onMapCreated: (controller) {
                _mapController = controller;
                // Center on user if location already available
                if (provider.locationReady) {
                  _hasCenteredOnUser = true;
                  controller.animateCamera(
                    CameraUpdate.newLatLngZoom(
                      LatLng(provider.latitude, provider.longitude),
                      14,
                    ),
                  );
                }
              },
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapType: _mapType,
              markers: _buildMarkers(provider),
              circles: _buildRiskCircles(provider),
              polylines: _buildPolylines(provider),
            ),

            // Top Status Bar
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 16,
              right: 16,
              child: _buildTopStatusBar(provider),
            ),

            // Emergency Mode Banner
            if (provider.isEmergencyMode)
              Positioned(
                top: MediaQuery.of(context).padding.top + 70,
                left: 16,
                right: 16,
                child: _buildEmergencyBanner(provider),
              ),

            // Map Controls
            Positioned(
              right: 16,
              bottom: 120,
              child: _buildMapControls(provider),
            ),

            // Route Loading Indicator
            if (_isLoadingRoute)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.3),
                  child: const Center(
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: AppTheme.primaryGreen),
                            SizedBox(height: 12),
                            Text('Calculating safe route...'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // Route Info Bar (when route is active)
            if (_activeRoute != null)
              Positioned(
                left: 16,
                right: 16,
                bottom: 90,
                child: _buildRouteInfo().animate().fadeIn(duration: 300.ms).slideY(begin: 0.2, end: 0),
              ),

            // Active Overlay Legend
            if (_showAqiOverlay || _showHeatOverlay || _showFloodOverlay)
              Positioned(
                left: 16,
                right: 16,
                bottom: 82,
                child: _buildOverlayLegend(provider),
              ),

            // Bottom AQI Quick Info
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: _buildBottomInfo(provider),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTopStatusBar(ClimateProvider provider) {
    final aqi = provider.airQuality?.aqi ?? 0;
    final color = AppTheme.getAqiColor(aqi);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 6),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'AQI $aqi',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: color,
              fontSize: 16,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '• ${AppTheme.getAqiLabel(aqi)}',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
          const Spacer(),
          if (provider.weather != null)
            Row(
              children: [
                Icon(
                  Icons.thermostat,
                  size: 18,
                  color: AppTheme.getHeatColor(provider.weather!.temperature),
                ),
                Text(
                  '${provider.weather!.temperature.toStringAsFixed(0)}°C',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.getHeatColor(provider.weather!.temperature),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildEmergencyBanner(ClimateProvider provider) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.riskEmergency,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppTheme.riskEmergency.withValues(alpha: 0.5),
            blurRadius: 12,
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.emergency, color: Colors.white, size: 24),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '🚨 EMERGENCY MODE ACTIVE',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                Text(
                  'Showing evacuation routes & nearest safe zones',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => provider.deactivateEmergencyMode(),
            icon: const Icon(Icons.close, color: Colors.white70),
            iconSize: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildMapControls(ClimateProvider provider) {
    return Column(
      children: [
        // My Location
        _mapControlButton(
          icon: Icons.my_location,
          onTap: () {
            _mapController?.animateCamera(
              CameraUpdate.newLatLng(
                LatLng(provider.latitude, provider.longitude),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        // Map Type
        _mapControlButton(
          icon: Icons.layers,
          onTap: () {
            setState(() {
              _mapType = _mapType == MapType.normal
                  ? MapType.satellite
                  : MapType.normal;
            });
          },
        ),
        const SizedBox(height: 8),
        // AQI Overlay Toggle
        _mapControlButton(
          icon: Icons.air,
          isActive: _showAqiOverlay,
          onTap: () => setState(() => _showAqiOverlay = !_showAqiOverlay),
        ),
        const SizedBox(height: 8),
        // Heat Overlay Toggle
        _mapControlButton(
          icon: Icons.whatshot,
          isActive: _showHeatOverlay,
          onTap: () => setState(() => _showHeatOverlay = !_showHeatOverlay),
        ),
        const SizedBox(height: 8),
        // Flood Overlay Toggle
        _mapControlButton(
          icon: Icons.flood,
          isActive: _showFloodOverlay,
          onTap: () => setState(() => _showFloodOverlay = !_showFloodOverlay),
        ),
        const SizedBox(height: 8),
        // Emergency Mode
        _mapControlButton(
          icon: Icons.emergency,
          color: provider.isEmergencyMode ? AppTheme.riskEmergency : null,
          onTap: () {
            if (provider.isEmergencyMode) {
              provider.deactivateEmergencyMode();
            } else {
              provider.activateEmergencyMode();
            }
          },
        ),
      ],
    );
  }

  Widget _mapControlButton({
    required IconData icon,
    required VoidCallback onTap,
    bool isActive = false,
    Color? color,
  }) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: isActive
                ? AppTheme.primaryGreen.withValues(alpha: 0.1)
                : Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: color ?? (isActive ? AppTheme.primaryGreen : Colors.grey.shade700),
            size: 22,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomInfo(ClimateProvider provider) {
    final score = provider.exposureScore;
    if (score == null) return const SizedBox.shrink();

    final color = AppTheme.getRiskColor(score.totalScore);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                score.totalScore.toStringAsFixed(0),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Exposure: ${score.levelText}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: color,
                    fontSize: 14,
                  ),
                ),
                if (score.recommendations.isNotEmpty)
                  Text(
                    score.recommendations.first,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (provider.hasActiveDisaster)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.riskEmergency.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.warning_amber,
                color: AppTheme.riskEmergency,
                size: 22,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRouteInfo() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.primaryGreen,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryGreen.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.directions, color: Colors.white, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _selectedDestination?.name ?? 'Evacuation Route',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${_activeRoute!.distance} • ${_activeRoute!.duration}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _clearRoute,
            icon: const Icon(Icons.close, color: Colors.white70),
            iconSize: 20,
          ),
        ],
      ),
    );
  }

  Set<Marker> _buildMarkers(ClimateProvider provider) {
    final Set<Marker> markers = {};

    // AQI Station Markers
    if (_showAqiOverlay) {
      for (final station in provider.nearbyStations) {
        final color = station.aqi <= 100
            ? BitmapDescriptor.hueGreen
            : station.aqi <= 200
                ? BitmapDescriptor.hueYellow
                : station.aqi <= 300
                    ? BitmapDescriptor.hueOrange
                    : BitmapDescriptor.hueRed;

        markers.add(Marker(
          markerId: MarkerId('aqi_${station.station}'),
          position: LatLng(station.lat, station.lng),
          icon: BitmapDescriptor.defaultMarkerWithHue(color),
          infoWindow: InfoWindow(
            title: 'AQI: ${station.aqi}',
            snippet: station.station,
          ),
        ));
      }
    }

    // Disaster Alert Markers — filtered by active overlays for clarity
    for (final alert in provider.activeAlerts) {
      // Wildfire markers only when heat overlay is ON
      if (alert.type == DisasterType.wildfire && !_showHeatOverlay) {
        // Still show generic disaster marker
        markers.add(Marker(
          markerId: MarkerId('alert_${alert.id}'),
          position: LatLng(alert.lat, alert.lng),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(title: alert.title, snippet: alert.description),
        ));
        continue;
      }

      // Assign hue based on disaster type
      double hue;
      switch (alert.type) {
        case DisasterType.wildfire:
          hue = BitmapDescriptor.hueOrange;
          break;
        case DisasterType.flood:
        case DisasterType.cyclone:
          hue = BitmapDescriptor.hueAzure;
          break;
        case DisasterType.heatwave:
          hue = BitmapDescriptor.hueYellow;
          break;
        default:
          hue = BitmapDescriptor.hueRed;
      }

      markers.add(Marker(
        markerId: MarkerId('alert_${alert.id}'),
        position: LatLng(alert.lat, alert.lng),
        icon: BitmapDescriptor.defaultMarkerWithHue(hue),
        infoWindow: InfoWindow(
          title: '${_getDisasterEmoji(alert.type)} ${alert.title}',
          snippet: '${alert.severity} • ${alert.description}',
        ),
      ));
    }

    // Heat overlay: add temperature info marker at user location
    if (_showHeatOverlay && provider.weather != null) {
      markers.add(Marker(
        markerId: const MarkerId('heat_center'),
        position: LatLng(provider.latitude, provider.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        infoWindow: InfoWindow(
          title: '🌡️ ${provider.weather!.temperature.toStringAsFixed(1)}°C',
          snippet: 'Feels like ${provider.weather!.feelsLike.toStringAsFixed(0)}°C • ${provider.weather!.heatAdvice}',
        ),
      ));
    }

    // Flood overlay: add rain info marker at user location
    if (_showFloodOverlay && provider.weather != null) {
      final rain = provider.weather!.rain1h + provider.weather!.rain3h;
      markers.add(Marker(
        markerId: const MarkerId('flood_center'),
        position: LatLng(provider.latitude + 0.001, provider.longitude + 0.001),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
        infoWindow: InfoWindow(
          title: '🌧️ Rain: ${rain.toStringAsFixed(1)} mm',
          snippet: 'Flood Risk: ${provider.weather!.floodRisk.name.toUpperCase()} • ${provider.weather!.floodAdvice}',
        ),
      ));
    }

    // Emergency Place Markers
    if (provider.isEmergencyMode) {
      for (final entry in provider.nearbyPlaces.entries) {
        for (final place in entry.value) {
          markers.add(Marker(
            markerId: MarkerId('place_${place.id}'),
            position: place.latLng,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
            infoWindow: InfoWindow(
              title: '${place.typeIcon} ${place.name}',
              snippet: '${place.address} • Tap for route',
              onTap: () => _navigateToPlace(provider, place),
            ),
          ));
        }
      }
    }

    return markers;
  }

  Set<Circle> _buildRiskCircles(ClimateProvider provider) {
    final Set<Circle> circles = {};
    final center = LatLng(provider.latitude, provider.longitude);

    // ── AQI Risk Zones ──
    if (_showAqiOverlay && provider.airQuality != null) {
      final aqi = provider.airQuality!.aqi;
      final aqiColor = AppTheme.getAqiColor(aqi);
      // Inner zone (immediate area)
      circles.add(Circle(
        circleId: const CircleId('aqi_zone_inner'),
        center: center,
        radius: 1500,
        fillColor: aqiColor.withValues(alpha: 0.20),
        strokeColor: aqiColor.withValues(alpha: 0.5),
        strokeWidth: 2,
      ));
      // Outer zone (extended area)
      circles.add(Circle(
        circleId: const CircleId('aqi_zone_outer'),
        center: center,
        radius: 3500,
        fillColor: aqiColor.withValues(alpha: 0.08),
        strokeColor: aqiColor.withValues(alpha: 0.25),
        strokeWidth: 1,
      ));
      // Nearby station zones
      for (int i = 0; i < provider.nearbyStations.length; i++) {
        final st = provider.nearbyStations[i];
        final stColor = AppTheme.getAqiColor(st.aqi);
        circles.add(Circle(
          circleId: CircleId('station_zone_$i'),
          center: LatLng(st.lat, st.lng),
          radius: 1200,
          fillColor: stColor.withValues(alpha: 0.12),
          strokeColor: stColor.withValues(alpha: 0.3),
          strokeWidth: 1,
        ));
      }
    }

    // ── Heat Overlay Zones ──
    if (_showHeatOverlay && provider.weather != null) {
      final temp = provider.weather!.temperature;
      final heatColor = AppTheme.getHeatColor(temp);
      // Heat risk zone around user
      circles.add(Circle(
        circleId: const CircleId('heat_zone_inner'),
        center: center,
        radius: 2000,
        fillColor: heatColor.withValues(alpha: 0.18),
        strokeColor: heatColor.withValues(alpha: 0.5),
        strokeWidth: 2,
      ));
      circles.add(Circle(
        circleId: const CircleId('heat_zone_outer'),
        center: center,
        radius: 5000,
        fillColor: heatColor.withValues(alpha: 0.06),
        strokeColor: heatColor.withValues(alpha: 0.2),
        strokeWidth: 1,
      ));
      // Show heatwave disaster alert zones if any
      for (final alert in provider.activeAlerts) {
        if (alert.type == DisasterType.heatwave) {
          circles.add(Circle(
            circleId: CircleId('heat_alert_${alert.id}'),
            center: LatLng(alert.lat, alert.lng),
            radius: alert.radius,
            fillColor: AppTheme.heatwave.withValues(alpha: 0.15),
            strokeColor: AppTheme.heatwave.withValues(alpha: 0.5),
            strokeWidth: 2,
          ));
        }
      }
    }

    // ── Flood Overlay Zones ──
    if (_showFloodOverlay) {
      if (provider.weather != null) {
        final rain = provider.weather!.rain1h + provider.weather!.rain3h;
        final floodColor = rain > 30
            ? AppTheme.riskSevere
            : rain > 15
                ? AppTheme.riskPoor
                : rain > 5
                    ? AppTheme.riskModerate
                    : AppTheme.flood;
        // Flood risk zone around user based on rainfall
        circles.add(Circle(
          circleId: const CircleId('flood_zone_inner'),
          center: center,
          radius: 2500,
          fillColor: floodColor.withValues(alpha: 0.18),
          strokeColor: floodColor.withValues(alpha: 0.5),
          strokeWidth: 2,
        ));
        circles.add(Circle(
          circleId: const CircleId('flood_zone_outer'),
          center: center,
          radius: 6000,
          fillColor: floodColor.withValues(alpha: 0.06),
          strokeColor: floodColor.withValues(alpha: 0.2),
          strokeWidth: 1,
        ));
      }
      // Show flood/cyclone disaster zones
      for (final alert in provider.activeAlerts) {
        if (alert.type == DisasterType.flood || alert.type == DisasterType.cyclone) {
          circles.add(Circle(
            circleId: CircleId('flood_alert_${alert.id}'),
            center: LatLng(alert.lat, alert.lng),
            radius: alert.radius,
            fillColor: AppTheme.flood.withValues(alpha: 0.15),
            strokeColor: AppTheme.flood.withValues(alpha: 0.5),
            strokeWidth: 2,
          ));
        }
      }
    }

    // ── General disaster zones (always visible) ──
    for (final alert in provider.activeAlerts) {
      // Skip types already shown by specific overlays
      if (_showHeatOverlay && alert.type == DisasterType.heatwave) continue;
      if (_showFloodOverlay && (alert.type == DisasterType.flood || alert.type == DisasterType.cyclone)) continue;
      circles.add(Circle(
        circleId: CircleId('disaster_${alert.id}'),
        center: LatLng(alert.lat, alert.lng),
        radius: alert.radius,
        fillColor: Colors.red.withValues(alpha: 0.1),
        strokeColor: Colors.red.withValues(alpha: 0.5),
        strokeWidth: 2,
      ));
    }

    return circles;
  }

  Set<Polyline> _buildPolylines(ClimateProvider provider) {
    final Set<Polyline> polylines = {};

    // Render active evacuation route
    if (_activeRoute != null && _activeRoute!.polylinePoints.isNotEmpty) {
      polylines.add(Polyline(
        polylineId: const PolylineId('evacuation_route'),
        points: _activeRoute!.polylinePoints,
        color: AppTheme.primaryGreen,
        width: 5,
        patterns: [PatternItem.dash(20), PatternItem.gap(10)],
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
      ));
    }

    return polylines;
  }

  /// Navigate to a safe place and show route on map
  Future<void> _navigateToPlace(ClimateProvider provider, SafePlace place) async {
    setState(() {
      _isLoadingRoute = true;
      _selectedDestination = place;
    });

    final route = await provider.getEvacuationRoute(place);

    setState(() {
      _activeRoute = route;
      _isLoadingRoute = false;
    });

    // Zoom to fit the route
    if (route != null && route.polylinePoints.isNotEmpty && _mapController != null) {
      final bounds = _getBoundsForPoints(route.polylinePoints);
      _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 80),
      );
    }
  }

  /// Clear the active route
  void _clearRoute() {
    setState(() {
      _activeRoute = null;
      _selectedDestination = null;
    });
  }

  String _getDisasterEmoji(DisasterType type) {
    switch (type) {
      case DisasterType.wildfire: return '🔥';
      case DisasterType.flood: return '🌊';
      case DisasterType.cyclone: return '🌀';
      case DisasterType.heatwave: return '🌡️';
      case DisasterType.earthquake: return '🏚️';
      case DisasterType.landslide: return '⛰️';
      case DisasterType.tsunami: return '🌊';
      case DisasterType.waterPollution: return '🚰';
      case DisasterType.other: return '⚠️';
    }
  }

  Widget _buildOverlayLegend(ClimateProvider provider) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          if (_showAqiOverlay && provider.airQuality != null)
            _overlayChip(
              Icons.air,
              'AQI ${provider.airQuality!.aqi}',
              AppTheme.getAqiColor(provider.airQuality!.aqi),
              AppTheme.getAqiLabel(provider.airQuality!.aqi),
            ),
          if (_showHeatOverlay && provider.weather != null)
            _overlayChip(
              Icons.whatshot,
              '${provider.weather!.temperature.toStringAsFixed(0)}°C',
              AppTheme.getHeatColor(provider.weather!.temperature),
              provider.weather!.heatRisk.name.toUpperCase(),
            ),
          if (_showFloodOverlay && provider.weather != null) ...[  
            () {
              final rain = provider.weather!.rain1h + provider.weather!.rain3h;
              final floodColor = rain > 30
                  ? AppTheme.riskSevere
                  : rain > 15
                      ? AppTheme.riskPoor
                      : rain > 5
                          ? AppTheme.riskModerate
                          : AppTheme.flood;
              return _overlayChip(
                Icons.flood,
                'Rain ${rain.toStringAsFixed(1)}mm',
                floodColor,
                provider.weather!.floodRisk.name.toUpperCase(),
              );
            }(),
          ],
        ],
      ),
    );
  }

  Widget _overlayChip(IconData icon, String label, Color color, String sublabel) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color),
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              sublabel,
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color),
            ),
          ),
        ],
      ),
    );
  }

  /// Calculate bounds for a list of LatLng points
  LatLngBounds _getBoundsForPoints(List<LatLng> points) {
    double south = points.first.latitude;
    double north = points.first.latitude;
    double west = points.first.longitude;
    double east = points.first.longitude;

    for (final point in points) {
      if (point.latitude < south) south = point.latitude;
      if (point.latitude > north) north = point.latitude;
      if (point.longitude < west) west = point.longitude;
      if (point.longitude > east) east = point.longitude;
    }

    return LatLngBounds(
      southwest: LatLng(south, west),
      northeast: LatLng(north, east),
    );
  }
}
