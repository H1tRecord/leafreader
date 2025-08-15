import 'package:flutter/material.dart';
import 'prefs_helper.dart';

class ThemeProvider extends ChangeNotifier {
  String _themeMode;

  ThemeProvider(this._themeMode);

  String get themeMode => _themeMode;

  ThemeMode get themeMode2 {
    switch (_themeMode) {
      case 'Dark':
        return ThemeMode.dark;
      case 'Light':
        return ThemeMode.light;
      default:
        return ThemeMode.system;
    }
  }

  static Future<ThemeProvider> create() async {
    final themeMode = await PrefsHelper.getSelectedTheme();
    return ThemeProvider(themeMode);
  }

  void setThemeMode(String mode) async {
    _themeMode = mode;
    await PrefsHelper.saveSelectedTheme(mode);
    notifyListeners();
  }
}
