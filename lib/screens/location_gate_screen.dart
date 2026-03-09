import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../providers/climate_provider.dart';
import 'home_screen.dart';

/// Location Gate Screen - Forces user to enable GPS before entering the app.
/// This screen blocks entry until location is successfully obtained.
class LocationGateScreen extends StatefulWidget {
  const LocationGateScreen({super.key});

  @override
  State<LocationGateScreen> createState() => _LocationGateScreenState();
}

class _LocationGateScreenState extends State<LocationGateScreen>
    with SingleTickerProviderStateMixin {
  bool _isChecking = true;
  String _statusMessage = 'Checking location...';
  String? _errorDetail;
  bool _gpsDeniedForever = false;
  bool _gpsServiceOff = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _checkAndRequestLocation();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _checkAndRequestLocation() async {
    setState(() {
      _isChecking = true;
      _statusMessage = 'Checking location services...';
      _errorDetail = null;
      _gpsDeniedForever = false;
      _gpsServiceOff = false;
    });

    // Step 1: Check if GPS is enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _isChecking = false;
        _gpsServiceOff = true;
        _statusMessage = 'Location is Turned Off';
        _errorDetail =
            'ClimapX needs your GPS location to provide accurate weather, air quality, and safety alerts for your area.\n\nPlease turn on location services to continue.';
      });
      return;
    }

    // Step 2: Check permission
    setState(() => _statusMessage = 'Requesting permission...');
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          _isChecking = false;
          _statusMessage = 'Permission Denied';
          _errorDetail =
              'ClimapX needs location permission to show data for your area.\n\nPlease allow location access to continue.';
        });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        _isChecking = false;
        _gpsDeniedForever = true;
        _statusMessage = 'Permission Blocked';
        _errorDetail =
            'Location permission was permanently denied.\n\nPlease open Settings and enable location access for ClimapX.';
      });
      return;
    }

    // Step 3: Get actual position
    setState(() => _statusMessage = 'Getting your location...');
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 50,
        ),
      ).timeout(const Duration(seconds: 20), onTimeout: () {
        throw Exception('GPS timeout');
      });

      if (!mounted) return;

      // Success! Initialize provider with this location and navigate
      final provider = context.read<ClimateProvider>();
      provider.setLocationAndInitialize(position);

      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const HomeScreen(),
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 600),
        ),
      );
    } catch (e) {
      // Try last known position as a fallback
      try {
        final lastPos = await Geolocator.getLastKnownPosition();
        if (lastPos != null && mounted) {
          final provider = context.read<ClimateProvider>();
          provider.setLocationAndInitialize(lastPos);
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => const HomeScreen(),
              transitionsBuilder: (_, animation, __, child) =>
                  FadeTransition(opacity: animation, child: child),
              transitionDuration: const Duration(milliseconds: 600),
            ),
          );
          return;
        }
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _isChecking = false;
        _statusMessage = 'Could not get location';
        _errorDetail =
            'Unable to determine your position. Please make sure GPS is on and you are in an open area, then try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1B5E20),
              AppTheme.primaryGreen,
              Color(0xFF004D40),
            ],
          ),
        ),
        child: SafeArea(
          child: _isChecking ? _buildLoadingState() : _buildPromptState(),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ScaleTransition(
            scale: _pulseAnimation,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.my_location,
                size: 50,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 30),
          Text(
            _statusMessage,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          const SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPromptState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          // Icon
          ScaleTransition(
            scale: _pulseAnimation,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: Icon(
                _gpsServiceOff
                    ? Icons.location_off
                    : _gpsDeniedForever
                        ? Icons.lock_outline
                        : Icons.location_searching,
                size: 55,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 36),
          // Title
          Text(
            _statusMessage,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          // Detail text
          if (_errorDetail != null)
            Text(
              _errorDetail!,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 15,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          const SizedBox(height: 40),
          // Primary action
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: () async {
                if (_gpsServiceOff) {
                  await Geolocator.openLocationSettings();
                  // Wait for user to toggle GPS then re-check
                  await Future.delayed(const Duration(seconds: 3));
                  _checkAndRequestLocation();
                } else if (_gpsDeniedForever) {
                  await Geolocator.openAppSettings();
                  await Future.delayed(const Duration(seconds: 3));
                  _checkAndRequestLocation();
                } else {
                  _checkAndRequestLocation();
                }
              },
              icon: Icon(
                _gpsServiceOff
                    ? Icons.location_on
                    : _gpsDeniedForever
                        ? Icons.settings
                        : Icons.refresh,
                size: 22,
              ),
              label: Text(
                _gpsServiceOff
                    ? 'Turn On Location'
                    : _gpsDeniedForever
                        ? 'Open App Settings'
                        : 'Try Again',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.primaryDark,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Retry button (always visible)
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _checkAndRequestLocation,
              icon: const Icon(Icons.refresh, size: 20, color: Colors.white),
              label: const Text(
                'Retry',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white54, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),
          // Info card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.white70, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Your location is used only for local weather, air quality & safety alerts. It is never stored on any server.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
