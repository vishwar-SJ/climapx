import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme.dart';
import '../../providers/climate_provider.dart';
import '../../models/safe_place_model.dart';
import '../../widgets/safe_place_tile.dart';

/// Emergency Screen - Evacuation routes, shelters, hospitals
class EmergencyScreen extends StatefulWidget {
  const EmergencyScreen({super.key});

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isSearching = false;

  final List<_EmergencyTab> _tabs = [
    _EmergencyTab('All', Icons.emergency, null),
    _EmergencyTab('Hospitals', Icons.local_hospital, SafePlaceType.hospital),
    _EmergencyTab('Shelters', Icons.night_shelter, SafePlaceType.shelter),
    _EmergencyTab('Fire', Icons.fire_truck, SafePlaceType.fireStation),
    _EmergencyTab('Police', Icons.local_police, SafePlaceType.policeStation),
    _EmergencyTab('Pharmacy', Icons.local_pharmacy, SafePlaceType.pharmacy),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _loadEmergencyData();
  }

  Future<void> _loadEmergencyData() async {
    setState(() => _isSearching = true);
    final provider = context.read<ClimateProvider>();
    await provider.activateEmergencyMode();
    setState(() => _isSearching = false);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ClimateProvider>(
      builder: (context, provider, child) {
        return Column(
          children: [
            // Emergency Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.riskEmergency,
                    AppTheme.riskEmergency.withValues(alpha: 0.8),
                  ],
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.emergency, color: Colors.white, size: 28),
                        SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Emergency Response',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                'Find nearest safe zones & emergency services',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Quick Emergency Actions
                    Row(
                      children: [
                        _quickAction('🚨 Call 112', () => _makeCall('112')),
                        const SizedBox(width: 8),
                        _quickAction('🚑 Call 108', () => _makeCall('108')),
                        const SizedBox(width: 8),
                        _quickAction('⛑️ NDMA 1078', () => _makeCall('1078')),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Tab Bar
            Container(
              color: Colors.white,
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                indicatorColor: AppTheme.riskEmergency,
                labelColor: AppTheme.riskEmergency,
                unselectedLabelColor: Colors.grey,
                tabAlignment: TabAlignment.start,
                tabs: _tabs.map((tab) {
                  return Tab(
                    child: Row(
                      children: [
                        Icon(tab.icon, size: 18),
                        const SizedBox(width: 6),
                        Text(tab.label, style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),

            // Content
            Expanded(
              child: _isSearching
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: AppTheme.riskEmergency),
                          SizedBox(height: 16),
                          Text('Searching for nearby safe places...'),
                        ],
                      ),
                    )
                  : TabBarView(
                      controller: _tabController,
                      children: _tabs.map((tab) {
                        return _buildPlaceList(provider, tab.type);
                      }).toList(),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _quickAction(String label, VoidCallback onTap) {
    return Expanded(
      child: Material(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceList(ClimateProvider provider, SafePlaceType? type) {
    List<SafePlace> places;

    if (type == null) {
      // All places
      places = provider.nearbyPlaces.values
          .expand((list) => list)
          .toList();
    } else {
      places = provider.nearbyPlaces[type] ?? [];
    }

    if (places.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'No places found nearby',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _loadEmergencyData,
              child: const Text('Search Again'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadEmergencyData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: places.length,
        itemBuilder: (context, index) {
          final place = places[index];
          return SafePlaceTile(
            place: place,
            onNavigate: () => _navigateToPlace(place),
            onCall: place.phoneNumber != null
                ? () => _makeCall(place.phoneNumber!)
                : null,
          );
        },
      ),
    );
  }

  Future<void> _makeCall(String number) async {
    final uri = Uri.parse('tel:$number');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _navigateToPlace(SafePlace place) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&destination=${place.lat},${place.lng}'
      '&travelmode=driving',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _EmergencyTab {
  final String label;
  final IconData icon;
  final SafePlaceType? type;

  _EmergencyTab(this.label, this.icon, this.type);
}
