import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static SharedPreferences? _prefs;

  // Key names to prevent typos across the app
  static const String _keyActiveSemester = 'active_semester';

  // Micro-task 5.1.1: Initialize SharedPreferences on the device storage drive
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    print("SUCCESS: Local Settings Service Engine Initialized.");
  }

  // Micro-task 5.1.2: Get active semester with a fallback ("S5")
  static String getActiveSemester() {
    if (_prefs == null) return 'S5'; // Safe fallback if engine isn't ready

    // Read the cached string. If it's empty, default to "S5"
    return _prefs!.getString(_keyActiveSemester) ?? 'S5';
  }

  // Micro-task 5.1.2: Set active semester instantly to local storage
  static Future<bool> setActiveSemester(String semester) async {
    if (_prefs == null) return false;

    print("SAVING LOCAL STATE: Active semester locked to -> $semester");
    return await _prefs!.setString(_keyActiveSemester, semester);
  }
}
