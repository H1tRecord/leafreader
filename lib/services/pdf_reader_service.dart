import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'annotation_storage_service.dart';

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
  String? _filePath;
  List<Annotation>? _loadedAnnotations;
  bool _annotationsModified = false;

  String? get errorMessage => _errorMessage;
  bool get showScrollHead => _showScrollHead;
  bool get showPageNavigation => _showPageNavigation;
  PdfPageLayoutMode get pageLayoutMode => _pageLayoutMode;
  PdfTextSearchResult get searchResult => _searchResult;
  bool get isSearching => _isSearching;
  bool get hasUnsavedAnnotations => _annotationsModified;

  PdfReaderService() {
    pdfViewerController.addListener(_onControllerChanged);
  }

  /// Initialize the service with a PDF file path.
  /// This should be called when the PDF is opened.
  Future<void> initWithFile(String filePath) async {
    _filePath = filePath;
    // Load saved annotations
    await _loadAnnotations();
  }

  void _onControllerChanged() {
    notifyListeners();
  }

  @override
  void dispose() {
    // Save annotations before disposing
    _saveAnnotationsIfNeeded();

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

  /// Load saved annotations from storage.
  Future<void> _loadAnnotations() async {
    if (_filePath == null) return;

    try {
      _loadedAnnotations = await AnnotationStorageService.loadAnnotations(
        _filePath!,
      );

      if (_loadedAnnotations != null && _loadedAnnotations!.isNotEmpty) {
        // We need to add the annotations after the document is loaded
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final state = pdfViewerKey.currentState;
          if (state != null) {
            for (final annotation in _loadedAnnotations!) {
              pdfViewerController.addAnnotation(annotation);
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading annotations: $e');
    }
  }

  /// Save the current annotations to storage if they have been modified.
  Future<void> _saveAnnotationsIfNeeded() async {
    if (_filePath == null || !_annotationsModified) return;

    try {
      final annotations = pdfViewerController.getAnnotations();
      if (annotations.isNotEmpty) {
        await AnnotationStorageService.saveAnnotations(_filePath!, annotations);
        _annotationsModified = false;
      }
    } catch (e) {
      debugPrint('Error saving annotations: $e');
    }
  }

  /// Save annotations immediately, regardless of modification status.
  /// This can be called when explicitly saving or when the app is paused.
  Future<void> saveAnnotations() async {
    if (_filePath == null) return;

    try {
      final annotations = pdfViewerController.getAnnotations();
      await AnnotationStorageService.saveAnnotations(_filePath!, annotations);
      _annotationsModified = false;
    } catch (e) {
      debugPrint('Error saving annotations: $e');
    }
  }

  /// Should be called when annotations are added, modified, or removed.
  void onAnnotationsChanged() {
    _annotationsModified = true;
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
