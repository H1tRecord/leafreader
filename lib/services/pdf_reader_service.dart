import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class PdfReaderService with ChangeNotifier {
  final PdfViewerController pdfViewerController = PdfViewerController();
  final GlobalKey<SfPdfViewerState> pdfViewerKey = GlobalKey();
  final TextEditingController searchController = TextEditingController();

  String? _errorMessage;
  bool _showScrollHead = true;
  bool _showPageNavigation = true;
  PdfPageLayoutMode _pageLayoutMode = PdfPageLayoutMode.continuous;
  PdfTextSearchResult _searchResult = PdfTextSearchResult();
  bool _isSearching = false;
  Timer? _debounce;

  String? get errorMessage => _errorMessage;
  bool get showScrollHead => _showScrollHead;
  bool get showPageNavigation => _showPageNavigation;
  PdfPageLayoutMode get pageLayoutMode => _pageLayoutMode;
  PdfTextSearchResult get searchResult => _searchResult;
  bool get isSearching => _isSearching;

  PdfReaderService() {
    pdfViewerController.addListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    notifyListeners();
  }

  @override
  void dispose() {
    pdfViewerController.removeListener(_onControllerChanged);
    pdfViewerController.dispose();
    searchController.dispose();
    if (_searchResult.hasResult) {
      _searchResult.removeListener(_onSearchResultChanged);
      _searchResult.clear();
    }
    _debounce?.cancel();
    super.dispose();
  }

  void onSearchTextChanged(String text) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    if (text.isEmpty) {
      if (_searchResult.hasResult) {
        _searchResult.removeListener(_onSearchResultChanged);
        _searchResult.clear();
        notifyListeners();
      }
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (text.isNotEmpty) {
        startSearch(text);
      }
    });
  }

  void startSearch(String searchText) {
    if (_searchResult.hasResult) {
      _searchResult.removeListener(_onSearchResultChanged);
      _searchResult.clear();
    }

    _searchResult = pdfViewerController.searchText(searchText);

    _isSearching = true;
    notifyListeners();

    if (kIsWeb) {
      if (!_searchResult.hasResult) {
        // Handle no results found for web
      }
    } else {
      _searchResult.addListener(_onSearchResultChanged);
    }
  }

  void _onSearchResultChanged() {
    if (_searchResult.isSearchCompleted) {
      notifyListeners();
    }
  }

  void toggleSearch() {
    _isSearching = !_isSearching;
    if (!_isSearching && _searchResult.hasResult) {
      _searchResult.removeListener(_onSearchResultChanged);
      _searchResult.clear();
    }
    searchController.clear();
    notifyListeners();
  }

  void clearSearch() {
    searchController.clear();
    if (_searchResult.hasResult) {
      _searchResult.removeListener(_onSearchResultChanged);
      _searchResult.clear();
    }
    notifyListeners();
  }

  void handleMenuSelection(String value) {
    switch (value) {
      case 'zoom_in':
        pdfViewerController.zoomLevel += 0.25;
        break;
      case 'zoom_out':
        if (pdfViewerController.zoomLevel > 0.5) {
          pdfViewerController.zoomLevel -= 0.25;
        }
        break;
      case 'page_nav':
        _showPageNavigation = !_showPageNavigation;
        break;
      case 'scroll_head':
        _showScrollHead = !_showScrollHead;
        break;
    }
    notifyListeners();
  }

  void togglePageLayoutMode() {
    _pageLayoutMode = _pageLayoutMode == PdfPageLayoutMode.continuous
        ? PdfPageLayoutMode.single
        : PdfPageLayoutMode.continuous;
    notifyListeners();
  }
}
