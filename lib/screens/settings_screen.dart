import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme.dart';

/// Settings Screen - App preferences and about
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _aqiAlerts = true;
  bool _heatAlerts = true;
  bool _floodAlerts = true;
  bool _wildfireAlerts = true;
  bool _autoEmergencyMode = true;
  double _alertRadius = 10.0;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notifications') ?? true;
      _aqiAlerts = prefs.getBool('aqi_alerts') ?? true;
      _heatAlerts = prefs.getBool('heat_alerts') ?? true;
      _floodAlerts = prefs.getBool('flood_alerts') ?? true;
      _wildfireAlerts = prefs.getBool('wildfire_alerts') ?? true;
      _autoEmergencyMode = prefs.getBool('auto_emergency') ?? true;
      _alertRadius = prefs.getDouble('alert_radius') ?? 10.0;
    });
  }

  Future<void> _savePreference(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) await prefs.setBool(key, value);
    if (value is double) await prefs.setDouble(key, value);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // App Header
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(
                  colors: [AppTheme.primaryGreen, AppTheme.primaryDark],
                ),
              ),
              child: const Column(
                children: [
                  Icon(Icons.eco, color: Colors.white, size: 48),
                  SizedBox(height: 12),
                  Text(
                    'ClimapX',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                  Text(
                    'AI Climate Safety for India',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Version 1.0.0',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Notification Settings
          _sectionTitle('🔔 Notifications'),
          _settingSwitch(
            'Enable Notifications',
            'Get real-time climate safety alerts',
            _notificationsEnabled,
            (val) {
              setState(() => _notificationsEnabled = val);
              _savePreference('notifications', val);
            },
          ),
          _settingSwitch(
            'Air Quality Alerts',
            'Alert when AQI exceeds safe levels',
            _aqiAlerts,
            (val) {
              setState(() => _aqiAlerts = val);
              _savePreference('aqi_alerts', val);
            },
          ),
          _settingSwitch(
            'Heatwave Alerts',
            'Alert when temperature crosses danger levels',
            _heatAlerts,
            (val) {
              setState(() => _heatAlerts = val);
              _savePreference('heat_alerts', val);
            },
          ),
          _settingSwitch(
            'Flood Alerts',
            'Alert for heavy rainfall and flood risk areas',
            _floodAlerts,
            (val) {
              setState(() => _floodAlerts = val);
              _savePreference('flood_alerts', val);
            },
          ),
          _settingSwitch(
            'Wildfire Alerts',
            'Alert when fire hotspots detected nearby (NASA FIRMS)',
            _wildfireAlerts,
            (val) {
              setState(() => _wildfireAlerts = val);
              _savePreference('wildfire_alerts', val);
            },
          ),
          const SizedBox(height: 24),

          // Safety Settings
          _sectionTitle('🛡️ Safety Settings'),
          _settingSwitch(
            'Auto Emergency Mode',
            'Automatically activate emergency mode during disasters',
            _autoEmergencyMode,
            (val) {
              setState(() => _autoEmergencyMode = val);
              _savePreference('auto_emergency', val);
            },
          ),
          // Alert Radius Slider
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Alert Radius',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  Text(
                    'Get alerts for events within ${_alertRadius.toStringAsFixed(0)} km',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  Slider(
                    value: _alertRadius,
                    min: 5,
                    max: 100,
                    divisions: 19,
                    label: '${_alertRadius.toStringAsFixed(0)} km',
                    thumbColor: AppTheme.primaryGreen,
                    onChanged: (val) {
                      setState(() => _alertRadius = val);
                      _savePreference('alert_radius', val);
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Data Sources
          _sectionTitle('📡 Data Sources'),
          _infoCard('Air Quality', 'AQICN (waqi.info) + Google Air Quality API'),
          _infoCard('Weather & Heat', 'OpenWeatherMap API'),
          _infoCard('Disaster Alerts', 'NDMA India (ndma.gov.in)'),
          _infoCard('Wildfire Detection', 'NASA FIRMS (VIIRS Satellite)'),
          _infoCard('Maps & Navigation', 'Google Maps Platform'),
          const SizedBox(height: 24),

          // About
          _sectionTitle('ℹ️ About ClimapX'),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'ClimapX is an AI-powered climate safety application designed to protect '
                'people from environmental and climate-related health hazards in India. '
                'It provides real-time monitoring, predictive exposure analysis, and '
                'emergency response capabilities for air pollution, heatwaves, floods, '
                'wildfires, and water contamination.',
                style: TextStyle(fontSize: 13, height: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _settingSwitch(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: SwitchListTile(
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        value: value,
        onChanged: onChanged,
        activeTrackColor: AppTheme.primaryGreen.withValues(alpha: 0.5),
        thumbColor: WidgetStatePropertyAll(AppTheme.primaryGreen),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Widget _infoCard(String title, String source) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        dense: true,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(source, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.verified, color: AppTheme.primaryGreen, size: 20),
      ),
    );
  }
}
