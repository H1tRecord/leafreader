import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:epubx/epubx.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/prefs_helper.dart';
import '../utils/epub_cfi_util.dart';

class EpubSearchHit {
  EpubSearchHit({
    required this.chapterIndex,
    required this.chapterTitle,
    required this.snippet,
    required this.scrollRatio,
    this.sectionIndex,
  });

  final int chapterIndex;
  final String chapterTitle;
  final String snippet;
  final double scrollRatio;
  final int? sectionIndex;
}

class EpubReaderService with ChangeNotifier {
  final String filePath;
  EpubBook? _book;
  bool _isLoading = true;
  String? _errorMessage;
  int _currentChapterIndex = 0;
  double _scrollPosition = 0.0;
  String? _currentCfiPosition;
  PageController? _pageController; // Make nullable
  Timer? _scrollSaveDebounce;
  int _scrollRequestId = 0;
  int? _pendingSectionIndex;
  bool _pendingSectionShouldAlignToAnchor = false;
  String? _activeSearchHighlight;
  final Map<int, List<_ChapterSection>> _chapterSectionsCache = {};

  // Font settings
  double? _fontSize;
  String? _fontFamily;
  bool _loadingFontSettings = true;
  static final p.Context _pathContext = p.Context(style: p.Style.posix);

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
  int get scrollRequestId => _scrollRequestId;
  int? get pendingSectionIndex => _pendingSectionIndex;
  bool get pendingSectionShouldAlignToAnchor =>
      _pendingSectionShouldAlignToAnchor;
  String? get activeSearchHighlight => _activeSearchHighlight;

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
      _chapterSectionsCache.clear();
      _activeSearchHighlight = null;

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

    final storedScroll = await PrefsHelper.getEpubScrollPosition(filePath);

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
          _scrollPosition = scrollPos.clamp(0.0, 1.0);
        }
      } else {
        // Fallback to simple chapter position
        _currentChapterIndex = await _loadPosition();
      }
    } else {
      // Fallback to simple chapter position
      _currentChapterIndex = await _loadPosition();
    }

    if (storedScroll != null) {
      _scrollPosition = storedScroll.clamp(0.0, 1.0);
    }
  }

  String getChapterHtmlContent(int chapterIndex) {
    if (_book == null ||
        chapterIndex < 0 ||
        chapterIndex >= _book!.Chapters!.length) {
      return '';
    }

    final sections = _ensureChapterSections(chapterIndex);
    if (sections.isEmpty) {
      return '';
    }

    final buffer = StringBuffer();
    for (final section in sections) {
      buffer.writeln(section.html);
    }

    return buffer.toString();
  }

  String getChapterTitle(int chapterIndex) {
    final chapters = _book?.Chapters;
    if (chapters == null ||
        chapterIndex < 0 ||
        chapterIndex >= chapters.length) {
      return 'Chapter ${chapterIndex + 1}';
    }

    final title = chapters[chapterIndex].Title?.trim();
    if (title == null || title.isEmpty) {
      return 'Chapter ${chapterIndex + 1}';
    }
    return title;
  }

  Future<List<EpubSearchHit>> searchForText(
    String query, {
    required bool entireBook,
    int maxResults = 100,
    int maxResultsPerChapter = 10,
  }) async {
    if (_book == null) {
      return [];
    }

    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      return [];
    }

    final chapters = _book!.Chapters ?? [];
    if (chapters.isEmpty) {
      return [];
    }

    final lowerQuery = trimmedQuery.toLowerCase();
    final indices = entireBook
        ? List<int>.generate(chapters.length, (index) => index)
        : <int>[currentChapterIndex];

    final results = <EpubSearchHit>[];

    for (final chapterIndex in indices) {
      if (chapterIndex < 0 || chapterIndex >= chapters.length) {
        continue;
      }

      final sections = _ensureChapterSections(chapterIndex);
      if (sections.isEmpty) {
        continue;
      }

      final totalLength = sections.fold<int>(
        0,
        (previousValue, section) => previousValue + section.plainText.length,
      );

      if (totalLength == 0) {
        continue;
      }

      var matchesForChapter = 0;
      var accumulated = 0;

      for (final section in sections) {
        if (matchesForChapter >= maxResultsPerChapter ||
            results.length >= maxResults) {
          break;
        }

        final plainText = section.plainText;
        if (plainText.isEmpty) {
          accumulated += plainText.length;
          continue;
        }

        final lowerPlain = plainText.toLowerCase();
        var searchStart = 0;

        while (matchesForChapter < maxResultsPerChapter &&
            results.length < maxResults) {
          final matchIndex = lowerPlain.indexOf(lowerQuery, searchStart);
          if (matchIndex == -1) {
            break;
          }

          final snippet = _buildSnippet(
            plainText,
            matchIndex,
            lowerQuery.length,
          );
          final globalIndex = accumulated + matchIndex;
          final ratio = (globalIndex / totalLength).clamp(0.0, 1.0);

          results.add(
            EpubSearchHit(
              chapterIndex: chapterIndex,
              chapterTitle: getChapterTitle(chapterIndex),
              snippet: snippet,
              scrollRatio: ratio.isNaN ? 0.0 : ratio,
              sectionIndex: section.sectionIndex,
            ),
          );

          matchesForChapter += 1;
          searchStart = matchIndex + lowerQuery.length;
        }

        accumulated += plainText.length;
      }

      if (results.length >= maxResults) {
        break;
      }
    }

    return results;
  }

  Uint8List? resolveImageBytes(int chapterIndex, String? source) {
    if (_book == null || source == null || source.isEmpty) {
      return null;
    }

    final sanitizedSource = source.trim();
    if (sanitizedSource.startsWith('http') ||
        sanitizedSource.startsWith('https') ||
        sanitizedSource.startsWith('data:')) {
      return null; // Let flutter_html handle external & data URIs.
    }

    if (chapterIndex < 0 || chapterIndex >= (_book!.Chapters?.length ?? 0)) {
      return null;
    }

    final chapter = _book!.Chapters![chapterIndex];
    final resolvedPath = _resolveRelativeToChapter(
      sanitizedSource,
      chapter.ContentFileName,
    );

    final imageFile = _lookupImageFile(resolvedPath);
    if (imageFile?.Content == null) {
      return null;
    }

    return Uint8List.fromList(imageFile!.Content!);
  }

  void goToChapter(
    int index, {
    double? scrollPosition,
    int? sectionIndex,
    bool alignToSectionAnchor = false,
  }) {
    if (index >= 0 && index < _book!.Chapters!.length) {
      _currentChapterIndex = index;
      final targetScroll = (scrollPosition ?? 0.0).clamp(0.0, 1.0);
      _scrollPosition = targetScroll;
      _pendingSectionIndex = sectionIndex;
      _pendingSectionShouldAlignToAnchor =
          alignToSectionAnchor && sectionIndex != null;

      // Generate new CFI position
      _updateCfiPosition();

      // Save position both ways (for backward compatibility)
      _savePosition(index);
      _saveCfiPosition();

      // Make sure the controller is initialized before trying to use it
      // The getter will lazily initialize the controller if needed
      if (pageController.hasClients) {
        final currentPage = pageController.page?.round();
        if (currentPage != index) {
          pageController.jumpToPage(index);
        }
      }
      _scrollRequestId += 1;
      notifyListeners();
    }
  }

  void navigateToSection(
    int index, {
    double? scrollPosition,
    int? sectionIndex,
  }) {
    final targetSection = sectionIndex;
    final wantsAnchorAlignment =
        targetSection != null && scrollPosition == null;
    final targetRatio =
        scrollPosition ??
        (targetSection != null
            ? _computeSectionStartRatio(index, targetSection)
            : null);

    if (index != _currentChapterIndex) {
      goToChapter(
        index,
        scrollPosition: targetRatio,
        sectionIndex: targetSection,
        alignToSectionAnchor: wantsAnchorAlignment,
      );
      return;
    }

    if (targetRatio != null) {
      _scrollPosition = targetRatio.clamp(0.0, 1.0);
      _updateCfiPosition();
    }

    _pendingSectionIndex = targetSection;
    _pendingSectionShouldAlignToAnchor = wantsAnchorAlignment;
    _scrollRequestId += 1;
    notifyListeners();
  }

  void updateScrollPosition(double position) {
    final clamped = position.clamp(0.0, 1.0);
    if (clamped >= 0.0 && clamped <= 1.0) {
      _scrollPosition = clamped;
      _pendingSectionIndex = null;
      _pendingSectionShouldAlignToAnchor = false;
      _updateCfiPosition();
      _scheduleScrollSave();
      notifyListeners();
    }
  }

  void markSectionNavigationHandled() {
    _pendingSectionShouldAlignToAnchor = false;
  }

  void setActiveSearchHighlight(String? term) {
    final normalized = term?.trim();
    final nextValue = (normalized == null || normalized.isEmpty)
        ? null
        : normalized;
    if (_activeSearchHighlight == nextValue) {
      return;
    }
    _activeSearchHighlight = nextValue;
    notifyListeners();
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
    _scrollSaveDebounce?.cancel();

    // Save the current chapter index when exiting
    await _savePosition(_currentChapterIndex);

    // Also save the CFI position (more accurate)
    await _saveCfiPosition();

    // Persist the current scroll ratio for reliable restoration
    await PrefsHelper.saveEpubScrollPosition(filePath, _scrollPosition);
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

  Future<void> resetFontSettings() async {
    _fontSize = 16.0;
    _fontFamily = 'Default';
    await PrefsHelper.saveEpubFontSize(_fontSize!);
    await PrefsHelper.saveEpubFontFamily(_fontFamily!);
    notifyListeners();
  }

  @override
  void dispose() {
    _pageController?.dispose();
    _scrollSaveDebounce?.cancel();
    super.dispose();
  }

  void _scheduleScrollSave() {
    _scrollSaveDebounce?.cancel();
    _scrollSaveDebounce = Timer(const Duration(milliseconds: 500), () async {
      await PrefsHelper.saveEpubScrollPosition(filePath, _scrollPosition);
    });
  }

  List<_ChapterSection> _ensureChapterSections(int chapterIndex) {
    if (_book == null) {
      return [];
    }

    if (_chapterSectionsCache.containsKey(chapterIndex)) {
      return _chapterSectionsCache[chapterIndex]!;
    }

    final chapters = _book!.Chapters;
    if (chapters == null ||
        chapterIndex < 0 ||
        chapterIndex >= chapters.length) {
      _chapterSectionsCache[chapterIndex] = [];
      return [];
    }

    final collector = _SectionCollector();
    _populateChapterSections(
      chapter: chapters[chapterIndex],
      chapterIndex: chapterIndex,
      depth: 0,
      collector: collector,
    );

    _chapterSectionsCache[chapterIndex] = collector.sections;
    return collector.sections;
  }

  void _populateChapterSections({
    required EpubChapter chapter,
    required int chapterIndex,
    required int depth,
    required _SectionCollector collector,
  }) {
    final rawHtml = chapter.HtmlContent;
    if (rawHtml != null && rawHtml.trim().isNotEmpty) {
      final sanitized = _stripXmlDeclarations(rawHtml);
      final withStyles = _inlineChapterStyles(
        sanitized,
        chapter.ContentFileName,
      );
      final rendered = _inlineChapterImages(
        withStyles,
        chapter.ContentFileName,
      );
      final plainText = _plainTextFromHtml(rendered);

      if (rendered.trim().isNotEmpty || plainText.isNotEmpty) {
        collector.add(
          _ChapterSection(
            chapterIndex: chapterIndex,
            sectionIndex: collector.nextIndex(),
            html: rendered,
            basePath: chapter.ContentFileName,
            title: _deriveSectionTitle(
              chapter: chapter,
              chapterIndex: chapterIndex,
              depth: depth,
              sectionNumber: collector.sections.length + 1,
            ),
            depth: depth,
            anchor: chapter.Anchor,
            plainText: plainText,
          ),
        );
      }
    }

    final subChapters = chapter.SubChapters;
    if (subChapters != null && subChapters.isNotEmpty) {
      for (final subChapter in subChapters) {
        _populateChapterSections(
          chapter: subChapter,
          chapterIndex: chapterIndex,
          depth: depth + 1,
          collector: collector,
        );
      }
    }
  }

  String? _deriveSectionTitle({
    required EpubChapter chapter,
    required int chapterIndex,
    required int depth,
    required int sectionNumber,
  }) {
    final trimmed = chapter.Title?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      return trimmed;
    }

    if (depth == 0) {
      return getChapterTitle(chapterIndex);
    }

    return 'Section $sectionNumber';
  }

  List<ChapterNavItem> getNavigationItems() {
    final chapters = _book?.Chapters;
    if (chapters == null || chapters.isEmpty) {
      return [];
    }

    final items = <ChapterNavItem>[];

    for (var i = 0; i < chapters.length; i++) {
      final sections = _ensureChapterSections(i);
      if (sections.isEmpty) {
        continue;
      }

      final totalLength = sections.fold<int>(
        0,
        (previousValue, section) => previousValue + section.plainText.length,
      );

      var accumulated = 0;
      for (final section in sections) {
        final length = section.plainText.length;
        final ratio = totalLength == 0
            ? 0.0
            : (accumulated / totalLength).clamp(0.0, 1.0);

        final depth = section.depth;
        final title =
            section.title ??
            (depth == 0
                ? getChapterTitle(i)
                : 'Section ${section.sectionIndex + 1}');

        if (title.isNotEmpty) {
          items.add(
            ChapterNavItem(
              title: title,
              chapterIndex: i,
              scrollRatio: depth == 0 ? 0.0 : ratio,
              depth: depth,
              sectionIndex: section.sectionIndex,
            ),
          );
        }

        accumulated += length;
      }
    }

    return items;
  }

  String _stripXmlDeclarations(String html) {
    var content = html.trim();
    content = content.replaceFirst(
      RegExp(r'^\s*<\?xml[^>]*>\s*', multiLine: true),
      '',
    );
    content = content.replaceFirst(
      RegExp(r'^\s*<!DOCTYPE[^>]*>\s*', multiLine: true),
      '',
    );
    return content;
  }

  List<ChapterSectionViewModel> getRenderedSections(int chapterIndex) {
    final sections = _ensureChapterSections(chapterIndex);
    if (sections.isEmpty) {
      return const [];
    }

    final totalLength = sections.fold<int>(
      0,
      (previousValue, section) => previousValue + section.plainText.length,
    );

    var accumulated = 0;
    final viewModels = <ChapterSectionViewModel>[];
    for (final section in sections) {
      final ratio = totalLength == 0
          ? 0.0
          : (accumulated / totalLength).clamp(0.0, 1.0);
      viewModels.add(
        ChapterSectionViewModel(
          html: section.html,
          depth: section.depth,
          sectionIndex: section.sectionIndex,
          startRatio: ratio,
        ),
      );
      accumulated += section.plainText.length;
    }

    return viewModels;
  }

  double? _computeSectionStartRatio(int chapterIndex, int sectionIndex) {
    final sections = _ensureChapterSections(chapterIndex);
    if (sections.isEmpty) {
      return null;
    }

    final totalLength = sections.fold<int>(
      0,
      (previousValue, section) => previousValue + section.plainText.length,
    );

    if (totalLength == 0) {
      return 0.0;
    }

    var accumulated = 0;
    for (final section in sections) {
      if (section.sectionIndex == sectionIndex) {
        return (accumulated / totalLength).clamp(0.0, 1.0);
      }
      accumulated += section.plainText.length;
    }

    return null;
  }

  String _inlineChapterStyles(String html, String? chapterPath) {
    final cssFiles = _book?.Content?.Css;
    if (cssFiles == null || cssFiles.isEmpty) {
      return html;
    }

    final linkRegex = RegExp(
      r'<link[^>]*rel\s*=\s*"?stylesheet"?[^>]*>',
      caseSensitive: false,
    );

    return html.replaceAllMapped(linkRegex, (match) {
      final linkTag = match.group(0) ?? '';
      final hrefMatch = RegExp(
        "href\\s*=\\s*\"([^\"]+)\"|href\\s*=\\s*'([^']+)'",
        caseSensitive: false,
      ).firstMatch(linkTag);

      final href = hrefMatch?.group(1) ?? hrefMatch?.group(2);
      if (href == null || href.isEmpty) {
        return linkTag; // Leave untouched if we can't parse it.
      }

      final resolved = _resolveRelativeToChapter(href, chapterPath);
      final cssFile = _lookupCssFile(resolved);
      if (cssFile?.Content == null) {
        return linkTag;
      }

      return '<style>${cssFile!.Content}</style>';
    });
  }

  String _inlineChapterImages(String html, String? chapterPath) {
    if (_book?.Content?.Images == null || _book!.Content!.Images!.isEmpty) {
      return html;
    }

    final imgRegex = RegExp(
      "<img[^>]*src\\s*=\\s*\"([^\"]+)\"[^>]*>|<img[^>]*src\\s*=\\s*'([^']+)'[^>]*>",
      caseSensitive: false,
    );

    return html.replaceAllMapped(imgRegex, (match) {
      final tag = match.group(0) ?? '';
      final src = match.group(1) ?? match.group(2);
      if (src == null ||
          src.isEmpty ||
          src.startsWith('data:') ||
          src.startsWith('http') ||
          src.startsWith('https') ||
          src.startsWith('about:')) {
        return tag;
      }

      final resolved = _resolveRelativeToChapter(src, chapterPath);
      final imageFile = _lookupImageFile(resolved);
      if (imageFile?.Content == null || imageFile!.Content!.isEmpty) {
        return tag;
      }

      final mime = imageFile.ContentMimeType ?? 'image/*';
      final base64Data = base64Encode(imageFile.Content!);
      final dataUri = 'src="data:$mime;base64,$base64Data"';

      return tag.replaceFirst(
        RegExp("src\\s*=\\s*\"[^\"]+\"|src\\s*=\\s*'[^']+'"),
        dataUri,
      );
    });
  }

  EpubByteContentFile? _lookupImageFile(String normalizedPath) {
    final images = _book?.Content?.Images;
    if (images == null || images.isEmpty) {
      return null;
    }

    final target = _normalizeContentPath(normalizedPath);

    if (images.containsKey(target)) {
      return images[target];
    }

    for (final entry in images.entries) {
      final file = entry.value;
      final candidates = <String?>[entry.key, file.FileName];
      if (candidates.any(
        (candidate) =>
            candidate != null && _normalizeContentPath(candidate) == target,
      )) {
        return file;
      }
    }

    return null;
  }

  EpubTextContentFile? _lookupCssFile(String normalizedPath) {
    final cssFiles = _book?.Content?.Css;
    if (cssFiles == null || cssFiles.isEmpty) {
      return null;
    }

    final target = _normalizeContentPath(normalizedPath);

    if (cssFiles.containsKey(target)) {
      return cssFiles[target];
    }

    for (final entry in cssFiles.entries) {
      final file = entry.value;
      final candidates = <String?>[entry.key, file.FileName];
      if (candidates.any(
        (candidate) =>
            candidate != null && _normalizeContentPath(candidate) == target,
      )) {
        return file;
      }
    }

    return null;
  }

  String _resolveRelativeToChapter(String target, String? chapterPath) {
    final sanitized = target.split('#').first.replaceAll('\\', '/');
    if (sanitized.startsWith('http') ||
        sanitized.startsWith('https') ||
        sanitized.startsWith('data:') ||
        sanitized.startsWith('about:')) {
      return sanitized;
    }

    final baseDir = (chapterPath != null && chapterPath.isNotEmpty)
        ? _pathContext.dirname(chapterPath)
        : '';

    final joined = baseDir.isEmpty
        ? sanitized
        : _pathContext.normalize(_pathContext.join(baseDir, sanitized));

    return _normalizeContentPath(joined);
  }

  String _normalizeContentPath(String path) {
    return _pathContext.normalize(path).replaceAll('\\', '/');
  }

  String _plainTextFromHtml(String htmlContent) {
    if (htmlContent.isEmpty) {
      return '';
    }

    var sanitized = htmlContent
        .replaceAll(RegExp(r'<script[^>]*>.*?</script>', dotAll: true), ' ')
        .replaceAll(RegExp(r'<style[^>]*>.*?</style>', dotAll: true), ' ')
        .replaceAll(RegExp(r'<!--.*?-->', dotAll: true), ' ');

    sanitized = sanitized.replaceAll(RegExp(r'<[^>]+>'), ' ');

    sanitized = sanitized
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");

    sanitized = sanitized.replaceAll(RegExp(r'\s+'), ' ').trim();
    return sanitized;
  }

  String _buildSnippet(String text, int matchIndex, int matchLength) {
    const snippetRadius = 60;
    final start = math.max(0, matchIndex - snippetRadius);
    final end = math.min(text.length, matchIndex + matchLength + snippetRadius);

    var snippet = text.substring(start, end).trim();
    if (start > 0) {
      snippet = '…$snippet';
    }
    if (end < text.length) {
      snippet = '$snippet…';
    }
    return snippet;
  }
}

class _SectionCollector {
  final List<_ChapterSection> sections = <_ChapterSection>[];
  int _nextIndex = 0;

  int nextIndex() => _nextIndex++;

  void add(_ChapterSection section) {
    sections.add(section);
  }
}

class _ChapterSection {
  const _ChapterSection({
    required this.chapterIndex,
    required this.sectionIndex,
    required this.html,
    required this.basePath,
    required this.title,
    required this.depth,
    required this.anchor,
    required this.plainText,
  });

  final int chapterIndex;
  final int sectionIndex;
  final String html;
  final String? basePath;
  final String? title;
  final int depth;
  final String? anchor;
  final String plainText;
}

class ChapterSectionViewModel {
  const ChapterSectionViewModel({
    required this.html,
    required this.depth,
    required this.sectionIndex,
    required this.startRatio,
  });

  final String html;
  final int depth;
  final int sectionIndex;
  final double startRatio;
}

class ChapterNavItem {
  const ChapterNavItem({
    required this.title,
    required this.chapterIndex,
    required this.scrollRatio,
    required this.depth,
    required this.sectionIndex,
  });

  final String title;
  final int chapterIndex;
  final double scrollRatio;
  final int depth;
  final int sectionIndex;
}
