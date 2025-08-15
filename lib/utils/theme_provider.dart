import 'package:flutter/material.dart';
import 'prefs_helper.dart';

class ThemeProvider extends ChangeNotifier {
  String _themeMode;

  ThemeProvider(this._themeMode);

  // Get the string representation of theme mode
  String get themeModeString => _themeMode;

  // Convert string to actual ThemeMode enum for MaterialApp
  ThemeMode get themeMode {
    switch (_themeMode) {
      case 'Dark':
        return ThemeMode.dark;
      case 'Light':
        return ThemeMode.light;
      default:
        return ThemeMode.system;
    }
  }

  // Determine if dark mode is active (either explicitly set or via system)
  bool isDarkMode(BuildContext context) {
    if (_themeMode == 'Dark') {
      return true;
    } else if (_themeMode == 'Light') {
      return false;
    } else {
      // System mode - check the system brightness
      return MediaQuery.of(context).platformBrightness == Brightness.dark;
    }
  }

  // Factory constructor to initialize from preferences
  static Future<ThemeProvider> create() async {
    final themeMode = await PrefsHelper.getSelectedTheme();
    return ThemeProvider(themeMode);
  }

  // Change theme and save to preferences
  Future<void> setThemeMode(String mode) async {
    if (_themeMode != mode) {
      _themeMode = mode;
      await PrefsHelper.saveSelectedTheme(mode);
      notifyListeners();
    }
  }
}
