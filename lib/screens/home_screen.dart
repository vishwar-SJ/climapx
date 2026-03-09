import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/theme.dart';
import '../providers/climate_provider.dart';
import 'map_screen.dart';
import 'dashboard_screen.dart';
import 'emergency_screen.dart';
import 'alerts_screen.dart';
import 'settings_screen.dart';

/// Home Screen - Main navigation shell with Material 3 NavigationBar
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    DashboardScreen(),
    MapScreen(),
    EmergencyScreen(),
    AlertsScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ClimateProvider>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ClimateProvider>(
      builder: (context, provider, child) {
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: _currentIndex == 1
              ? SystemUiOverlayStyle.dark
              : const SystemUiOverlayStyle(
                  statusBarColor: Colors.transparent,
                  statusBarIconBrightness: Brightness.light,
                ),
          child: Scaffold(
            extendBody: true,
            appBar: _currentIndex != 1 && _currentIndex != 2
                ? _buildAppBar(provider)
                : null,
            body: IndexedStack(
              index: _currentIndex,
              children: _screens,
            ),
            bottomNavigationBar: _buildNavigationBar(provider),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(ClimateProvider provider) {
    return AppBar(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.eco, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          Text(_getTitle()),
        ],
      ),
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.primaryDark, AppTheme.primaryGreen],
          ),
        ),
      ),
      actions: [
        if (provider.hasActiveDisaster)
          IconButton(
            onPressed: () => setState(() => _currentIndex = 3),
            icon: Badge(
              label: Text('${provider.activeAlerts.length}'),
              backgroundColor: Colors.red,
              child: const Icon(Icons.notifications_active),
            ),
          ).animate(onPlay: (c) => c.repeat(reverse: true))
              .shimmer(duration: 1500.ms, color: Colors.white38),
        IconButton(
          onPressed: () => provider.refreshAllData(),
          icon: provider.isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Icon(Icons.refresh_rounded),
          tooltip: 'Refresh Data',
        ),
      ],
      elevation: 0,
    );
  }

  Widget _buildNavigationBar(ClimateProvider provider) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) =>
              setState(() => _currentIndex = index),
          backgroundColor: Colors.white,
          indicatorColor: AppTheme.primaryGreen.withValues(alpha: 0.12),
          surfaceTintColor: Colors.transparent,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          height: 70,
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon:
                  Icon(Icons.dashboard, color: AppTheme.primaryGreen),
              label: 'Dashboard',
            ),
            const NavigationDestination(
              icon: Icon(Icons.map_outlined),
              selectedIcon: Icon(Icons.map, color: AppTheme.primaryGreen),
              label: 'Map',
            ),
            NavigationDestination(
              icon: Badge(
                isLabelVisible: provider.isEmergencyMode,
                backgroundColor: AppTheme.riskEmergency,
                child: Icon(
                  Icons.emergency_outlined,
                  color: provider.isEmergencyMode
                      ? AppTheme.riskEmergency
                      : null,
                ),
              ),
              selectedIcon: Icon(
                Icons.emergency,
                color: provider.isEmergencyMode
                    ? AppTheme.riskEmergency
                    : AppTheme.primaryGreen,
              ),
              label: 'Emergency',
            ),
            NavigationDestination(
              icon: Badge(
                isLabelVisible: provider.hasActiveDisaster,
                label: Text('${provider.activeAlerts.length}'),
                child: const Icon(Icons.notifications_outlined),
              ),
              selectedIcon: Badge(
                isLabelVisible: provider.hasActiveDisaster,
                label: Text('${provider.activeAlerts.length}'),
                child: const Icon(Icons.notifications,
                    color: AppTheme.primaryGreen),
              ),
              label: 'Alerts',
            ),
            const NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon:
                  Icon(Icons.settings, color: AppTheme.primaryGreen),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }

  String _getTitle() {
    switch (_currentIndex) {
      case 0:
        return 'Dashboard';
      case 3:
        return 'Alerts';
      case 4:
        return 'Settings';
      default:
        return 'ClimapX';
    }
  }
}
