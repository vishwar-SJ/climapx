import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/theme.dart';
import 'location_gate_screen.dart';

/// Onboarding Screen - Beautiful first-time user experience
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_OnboardingPage> _pages = const [
    _OnboardingPage(
      icon: Icons.eco,
      title: 'Welcome to ClimapX',
      subtitle: 'AI-Powered Climate Safety',
      description:
          'Your personal guardian against environmental hazards. '
          'ClimapX uses real-time data from NASA, NDMA & global air quality networks '
          'to keep you safe — every moment, everywhere in India.',
      gradient: [Color(0xFF2E7D32), Color(0xFF1B5E20)],
      illustration: '🌍',
    ),
    _OnboardingPage(
      icon: Icons.air,
      title: 'Real-Time Air Quality',
      subtitle: 'Breathe Safe',
      description:
          'Monitor AQI from 10,000+ stations across India using the NAQI standard. '
          'Get PM2.5, PM10, NO₂, O₃ levels & personalized health advice '
          'based on your exact location.',
      gradient: [Color(0xFF546E7A), Color(0xFF37474F)],
      illustration: '🌫️',
    ),
    _OnboardingPage(
      icon: Icons.whatshot,
      title: 'Heatwave & Flood Alerts',
      subtitle: 'Stay Ahead of Danger',
      description:
          'Automatic detection of heat stress (35°C-48°C thresholds) and '
          'flood risk from rainfall intensity. Get life-saving advisories '
          'and hydration reminders before it\'s too late.',
      gradient: [Color(0xFFE65100), Color(0xFFBF360C)],
      illustration: '🔥',
    ),
    _OnboardingPage(
      icon: Icons.local_fire_department,
      title: 'Wildfire Detection',
      subtitle: 'NASA Satellite Tracking',
      description:
          'VIIRS satellite fire hotspot data from NASA FIRMS scanned every 12 hours. '
          'Know about wildfires within 50 km of you — before the smoke reaches you.',
      gradient: [Color(0xFFC62828), Color(0xFF8E0000)],
      illustration: '🛰️',
    ),
    _OnboardingPage(
      icon: Icons.emergency,
      title: 'Emergency Mode',
      subtitle: 'One-Tap Safety',
      description:
          'Auto-activates during extreme conditions. Instantly finds hospitals, '
          'shelters, fire stations & evacuation routes near you. '
          'Quick-dial 112, 108 & NDMA 1078 with one tap.',
      gradient: [Color(0xFF880E4F), Color(0xFF4A0028)],
      illustration: '🚨',
    ),
    _OnboardingPage(
      icon: Icons.shield,
      title: 'Personal Exposure Score',
      subtitle: 'Your Climate Health Index',
      description:
          'A weighted score combining air quality (35%), heat (25%), flood (20%), '
          'wildfire (10%) & water quality (10%). Get personalized recommendations '
          'to reduce your risk throughout the day.',
      gradient: [Color(0xFF00695C), Color(0xFF004D40)],
      illustration: '🛡️',
    ),
  ];

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const LocationGateScreen(),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 600),
        ),
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Page View
          PageView.builder(
            controller: _pageController,
            itemCount: _pages.length,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemBuilder: (context, index) {
              final page = _pages[index];
              return _buildPage(page, index);
            },
          ),

          // Skip Button
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 20,
            child: _currentPage < _pages.length - 1
                ? TextButton(
                    onPressed: _completeOnboarding,
                    child: Text(
                      'Skip',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          // Bottom Navigation
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomNav(),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(_OnboardingPage page, int index) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            page.gradient[0],
            page.gradient[1],
            page.gradient[1].withValues(alpha: 0.95),
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 2),
              // Large Illustration
              Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(40),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    page.illustration,
                    style: const TextStyle(fontSize: 80),
                  ),
                ),
              )
                  .animate()
                  .fadeIn(duration: 600.ms)
                  .scale(begin: const Offset(0.5, 0.5), end: const Offset(1, 1), curve: Curves.elasticOut, duration: 800.ms),
              const SizedBox(height: 48),
              // Title
              Text(
                page.title,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 200.ms, duration: 500.ms).slideY(begin: 0.3, end: 0),
              const SizedBox(height: 8),
              // Subtitle
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  page.subtitle,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70,
                    letterSpacing: 1,
                  ),
                ),
              ).animate().fadeIn(delay: 350.ms, duration: 500.ms),
              const SizedBox(height: 28),
              // Description
              Text(
                page.description,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.white.withValues(alpha: 0.85),
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 500.ms, duration: 500.ms),
              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    final isLast = _currentPage == _pages.length - 1;

    return Container(
      padding: EdgeInsets.only(
        left: 32,
        right: 32,
        bottom: MediaQuery.of(context).padding.bottom + 24,
        top: 16,
      ),
      child: Row(
        children: [
          // Page Indicators
          Row(
            children: List.generate(_pages.length, (index) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: index == _currentPage ? 28 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: index == _currentPage
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
          const Spacer(),
          // Next / Get Started Button
          GestureDetector(
            onTap: _nextPage,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: EdgeInsets.symmetric(
                horizontal: isLast ? 28 : 20,
                vertical: 14,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(isLast ? 16 : 30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isLast) ...[
                    const Text(
                      'Get Started',
                      style: TextStyle(
                        color: AppTheme.primaryDark,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Icon(
                    isLast ? Icons.arrow_forward : Icons.arrow_forward_ios,
                    color: AppTheme.primaryDark,
                    size: isLast ? 20 : 18,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingPage {
  final IconData icon;
  final String title;
  final String subtitle;
  final String description;
  final List<Color> gradient;
  final String illustration;

  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.gradient,
    required this.illustration,
  });
}
