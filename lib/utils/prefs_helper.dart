import 'package:shared_preferences/shared_preferences.dart';

class PrefsHelper {
  static const String _keyOnboardingCompleted = 'onboarding_completed';
  static const String _keySelectedTheme = 'selected_theme';
  static const String _keySelectedFolder = 'selected_folder';

  // Check if onboarding was completed
  static Future<bool> isOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyOnboardingCompleted) ?? false;
  }

  // Mark onboarding as completed
  static Future<void> setOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyOnboardingCompleted, true);
  }

  // Save selected theme with validation
  static Future<void> saveSelectedTheme(String theme) async {
    final prefs = await SharedPreferences.getInstance();
    // Validate theme value before saving
    final validTheme = _validateTheme(theme);
    await prefs.setString(_keySelectedTheme, validTheme);
  }

  // Get selected theme with fallback
  static Future<String> getSelectedTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final theme = prefs.getString(_keySelectedTheme);
    return _validateTheme(theme);
  }

  // Helper to validate theme string
  static String _validateTheme(String? theme) {
    // Make sure we only save valid theme values
    if (theme == null) {
      return 'System';
    }

    switch (theme) {
      case 'Light':
      case 'Dark':
      case 'Green':
      case 'Blue':
      case 'Purple':
      case 'Orange':
      case 'Red':
        return theme;
      default:
        return 'System'; // Default fallback
    }
  }

  // Save selected folder
  static Future<void> saveSelectedFolder(String folderPath) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySelectedFolder, folderPath);
  }

  // Get selected folder
  static Future<String?> getSelectedFolder() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keySelectedFolder);
  }

  // Reset onboarding status (for debugging)
  static Future<void> resetOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyOnboardingCompleted, false);
  }
}
