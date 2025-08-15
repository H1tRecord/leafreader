import 'package:flutter/material.dart';
import 'prefs_helper.dart';

class ThemeProvider extends ChangeNotifier {
  String _themeMode; // System, Light, Dark
  String _accentColor; // Green, Blue, Purple, Orange, Red

  ThemeProvider(this._themeMode, this._accentColor);

  // Get the string representation of theme mode
  String get themeModeString => _themeMode;

  // Get accent color name
  String get accentColorString => _accentColor;

  // Get the actual accent color
  Color get accentColor {
    switch (_accentColor) {
      case 'Blue':
        return Colors.blue;
      case 'Purple':
        return Colors.purple;
      case 'Orange':
        return Colors.orange;
      case 'Red':
        return Colors.red;
      default:
        return Colors.green; // Default accent color
    }
  }

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
    final accentColor = await PrefsHelper.getAccentColor();
    return ThemeProvider(themeMode, accentColor);
  }

  // Change theme mode and save to preferences
  Future<void> setThemeMode(String mode) async {
    if (_themeMode != mode) {
      _themeMode = mode;
      await PrefsHelper.saveSelectedTheme(mode);
      notifyListeners();
    }
  }

  // Change accent color and save to preferences
  Future<void> setAccentColor(String color) async {
    if (_accentColor != color) {
      _accentColor = color;
      await PrefsHelper.saveAccentColor(color);
      notifyListeners();
    }
  }
}
