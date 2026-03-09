import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../core/theme.dart';
import '../../providers/climate_provider.dart';
import '../../services/route_optimization_service.dart';

/// Journey Planner Screen — Pollution-aware routing with optimal departure times
class JourneyPlannerScreen extends StatefulWidget {
  const JourneyPlannerScreen({super.key});

  @override
  State<JourneyPlannerScreen> createState() => _JourneyPlannerScreenState();
}

class _JourneyPlannerScreenState extends State<JourneyPlannerScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _destinationController = TextEditingController();
  late TabController _tabController;

  // State
  bool _isSearching = false;
  bool _isLoadingRoutes = false;
  bool _isLoadingTimes = false;
  List<_PlaceSuggestion> _suggestions = [];
  List<ScoredRoute> _routes = [];
  List<DepartureRecommendation> _departureTimes = [];
  ScoredRoute? _selectedRoute;
  GoogleMapController? _mapController;
  LatLng? _destinationLatLng;
  String? _destinationName;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _destinationController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  /// Search for places using Google Places Autocomplete
  Future<void> _searchPlaces(String query) async {
    if (query.length < 3) {
      setState(() => _suggestions = []);
      return;
    }

    setState(() => _isSearching = true);

    try {
      final apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
      if (apiKey.isEmpty) {
        setState(() => _isSearching = false);
        return;
      }

      final provider = context.read<ClimateProvider>();
      final url = 'https://maps.googleapis.com/maps/api/place/autocomplete/json'
          '?input=${Uri.encodeComponent(query)}'
          '&location=${provider.latitude},${provider.longitude}'
          '&radius=50000'
          '&components=country:in'
          '&key=$apiKey';

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final predictions = json['predictions'] as List? ?? [];
        setState(() {
          _suggestions = predictions
              .map((p) => _PlaceSuggestion(
                    placeId: p['place_id'] ?? '',
                    description: p['description'] ?? '',
                    mainText: p['structured_formatting']?['main_text'] ?? '',
                  ))
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Place search error: $e');
    }

    setState(() => _isSearching = false);
  }

  /// Get LatLng from place ID and start route calculation
  Future<void> _selectPlace(_PlaceSuggestion suggestion) async {
    setState(() {
      _destinationController.text = suggestion.mainText;
      _destinationName = suggestion.mainText;
      _suggestions = [];
    });

    try {
      final apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
      final url = 'https://maps.googleapis.com/maps/api/place/details/json'
          '?place_id=${suggestion.placeId}'
          '&fields=geometry'
          '&key=$apiKey';

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final loc = json['result']?['geometry']?['location'];
        if (loc != null) {
          _destinationLatLng = LatLng(
            (loc['lat'] as num).toDouble(),
            (loc['lng'] as num).toDouble(),
          );
          _fetchRoutesAndTimes();
        }
      }
    } catch (e) {
      debugPrint('Place details error: $e');
    }
  }

  /// Fetch pollution-optimized routes AND optimal departure times sequentially
  /// to prevent memory pressure from parallel heavy operations.
  Future<void> _fetchRoutesAndTimes() async {
    if (_destinationLatLng == null) return;
    if (!mounted) return;
    final provider = context.read<ClimateProvider>();

    setState(() {
      _isLoadingRoutes = true;
      _isLoadingTimes = true;
      _selectedRoute = null;
      _routes = [];
      _departureTimes = [];
    });

    final origin = LatLng(provider.latitude, provider.longitude);

    // Step 1: Fetch routes first (the heavier operation)
    try {
      final routes = await RouteOptimizationService.getOptimizedRoutes(
        origin: origin,
        destination: _destinationLatLng!,
        currentAqi: provider.airQuality,
        currentWeather: provider.weather,
      );
      if (!mounted) return;
      setState(() {
        _routes = routes;
        _selectedRoute = routes.isNotEmpty ? routes.first : null;
        _isLoadingRoutes = false;
      });
      if (_selectedRoute != null && _mapController != null) {
        _zoomToRoute(_selectedRoute!);
      }
    } catch (e) {
      debugPrint('Route fetch error: $e');
      if (!mounted) return;
      setState(() => _isLoadingRoutes = false);
    }

    // Step 2: Then fetch departure times
    try {
      final times = await RouteOptimizationService.getOptimalDepartureTimes(
        lat: provider.latitude,
        lng: provider.longitude,
        currentAqi: provider.airQuality?.aqi,
      );
      if (!mounted) return;
      setState(() {
        _departureTimes = times;
        _isLoadingTimes = false;
      });
    } catch (e) {
      debugPrint('Departure time error: $e');
      if (!mounted) return;
      setState(() => _isLoadingTimes = false);
    }
  }

  void _zoomToRoute(ScoredRoute route) {
    if (route.polylinePoints.isEmpty || _mapController == null) return;
    double south = route.polylinePoints.first.latitude;
    double north = south;
    double west = route.polylinePoints.first.longitude;
    double east = west;
    for (final p in route.polylinePoints) {
      if (p.latitude < south) south = p.latitude;
      if (p.latitude > north) north = p.latitude;
      if (p.longitude < west) west = p.longitude;
      if (p.longitude > east) east = p.longitude;
    }
    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(
      LatLngBounds(
        southwest: LatLng(south, west),
        northeast: LatLng(north, east),
      ),
      60,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Journey Planner'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.primaryDark, AppTheme.primaryGreen],
            ),
          ),
        ),
        bottom: _destinationLatLng != null
            ? TabBar(
                controller: _tabController,
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white60,
                tabs: const [
                  Tab(icon: Icon(Icons.route, size: 20), text: 'Routes'),
                  Tab(icon: Icon(Icons.schedule, size: 20), text: 'Best Time'),
                ],
              )
            : null,
      ),
      body: Column(
        children: [
          // Search Bar
          _buildSearchBar(),

          // Content
          Expanded(
            child: _destinationLatLng == null
                ? _buildEmptyState()
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildRoutesTab(),
                      _buildTimesTab(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Origin (current location)
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.my_location, size: 16, color: AppTheme.primaryGreen),
              ),
              const SizedBox(width: 12),
              Text(
                'Your Location',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          // Dotted line connector
          Padding(
            padding: const EdgeInsets.only(left: 15),
            child: Column(
              children: List.generate(3, (_) => Container(
                width: 2, height: 4,
                margin: const EdgeInsets.symmetric(vertical: 1),
                color: Colors.grey.shade300,
              )),
            ),
          ),
          // Destination input
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.location_on, size: 16, color: Colors.red.shade400),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _destinationController,
                  onChanged: _searchPlaces,
                  decoration: InputDecoration(
                    hintText: 'Enter destination...',
                    hintStyle: TextStyle(color: Colors.grey.shade400),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    suffixIcon: _destinationController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.close, size: 18, color: Colors.grey.shade500),
                            onPressed: () {
                              _destinationController.clear();
                              setState(() {
                                _suggestions = [];
                                _destinationLatLng = null;
                                _routes = [];
                                _departureTimes = [];
                                _selectedRoute = null;
                              });
                            },
                          )
                        : null,
                  ),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          // Suggestions dropdown
          if (_suggestions.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 8),
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _suggestions.length,
                separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade100),
                itemBuilder: (context, index) {
                  final s = _suggestions[index];
                  return ListTile(
                    dense: true,
                    leading: Icon(Icons.place, color: Colors.grey.shade500, size: 20),
                    title: Text(s.mainText, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: Text(
                      s.description,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => _selectPlace(s),
                  );
                },
              ),
            ),
          if (_isSearching)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(color: AppTheme.primaryGreen, minHeight: 2),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.route, size: 48, color: AppTheme.primaryGreen),
          ),
          const SizedBox(height: 24),
          Text(
            'Plan a Safe Journey',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'Enter a destination above to get pollution-optimized routes and the best departure time.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500, height: 1.5),
            ),
          ),
          const SizedBox(height: 32),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _featureChip(Icons.air, 'AQI-aware routing'),
              _featureChip(Icons.schedule, 'Best start time'),
              _featureChip(Icons.thermostat, 'Heat risk check'),
              _featureChip(Icons.flood, 'Flood zone avoidance'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _featureChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.primaryGreen.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppTheme.primaryGreen),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.primaryGreen, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────
  //  ROUTES TAB
  // ───────────────────────────────────────────────────────────────

  Widget _buildRoutesTab() {
    if (_isLoadingRoutes) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppTheme.primaryGreen),
            SizedBox(height: 16),
            Text('Analyzing routes for pollution & safety...'),
          ],
        ),
      );
    }

    if (_routes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text('Could not find routes. Try another destination.'),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Map
        SizedBox(
          height: 200,
          child: _buildRouteMap(),
        ),
        // Route list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: _routes.length,
            itemBuilder: (context, index) {
              return _buildRouteCard(_routes[index], index)
                  .animate()
                  .fadeIn(delay: (index * 100).ms, duration: 300.ms)
                  .slideY(begin: 0.1, end: 0);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRouteMap() {
    final provider = context.read<ClimateProvider>();
    final origin = LatLng(provider.latitude, provider.longitude);

    return GoogleMap(
      initialCameraPosition: CameraPosition(target: origin, zoom: 12),
      onMapCreated: (c) {
        _mapController = c;
        if (_selectedRoute != null) _zoomToRoute(_selectedRoute!);
      },
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      polylines: _buildRoutePolylines(),
      markers: {
        Marker(
          markerId: const MarkerId('origin'),
          position: origin,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: const InfoWindow(title: 'Your Location'),
        ),
        if (_destinationLatLng != null)
          Marker(
            markerId: const MarkerId('destination'),
            position: _destinationLatLng!,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            infoWindow: InfoWindow(title: _destinationName ?? 'Destination'),
          ),
      },
    );
  }

  Set<Polyline> _buildRoutePolylines() {
    final polylines = <Polyline>{};
    for (int i = 0; i < _routes.length; i++) {
      final route = _routes[i];
      final isSelected = route == _selectedRoute;
      polylines.add(Polyline(
        polylineId: PolylineId('route_$i'),
        points: route.polylinePoints,
        color: isSelected
            ? _getRouteColor(route.overallRiskScore)
            : Colors.grey.shade400,
        width: isSelected ? 5 : 3,
        patterns: isSelected ? [] : [PatternItem.dash(10), PatternItem.gap(8)],
      ));
    }
    return polylines;
  }

  Color _getRouteColor(double riskScore) {
    if (riskScore < 25) return AppTheme.riskGood;
    if (riskScore < 50) return AppTheme.riskModerate;
    if (riskScore < 75) return AppTheme.riskPoor;
    return AppTheme.riskSevere;
  }

  Widget _buildRouteCard(ScoredRoute route, int index) {
    final isSelected = route == _selectedRoute;
    final color = _getRouteColor(route.overallRiskScore);
    final isBest = index == 0;

    return GestureDetector(
      onTap: () {
        setState(() => _selectedRoute = route);
        _zoomToRoute(route);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 8)]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.directions_car, color: color, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'via ${route.summary}',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                          if (isBest) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryGreen,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'SAFEST',
                                style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        '${route.distance} • ${route.duration}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                // Risk score badge
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 2.5),
                    color: color.withValues(alpha: 0.08),
                  ),
                  child: Center(
                    child: Text(
                      route.overallRiskScore.toStringAsFixed(0),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: color,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Risk breakdown bars
            const SizedBox(height: 12),
            _riskBar('Air Pollution', route.pollutionScore, AppTheme.airPollution),
            const SizedBox(height: 4),
            _riskBar('Heat Stress', route.heatScore, AppTheme.heatwave),
            const SizedBox(height: 4),
            _riskBar('Flood Risk', route.floodScore, AppTheme.flood),

            // Warnings
            if (route.warnings.isNotEmpty) ...[
              const SizedBox(height: 10),
              ...route.warnings.map((w) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(w, style: TextStyle(fontSize: 12, color: Colors.orange.shade800)),
                  )),
            ],
          ],
        ),
      ),
    );
  }

  Widget _riskBar(String label, double value, Color color) {
    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: (value / 100).clamp(0.0, 1.0),
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 24,
          child: Text(
            value.toStringAsFixed(0),
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────
  //  BEST TIME TAB
  // ───────────────────────────────────────────────────────────────

  Widget _buildTimesTab() {
    if (_isLoadingTimes) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppTheme.primaryGreen),
            SizedBox(height: 16),
            Text('Analyzing weather & pollution patterns...'),
          ],
        ),
      );
    }

    if (_departureTimes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text('Could not analyze departure times.'),
          ],
        ),
      );
    }

    // Separate top 5 best times and rest
    final bestTimes = _departureTimes.take(5).toList();
    final otherTimes = _departureTimes.skip(5).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Best departure time highlight
          _buildBestTimeCard(bestTimes.first)
              .animate()
              .fadeIn(duration: 400.ms)
              .slideY(begin: 0.1, end: 0),

          const SizedBox(height: 20),

          // How it works
          _buildHowItWorksCard()
              .animate()
              .fadeIn(delay: 100.ms, duration: 400.ms),

          const SizedBox(height: 20),

          // Top 5 recommendations
          Text(
            '🏆 Top 5 Best Times',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.grey.shade800),
          ),
          const SizedBox(height: 10),
          ...bestTimes.asMap().entries.map((entry) {
            return _buildTimeSlotCard(entry.value, entry.key)
                .animate()
                .fadeIn(delay: ((entry.key + 1) * 100).ms, duration: 300.ms)
                .slideX(begin: 0.05, end: 0);
          }),

          const SizedBox(height: 16),

          // 24-hour breakdown
          ExpansionTile(
            title: Text(
              '📊 Full 24-Hour Breakdown',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.grey.shade700),
            ),
            children: otherTimes.map((t) => _buildTimeSlotCard(t, -1)).toList(),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildBestTimeCard(DepartureRecommendation best) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primaryGreen.withValues(alpha: 0.12),
              Colors.white,
            ],
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.schedule, size: 30, color: AppTheme.primaryGreen),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Best Departure Time',
                        style: TextStyle(fontSize: 12, color: AppTheme.primaryGreen, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        best.timeLabel,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.primaryDark,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.riskGood.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Risk ${best.riskScore.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.riskGood,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              best.reason,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700, height: 1.4),
            ),
            const SizedBox(height: 14),
            // Expected conditions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _conditionChip(Icons.air, 'AQI ~${best.expectedAqi}', AppTheme.airPollution),
                _conditionChip(Icons.thermostat, '${best.expectedTemp.toStringAsFixed(0)}°C', AppTheme.heatwave),
                _conditionChip(Icons.water_drop, '${best.expectedRain.toStringAsFixed(1)} mm', AppTheme.flood),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _conditionChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }

  Widget _buildHowItWorksCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline, color: Colors.blue.shade700, size: 18),
              const SizedBox(width: 8),
              Text(
                'How We Calculate This',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.blue.shade800),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '• AQI patterns from CPCB data — pollution is lowest 5-8 AM\n'
            '• Weather forecast from OpenWeatherMap — temperature & rain\n'
            '• Rush-hour traffic peaks factored in (9-10 AM, 5-7 PM)\n'
            '• Night inversion effect (10 PM-3 AM traps pollutants)',
            style: TextStyle(fontSize: 12, color: Colors.blue.shade700, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeSlotCard(DepartureRecommendation time, int rank) {
    final color = _getRouteColor(time.riskScore);
    final isBest = rank == 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isBest ? color : Colors.grey.shade200,
          width: isBest ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          // Time
          SizedBox(
            width: 70,
            child: Text(
              time.timeLabel,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Colors.grey.shade800,
              ),
            ),
          ),
          // Risk bar
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: (time.riskScore / 100).clamp(0.0, 1.0),
                    backgroundColor: Colors.grey.shade100,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  time.reason,
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Score
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2),
              color: color.withValues(alpha: 0.08),
            ),
            child: Center(
              child: Text(
                time.riskScore.toStringAsFixed(0),
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: color),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Place autocomplete suggestion
class _PlaceSuggestion {
  final String placeId;
  final String description;
  final String mainText;

  _PlaceSuggestion({
    required this.placeId,
    required this.description,
    required this.mainText,
  });
}
