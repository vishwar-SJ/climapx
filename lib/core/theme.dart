import 'package:flutter/material.dart';

/// ClimapX App Theme - Climate Safety Design System
class AppTheme {
  // ─── Brand Colors ───
  static const Color primaryGreen = Color(0xFF2E7D32);
  static const Color primaryDark = Color(0xFF1B5E20);
  static const Color accentTeal = Color(0xFF00897B);
  static const Color backgroundLight = Color(0xFFF1F8E9);
  static const Color surfaceWhite = Color(0xFFFFFFFF);
  static const Color textDark = Color(0xFF1A1A2E);
  static const Color textLight = Color(0xFF6B7280);

  // ─── Risk Level Colors ───
  static const Color riskGood = Color(0xFF4CAF50);
  static const Color riskSatisfactory = Color(0xFF8BC34A);
  static const Color riskModerate = Color(0xFFFFC107);
  static const Color riskPoor = Color(0xFFFF9800);
  static const Color riskVeryPoor = Color(0xFFF44336);
  static const Color riskSevere = Color(0xFF880E4F);
  static const Color riskEmergency = Color(0xFFB71C1C);

  // ─── Category Colors ───
  static const Color airPollution = Color(0xFF78909C);
  static const Color heatwave = Color(0xFFFF7043);
  static const Color flood = Color(0xFF42A5F5);
  static const Color wildfire = Color(0xFFEF5350);
  static const Color waterPollution = Color(0xFF5C6BC0);
  static const Color traffic = Color(0xFFAB47BC);

  // ─── Theme Data ───
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorSchemeSeed: primaryGreen,
      scaffoldBackgroundColor: backgroundLight,
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: 1.2,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: surfaceWhite,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surfaceWhite,
        selectedItemColor: primaryGreen,
        unselectedItemColor: textLight,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: textDark),
        headlineMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: textDark),
        titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textDark),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textDark),
        bodyLarge: TextStyle(fontSize: 16, color: textDark),
        bodyMedium: TextStyle(fontSize: 14, color: textLight),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: primaryGreen),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorSchemeSeed: primaryGreen,
      scaffoldBackgroundColor: const Color(0xFF121212),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1E1E1E),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: const Color(0xFF1E1E1E),
      ),
    );
  }

  /// Returns the appropriate color for an AQI value
  static Color getAqiColor(int aqi) {
    if (aqi <= 50) return riskGood;
    if (aqi <= 100) return riskSatisfactory;
    if (aqi <= 200) return riskModerate;
    if (aqi <= 300) return riskPoor;
    if (aqi <= 400) return riskVeryPoor;
    return riskSevere;
  }

  /// Returns the label for an AQI value (India NAQI Standard)
  static String getAqiLabel(int aqi) {
    if (aqi <= 50) return 'Good';
    if (aqi <= 100) return 'Satisfactory';
    if (aqi <= 200) return 'Moderate';
    if (aqi <= 300) return 'Poor';
    if (aqi <= 400) return 'Very Poor';
    return 'Severe';
  }

  /// Returns the color for temperature risk
  static Color getHeatColor(double temp) {
    if (temp < 35) return riskGood;
    if (temp < 40) return riskModerate;
    if (temp < 45) return riskPoor;
    return riskSevere;
  }

  /// Returns the overall risk color
  static Color getRiskColor(double score) {
    if (score < 25) return riskGood;
    if (score < 50) return riskModerate;
    if (score < 75) return riskPoor;
    return riskSevere;
  }
}
