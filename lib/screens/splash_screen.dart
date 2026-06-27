import 'dart:async';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'main_navigation_hub.dart'; // Import your main screen wrapper here (e.g. main_navigation.dart or dashboard_screen.dart)
import '../services/google_sheets_service.dart'; // Adjust path if needed
// For this example, we will assume it goes to DashboardScreen, but change this
// to your main bottom-navigation tab wrapper if you have one!

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_animationController);
    _animationController.forward();

    // --- THE NEW SMART BOOT TRIGGER ---
    _bootSequence();
  }

  Future<void> _bootSequence() async {
    // 1. Give the animation 1 second to show off your logo
    await Future.delayed(const Duration(milliseconds: 1000));

    // 2. Fire the login sequence!
    // (This will pop open Chrome on Windows, or silently auth on Mobile)
    print("Initiating cross-platform login...");
    bool loginSuccess = await AuthService.login();

    if (mounted) {
      if (loginSuccess) {
        // --- THE FIX: OPEN THE DATABASE ---
        print("Login successful! Initializing the database...");
        await GoogleSheetsService.init(); // Make sure this matches your actual init function name!

        // Now slide to the Main Navigation Wrapper
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainNavigationHub()),
        );
      } else {
        print("LOGIN FAILED OR CANCELLED BY USER");
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Grab the total width of the current screen
    double screenWidth = MediaQuery.of(context).size.width;

    // If the screen is wider than 800px (Desktop), make the logo 400px.
    // Otherwise (Phone), keep it at a comfortable 200px.
    double dynamicLogoSize = screenWidth > 800 ? 400.0 : 200.0;

    return Scaffold(
      backgroundColor: const Color(
        0xFFFFFFFF,
      ), // Pure white background for the splash screen
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // No more white box needed once you export with transparency!
              Image.asset(
                'assets/images/logo.png',
                width: dynamicLogoSize,
                height: dynamicLogoSize,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
