import 'dart:io';
import 'package:flutter/material.dart';
import 'package:epubx/epubx.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/prefs_helper.dart';
import '../utils/epub_cfi_util.dart';

class EpubReaderService with ChangeNotifier {
  final String filePath;
  EpubBook? _book;
  bool _isLoading = true;
  String? _errorMessage;
  int _currentChapterIndex = 0;
  double _scrollPosition = 0.0;
  String? _currentCfiPosition;
  PageController? _pageController; // Make nullable

  // Font settings
  double? _fontSize;
  String? _fontFamily;
  bool _loadingFontSettings = true;

  // Getter with lazy initialization for the PageController
  PageController get pageController {
    _pageController ??= PageController(initialPage: _currentChapterIndex);
    return _pageController!;
  }

  EpubBook? get book => _book;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get currentChapterIndex => _currentChapterIndex;
  double get scrollPosition => _scrollPosition;
  String? get currentCfiPosition => _currentCfiPosition;

  // Font settings getters
  double get fontSize => _fontSize ?? 16.0;
  String get fontFamily => _fontFamily ?? 'Default';
  bool get loadingFontSettings => _loadingFontSettings;

  EpubReaderService(this.filePath) {
    // We'll initialize the PageController after we know the chapter index
    _loadBook();
    _loadFontSettings();
  }

  Future<void> _loadBook() async {
    try {
      final file = File(filePath);
      final bytes = await file.readAsBytes();
      _book = await EpubReader.readBook(bytes);

      // Load position using CFI
      await _loadPositionWithCfi();

      // Now that we know the chapter index, initialize the page controller
      // to start at the correct page
      _pageController = PageController(initialPage: _currentChapterIndex);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Error loading EPUB file: $e';
      notifyListeners();
    }
  }

  Future<void> _loadPositionWithCfi() async {
    // Try to get the saved CFI position
    final savedCfi = await PrefsHelper.getEpubCfiPosition(filePath);

    if (savedCfi != null && savedCfi.isNotEmpty) {
      // Store the CFI string
      _currentCfiPosition = savedCfi;

      // Extract chapter index from CFI
      final chapterIndex = EpubCfiUtil.getChapterIndexFromCfi(savedCfi, _book!);

      if (chapterIndex != null) {
        _currentChapterIndex = chapterIndex;

        // Extract scroll position from CFI
        final scrollPos = EpubCfiUtil.getScrollPositionFromCfi(
          savedCfi,
          _book!,
          chapterIndex,
        );
        if (scrollPos != null) {
          _scrollPosition = scrollPos;
        }
      } else {
        // Fallback to simple chapter position
        _currentChapterIndex = await _loadPosition();
      }
    } else {
      // Fallback to simple chapter position
      _currentChapterIndex = await _loadPosition();
    }
  }

  String getChapterHtmlContent(int chapterIndex) {
    if (_book == null ||
        chapterIndex < 0 ||
        chapterIndex >= _book!.Chapters!.length) {
      return '';
    }
    return _book!.Chapters![chapterIndex].HtmlContent ?? '';
  }

  void goToChapter(int index, {double scrollPosition = 0.0}) {
    if (index >= 0 && index < _book!.Chapters!.length) {
      _currentChapterIndex = index;
      _scrollPosition = scrollPosition;

      // Generate new CFI position
      _updateCfiPosition();

      // Save position both ways (for backward compatibility)
      _savePosition(index);
      _saveCfiPosition();

      // Make sure the controller is initialized before trying to use it
      // The getter will lazily initialize the controller if needed
      if (pageController.hasClients) {
        pageController.jumpToPage(index);
      }
      notifyListeners();
    }
  }

  void updateScrollPosition(double position) {
    if (position >= 0.0 && position <= 1.0) {
      _scrollPosition = position;
      _updateCfiPosition();
      notifyListeners();
    }
  }

  void _updateCfiPosition() {
    _currentCfiPosition = EpubCfiUtil.generateCfi(
      book: _book,
      chapterIndex: _currentChapterIndex,
      scrollPosition: _scrollPosition,
    );
  }

  Future<void> _savePosition(int chapterIndex) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getKeyForFile(filePath);
    await prefs.setInt(key, chapterIndex);
  }

  Future<int> _loadPosition() async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getKeyForFile(filePath);
    final position = prefs.get(key);

    if (position is int) {
      return position;
    }
    // If the stored value is not an int (e.g., a String from a previous app version),
    // default to 0. This makes the loading more robust.
    return 0;
  }

  static String _getKeyForFile(String filePath) {
    return 'epub_position_${filePath.hashCode}';
  }

  Future<void> savePositionOnExit() async {
    // Save the current chapter index when exiting
    await _savePosition(_currentChapterIndex);

    // Also save the CFI position (more accurate)
    await _saveCfiPosition();
  }

  Future<void> _saveCfiPosition() async {
    if (_currentCfiPosition != null && _currentCfiPosition!.isNotEmpty) {
      await PrefsHelper.saveEpubCfiPosition(filePath, _currentCfiPosition!);
    }
  }

  // Font settings methods
  Future<void> _loadFontSettings() async {
    try {
      _fontSize = await PrefsHelper.getEpubFontSize();
      _fontFamily = await PrefsHelper.getEpubFontFamily();
      _loadingFontSettings = false;
      notifyListeners();
    } catch (e) {
      _fontSize = 16.0;
      _fontFamily = 'Default';
      _loadingFontSettings = false;
      notifyListeners();
    }
  }

  Future<void> updateFontSize(double size) async {
    _fontSize = size;
    await PrefsHelper.saveEpubFontSize(size);
    notifyListeners();
  }

  Future<void> updateFontFamily(String family) async {
    _fontFamily = family;
    await PrefsHelper.saveEpubFontFamily(family);
    notifyListeners();
  }

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }
}
