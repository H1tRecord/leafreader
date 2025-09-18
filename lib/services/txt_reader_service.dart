import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../utils/prefs_helper.dart';

enum FontFamily {
  default_(''),
  serif('serif'),
  sansSerif('sans-serif'),
  monospace('monospace');

  final String name;
  const FontFamily(this.name);
}

class TxtReaderService with ChangeNotifier {
  String? _content;
  String? _errorMessage;
  bool _isLoading = true;
  double _fontSize = 16.0;
  String _fontFamily = 'Default';
  final ScrollController scrollController = ScrollController();

  final TextEditingController searchController = TextEditingController();
  bool _isSearching = false;
  List<int> _searchResults = [];
  int _currentSearchIndex = -1;
  Timer? _debounce;

  String? get content => _content;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;
  double get fontSize => _fontSize;
  String get fontFamily => _fontFamily;
  bool get isSearching => _isSearching;
  List<int> get searchResults => _searchResults;
  int get currentSearchIndex => _currentSearchIndex;

  final String filePath;

  TxtReaderService(this.filePath) {
    _loadContent();
    _loadReaderSettings();
    searchController.addListener(
      () => onSearchTextChanged(searchController.text),
    );
  }

  @override
  void dispose() {
    scrollController.dispose();
    searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadContent() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final file = File(filePath);
      _content = await file.readAsString();
    } catch (e) {
      _errorMessage = 'Error loading file: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadReaderSettings() async {
    _fontSize = await PrefsHelper.getTextFontSize();
    _fontFamily = await PrefsHelper.getTextFontFamily();
    notifyListeners();
  }

  void onSearchTextChanged(String text) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    if (text.isEmpty) {
      _searchResults = [];
      _currentSearchIndex = -1;
      notifyListeners();
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _performSearch(text);
    });
  }

  void _performSearch(String query) {
    if (_content == null || query.isEmpty) {
      _searchResults = [];
      _currentSearchIndex = -1;
      notifyListeners();
      return;
    }

    final results = <int>[];
    final contentLower = _content!.toLowerCase();
    final queryLower = query.toLowerCase();

    int index = contentLower.indexOf(queryLower);
    while (index != -1) {
      results.add(index);
      index = contentLower.indexOf(queryLower, index + 1);
    }

    _searchResults = results;
    _currentSearchIndex = results.isEmpty ? -1 : 0;
    notifyListeners();

    if (results.isNotEmpty) {
      _scrollToCurrentResult();
    }
  }

  void _scrollToCurrentResult() {
    if (_currentSearchIndex < 0 || _searchResults.isEmpty) return;

    final index = _searchResults[_currentSearchIndex];
    final textBefore = _content!.substring(0, index);
    final linesBefore = '\n'.allMatches(textBefore).length;
    final estimatedPosition = linesBefore * 20.0;

    scrollController.animateTo(
      estimatedPosition,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
    );
  }

  void nextSearchResult() {
    if (_searchResults.isEmpty) return;
    _currentSearchIndex = (_currentSearchIndex + 1) % _searchResults.length;
    notifyListeners();
    _scrollToCurrentResult();
  }

  void previousSearchResult() {
    if (_searchResults.isEmpty) return;
    _currentSearchIndex =
        (_currentSearchIndex - 1 + _searchResults.length) %
        _searchResults.length;
    notifyListeners();
    _scrollToCurrentResult();
  }

  void toggleSearch() {
    _isSearching = !_isSearching;
    if (!_isSearching) {
      searchController.clear();
      _searchResults = [];
      _currentSearchIndex = -1;
    }
    notifyListeners();
  }

  void clearSearch() {
    searchController.clear();
    _searchResults = [];
    _currentSearchIndex = -1;
    notifyListeners();
  }

  void setFontSize(double size) {
    _fontSize = size;
    PrefsHelper.saveTextFontSize(size);
    notifyListeners();
  }

  void setFontFamily(String family) {
    _fontFamily = family;
    PrefsHelper.saveTextFontFamily(family);
    notifyListeners();
  }
}
