import 'package:shared_preferences/shared_preferences.dart';

class ReaderPositionHelper {
  // Key prefix for storing reading positions
  static const String _keyPrefix = 'epub_position_';

  /// Save the reading position for a specific file
  static Future<bool> savePosition(String filePath, String epubCfi) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _getKeyForFile(filePath);
      return await prefs.setString(key, epubCfi);
    } catch (e) {
      print('Error saving position: $e');
      return false;
    }
  }

  /// Get the saved reading position for a specific file
  static Future<String?> getPosition(String filePath) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _getKeyForFile(filePath);
      return prefs.getString(key);
    } catch (e) {
      print('Error getting position: $e');
      return null;
    }
  }

  /// Generate a unique key for the file path
  static String _getKeyForFile(String filePath) {
    // Use hash to create a consistent and unique key for the file path
    return '$_keyPrefix${filePath.hashCode}';
  }

  /// Clear all saved positions
  static Future<bool> clearAllPositions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      final positionKeys = keys.where((key) => key.startsWith(_keyPrefix));

      for (final key in positionKeys) {
        await prefs.remove(key);
      }

      return true;
    } catch (e) {
      print('Error clearing positions: $e');
      return false;
    }
  }

  /// Remove saved position for a specific file
  static Future<bool> removePosition(String filePath) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _getKeyForFile(filePath);
      return await prefs.remove(key);
    } catch (e) {
      print('Error removing position: $e');
      return false;
    }
  }
}
