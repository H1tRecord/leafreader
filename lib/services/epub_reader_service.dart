import 'dart:io';
import 'package:flutter/material.dart';
import 'package:epub_view/epub_view.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/prefs_helper.dart';

class EpubReaderService with ChangeNotifier {
  late EpubController epubController;
  bool isLoading = true;
  String? errorMessage;

  // Reader settings
  double fontSize = 16.0;
  String fontFamily = 'Default';

  // EPUB version information
  String epubVersion = 'Unknown';
  Map<String, String> epubMetadata = {};

  final String filePath;

  EpubReaderService(this.filePath) {
    _loadEpub();
    _loadReaderSettings();
  }

  Future<void> _loadEpub() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _getKeyForFile(filePath);
      final savedPosition = prefs.getString(key);

      epubController = EpubController(
        document: EpubDocument.openFile(File(filePath)),
        epubCfi: savedPosition,
      );

      isLoading = false;
      notifyListeners();
    } catch (e) {
      isLoading = false;
      errorMessage = 'Error loading EPUB file: $e';
      notifyListeners();
    }
  }

  Future<void> _loadReaderSettings() async {
    fontSize = await PrefsHelper.getEpubFontSize();
    fontFamily = await PrefsHelper.getEpubFontFamily();
    notifyListeners();
  }

  static String _getKeyForFile(String filePath) {
    return 'epub_position_${filePath.hashCode}';
  }

  Future<void> savePosition() async {
    if (!isLoading && errorMessage == null) {
      final cfi = epubController.generateEpubCfi();
      if (cfi != null) {
        try {
          final prefs = await SharedPreferences.getInstance();
          final key = _getKeyForFile(filePath);
          await prefs.setString(key, cfi);
        } catch (e) {
          // Ignore errors when closing
        }
      }
    }
  }

  void onChapterChanged() {
    notifyListeners();
  }

  void onDocumentLoaded(EpubBook document) {
    _detectEpubVersion(document);
  }

  void onDocumentError(Exception? error) {
    errorMessage = 'Error loading document: $error';
    notifyListeners();
  }

  void _detectEpubVersion(EpubBook document) {
    try {
      final package = document.Schema?.Package;
      if (package != null) {
        final version = package.Version?.toString() ?? 'Unknown';
        final isEpub3 = _isEpub3Version(version);
        if (!isEpub3) {
          errorMessage =
              'This app only supports EPUB3 files. Detected EPUB version: $version';
          notifyListeners();
          return;
        }

        epubVersion = version;
        epubMetadata = {
          'Title': document.Title ?? 'Unknown',
          'Author': document.Author ?? 'Unknown',
          'Version': version,
        };

        final metadata = package.Metadata;
        if (metadata?.Languages?.isNotEmpty == true) {
          epubMetadata['Language'] = metadata!.Languages!.first;
        }

        String? publisher;
        metadata?.Contributors?.forEach((contributor) {
          if (contributor.Role?.toLowerCase() == 'publisher') {
            publisher = contributor.Contributor;
          }
        });
        if (publisher != null) {
          epubMetadata['Publisher'] = publisher!;
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error detecting EPUB version: $e');
    }
  }

  bool _isEpub3Version(String version) {
    if (version == 'Unknown') return false;
    if (version.contains('3')) {
      return true;
    }
    final numberRegex = RegExp(r'\d+');
    final matches = numberRegex.allMatches(version);
    for (final match in matches) {
      if (match.group(0) == '3') {
        return true;
      }
    }
    return false;
  }

  void updateFontSize(double newSize) {
    fontSize = newSize;
    notifyListeners();
    PrefsHelper.saveEpubFontSize(newSize);
  }

  void updateFontFamily(String newFamily) {
    fontFamily = newFamily;
    notifyListeners();
    PrefsHelper.saveEpubFontFamily(newFamily);
  }

  @override
  void dispose() {
    if (!isLoading) {
      epubController.dispose();
    }
    super.dispose();
  }
}
