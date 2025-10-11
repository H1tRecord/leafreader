import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
// Access text markup rectangles for duplicate detection.
import 'package:syncfusion_flutter_pdfviewer/src/annotation/text_markup.dart'
    show
        HighlightAnnotationExtension,
        UnderlineAnnotationExtension,
        StrikethroughAnnotationExtension,
        SquigglyAnnotationExtension;

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
  bool _isRestoringAnnotations = false;
  bool _isProcessingToggle = false;
  Timer? _autoSaveTimer;

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
    _autoSaveTimer?.cancel();
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
    } catch (e) {
      debugPrint('Error loading annotations: $e');
    }
  }

  /// Save the current annotations to storage if they have been modified.
  Future<void> _saveAnnotationsIfNeeded() async {
    if (_filePath == null || !_annotationsModified) return;

    await _saveAnnotationsInternal();
  }

  /// Save annotations immediately, regardless of modification status.
  /// This can be called when explicitly saving or when the app is paused.
  Future<void> saveAnnotations() async {
    if (_filePath == null) return;

    _autoSaveTimer?.cancel();
    await _saveAnnotationsInternal();
  }

  /// Applies stored annotations once the document is available.
  void handleDocumentLoaded() {
    if (_loadedAnnotations == null || _loadedAnnotations!.isEmpty) {
      return;
    }

    _isRestoringAnnotations = true;
    try {
      for (final annotation in _loadedAnnotations!) {
        pdfViewerController.addAnnotation(annotation);
      }
    } finally {
      _isRestoringAnnotations = false;
      _loadedAnnotations = null;
      _annotationsModified = false;
    }
  }

  /// Reacts to newly added annotations.
  void handleAnnotationAdded(Annotation annotation) {
    if (_isRestoringAnnotations) {
      return;
    }

    final List<Annotation> duplicates = _findDuplicateAnnotations(annotation);
    if (duplicates.isNotEmpty) {
      _isProcessingToggle = true;
      try {
        for (final duplicate in duplicates) {
          pdfViewerController.removeAnnotation(duplicate);
        }
        pdfViewerController.removeAnnotation(annotation);
      } finally {
        _isProcessingToggle = false;
      }
      _markAnnotationsDirty();
      _scheduleAutoSave();
      return;
    }

    _markAnnotationsDirty();
    _scheduleAutoSave();
  }

  /// Reacts to annotation removals.
  void handleAnnotationRemoved(Annotation annotation) {
    if (_isRestoringAnnotations) {
      return;
    }
    if (_isProcessingToggle) {
      return;
    }

    _markAnnotationsDirty();
    _scheduleAutoSave();
  }

  /// Ensures any pending changes are saved immediately.
  Future<void> flushPendingChanges() async {
    _autoSaveTimer?.cancel();
    await _saveAnnotationsIfNeeded();
  }

  Future<void> _saveAnnotationsInternal() async {
    if (_filePath == null) {
      return;
    }

    try {
      final List<Annotation> annotations = pdfViewerController.getAnnotations();
      await AnnotationStorageService.saveAnnotations(_filePath!, annotations);
      _annotationsModified = false;
    } catch (e) {
      debugPrint('Error saving annotations: $e');
    }
  }

  void _markAnnotationsDirty() {
    _annotationsModified = true;
  }

  void _scheduleAutoSave() {
    if (_filePath == null) {
      return;
    }

    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 2), () {
      _saveAnnotationsIfNeeded();
    });
  }

  List<Annotation> _findDuplicateAnnotations(Annotation candidate) {
    if (candidate is! HighlightAnnotation &&
        candidate is! UnderlineAnnotation &&
        candidate is! StrikethroughAnnotation &&
        candidate is! SquigglyAnnotation) {
      return const [];
    }

    final List<Rect> candidateRects = _extractAnnotationRects(candidate);
    final List<Annotation> duplicates = [];
    for (final Annotation annotation in pdfViewerController.getAnnotations()) {
      if (identical(annotation, candidate)) {
        continue;
      }
      if (annotation.runtimeType != candidate.runtimeType) {
        continue;
      }
      if (annotation.pageNumber != candidate.pageNumber) {
        continue;
      }

      final List<Rect> annotationRects = _extractAnnotationRects(annotation);
      if (annotationRects.length != candidateRects.length) {
        continue;
      }

      bool allMatch = true;
      for (int i = 0; i < annotationRects.length; i++) {
        if (!_rectsAlmostEqual(annotationRects[i], candidateRects[i])) {
          allMatch = false;
          break;
        }
      }

      if (allMatch) {
        duplicates.add(annotation);
      }
    }

    return duplicates;
  }

  List<Rect> _extractAnnotationRects(Annotation annotation) {
    if (annotation is HighlightAnnotation) {
      return annotation.textMarkupRects;
    }
    if (annotation is UnderlineAnnotation) {
      return annotation.textMarkupRects;
    }
    if (annotation is StrikethroughAnnotation) {
      return annotation.textMarkupRects;
    }
    if (annotation is SquigglyAnnotation) {
      return annotation.textMarkupRects;
    }
    return const <Rect>[Rect.zero];
  }

  bool _rectsAlmostEqual(Rect a, Rect b) {
    const double tolerance = 0.5;
    return (a.left - b.left).abs() <= tolerance &&
        (a.top - b.top).abs() <= tolerance &&
        (a.right - b.right).abs() <= tolerance &&
        (a.bottom - b.bottom).abs() <= tolerance;
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
