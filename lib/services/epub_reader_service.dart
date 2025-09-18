import 'dart:io';
import 'package:flutter/material.dart';
import 'package:epubx/epubx.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EpubReaderService with ChangeNotifier {
  final String filePath;
  EpubBook? _book;
  bool _isLoading = true;
  String? _errorMessage;
  int _currentChapterIndex = 0;
  final PageController pageController = PageController();

  EpubBook? get book => _book;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get currentChapterIndex => _currentChapterIndex;

  EpubReaderService(this.filePath) {
    _loadBook();
  }

  Future<void> _loadBook() async {
    try {
      final file = File(filePath);
      final bytes = await file.readAsBytes();
      _book = await EpubReader.readBook(bytes);
      _currentChapterIndex = await _loadPosition();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Error loading EPUB file: $e';
      notifyListeners();
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

  void goToChapter(int index) {
    if (index >= 0 && index < _book!.Chapters!.length) {
      _currentChapterIndex = index;
      _savePosition(index);
      pageController.jumpToPage(index);
      notifyListeners();
    }
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
  }

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
  }
}
