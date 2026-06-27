import 'services/settings_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/material.dart';
import 'services/google_sheets_service.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 1. Load hidden environment variables
  await dotenv.load(fileName: ".env");

  // 2. Initialize local device cache
  await SettingsService.init();

  // 3. Initialize Google Cloud connection & trigger login flow
  await GoogleSheetsService.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Studious',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(), // Keeps your global theme dark
      // --- THE ENTRY POINT UPGRADE ---
      home: const SplashScreen(),
    );
  }
}
