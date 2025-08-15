import 'package:shared_preferences/shared_preferences.dart';

class PrefsHelper {
  static const String _keyOnboardingCompleted = 'onboarding_completed';
  static const String _keySelectedTheme =
      'selected_theme'; // System, Light, Dark
  static const String _keyAccentColor = 'accent_color'; // Green, Blue, etc.
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
      case 'System':
        return theme;
      // For backwards compatibility - convert old color themes to default theme with accent
      case 'Green':
      case 'Blue':
      case 'Purple':
      case 'Orange':
      case 'Red':
        saveAccentColor(theme); // Save the color as accent
        return 'System'; // Default to System theme
      default:
        return 'System'; // Default fallback
    }
  }

  // Helper to validate accent color
  static String _validateAccentColor(String? color) {
    // Make sure we only save valid accent colors
    if (color == null) {
      return 'Green';
    }

    switch (color) {
      case 'Green':
      case 'Blue':
      case 'Purple':
      case 'Orange':
      case 'Red':
        return color;
      default:
        return 'Green'; // Default fallback
    }
  }

  // Save accent color
  static Future<void> saveAccentColor(String color) async {
    final prefs = await SharedPreferences.getInstance();
    final validColor = _validateAccentColor(color);
    await prefs.setString(_keyAccentColor, validColor);
  }

  // Get accent color with fallback
  static Future<String> getAccentColor() async {
    final prefs = await SharedPreferences.getInstance();
    final color = prefs.getString(_keyAccentColor);
    return _validateAccentColor(color);
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

  // Reset all app settings to defaults (for debugging)
  static Future<void> resetAllSettings() async {
    final prefs = await SharedPreferences.getInstance();
    // Reset onboarding status
    await prefs.setBool(_keyOnboardingCompleted, false);
    // Reset theme to system default
    await prefs.setString(_keySelectedTheme, 'System');
    // Reset accent color to default green
    await prefs.setString(_keyAccentColor, 'Green');
    // Keep folder path (don't reset) to avoid data loss
  }
}
