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
  final List<_ChapterEntry> _chapterEntries = <_ChapterEntry>[];
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
  int get chapterCount => _chapterEntries.length;
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
      _chapterEntries.clear();
      _activeSearchHighlight = null;
      _rebuildChapterEntries();

      // Load position using CFI
      await _loadPositionWithCfi();

      if (_chapterEntries.isEmpty) {
        _currentChapterIndex = 0;
        _scrollPosition = 0.0;
      } else {
        _currentChapterIndex = math.min(
          math.max(_currentChapterIndex, 0),
          _chapterEntries.length - 1,
        );
      }

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

    var resolvedIndex = await _loadPosition();

    if (savedCfi != null && savedCfi.isNotEmpty) {
      _currentCfiPosition = savedCfi;
      final cfiEntryIndex = _findEntryIndexForCfi(savedCfi);

      if (cfiEntryIndex != null) {
        resolvedIndex = cfiEntryIndex;
      } else if (_book != null) {
        final legacyRootIndex = EpubCfiUtil.getChapterIndexFromCfi(
          savedCfi,
          _book!,
        );
        if (legacyRootIndex != null) {
          resolvedIndex =
              _entryIndexForSection(legacyRootIndex, 0) ??
              _entryIndexForRoot(legacyRootIndex) ??
              resolvedIndex;
        }
      }

      final rootIndexForScroll = _entryForIndex(resolvedIndex)?.rootIndex ?? 0;
      final scrollPos = EpubCfiUtil.getScrollPositionFromCfi(
        savedCfi,
        _book!,
        rootIndexForScroll,
      );
      if (scrollPos != null) {
        _scrollPosition = scrollPos.clamp(0.0, 1.0);
      }
    }

    if (_chapterEntries.isEmpty) {
      _currentChapterIndex = 0;
    } else {
      _currentChapterIndex = resolvedIndex
          .clamp(0, _chapterEntries.length - 1)
          .toInt();
    }

    if (storedScroll != null) {
      _scrollPosition = storedScroll.clamp(0.0, 1.0);
    }
  }

  String getChapterHtmlContent(int chapterIndex) {
    final entry = _entryForIndex(chapterIndex);
    if (entry == null) {
      return '';
    }

    final section = _sectionForEntry(entry);
    if (section == null) {
      return '';
    }

    return section.html;
  }

  String getChapterTitle(int chapterIndex) {
    final entry = _entryForIndex(chapterIndex);
    if (entry == null) {
      return 'Chapter ${chapterIndex + 1}';
    }

    final section = _sectionForEntry(entry);
    final title = section?.title?.trim();
    if (title != null && title.isNotEmpty) {
      return title;
    }

    final chapters = _book?.Chapters;
    if (chapters != null &&
        entry.rootIndex >= 0 &&
        entry.rootIndex < chapters.length) {
      final rootTitle = chapters[entry.rootIndex].Title?.trim();
      if (rootTitle != null && rootTitle.isNotEmpty) {
        return rootTitle;
      }
    }

    return 'Chapter ${chapterIndex + 1}';
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

    if (_chapterEntries.isEmpty) {
      return [];
    }

    final lowerQuery = trimmedQuery.toLowerCase();
    final indices = entireBook
        ? List<int>.generate(_chapterEntries.length, (index) => index)
        : <int>[
            _chapterEntries.isEmpty
                ? 0
                : math.min(
                    math.max(_currentChapterIndex, 0),
                    _chapterEntries.length - 1,
                  ),
          ];

    final results = <EpubSearchHit>[];
    final matchesPerRoot = <int, int>{};

    for (final entryIndex in indices) {
      if (results.length >= maxResults) {
        break;
      }

      final entry = _entryForIndex(entryIndex);
      if (entry == null) {
        continue;
      }

      final section = _sectionForEntry(entry);
      if (section == null) {
        continue;
      }

      final rootMatches = matchesPerRoot[entry.rootIndex] ?? 0;
      if (rootMatches >= maxResultsPerChapter) {
        continue;
      }

      final plainText = section.plainText;
      if (plainText.isEmpty) {
        continue;
      }

      final lowerPlain = plainText.toLowerCase();
      var searchStart = 0;

      while ((matchesPerRoot[entry.rootIndex] ?? 0) < maxResultsPerChapter &&
          results.length < maxResults) {
        final matchIndex = lowerPlain.indexOf(lowerQuery, searchStart);
        if (matchIndex == -1) {
          break;
        }

        final snippet = _buildSnippet(plainText, matchIndex, lowerQuery.length);

        final length = plainText.length;
        final ratio = length <= 0 ? 0.0 : (matchIndex / length).clamp(0.0, 1.0);

        results.add(
          EpubSearchHit(
            chapterIndex: entryIndex,
            chapterTitle: getChapterTitle(entryIndex),
            snippet: snippet,
            scrollRatio: ratio.isNaN ? 0.0 : ratio,
            sectionIndex: section.sectionIndex,
          ),
        );

        matchesPerRoot[entry.rootIndex] =
            (matchesPerRoot[entry.rootIndex] ?? 0) + 1;
        searchStart = matchIndex + lowerQuery.length;
      }
    }

    return results;
  }

  Uint8List? resolveImageBytes(int chapterIndex, String? source) {
    if (_book == null || source == null || source.isEmpty) {
      return null;
    }

    final entry = _entryForIndex(chapterIndex);
    if (entry == null) {
      return null;
    }

    final section = _sectionForEntry(entry);
    if (section == null) {
      return null;
    }

    final sanitizedSource = source.trim();
    if (sanitizedSource.startsWith('http') ||
        sanitizedSource.startsWith('https') ||
        sanitizedSource.startsWith('data:')) {
      return null; // Let flutter_html handle external & data URIs.
    }

    final String? basePath;
    if (section.basePath != null && section.basePath!.isNotEmpty) {
      basePath = section.basePath;
    } else {
      final chapters = _book!.Chapters;
      basePath =
          (chapters != null &&
              entry.rootIndex >= 0 &&
              entry.rootIndex < chapters.length)
          ? chapters[entry.rootIndex].ContentFileName
          : null;
    }
    final resolvedPath = _resolveRelativeToChapter(sanitizedSource, basePath);

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
    if (_chapterEntries.isEmpty) {
      return;
    }

    if (index < 0 || index >= _chapterEntries.length) {
      return;
    }

    var targetIndex = index;
    final entry = _entryForIndex(index);
    if (entry == null) {
      return;
    }

    if (sectionIndex != null && sectionIndex != entry.sectionIndex) {
      final alternative = _entryIndexForSection(entry.rootIndex, sectionIndex);
      if (alternative != null) {
        targetIndex = alternative;
      }
    }

    final resolvedEntry = _entryForIndex(targetIndex);
    if (resolvedEntry == null) {
      return;
    }

    _currentChapterIndex = targetIndex;
    final targetScroll = (scrollPosition ?? 0.0).clamp(0.0, 1.0);
    _scrollPosition = targetScroll;
    _pendingSectionIndex = resolvedEntry.sectionIndex;
    _pendingSectionShouldAlignToAnchor =
        alignToSectionAnchor && sectionIndex != null;

    _updateCfiPosition();

    _savePosition(_currentChapterIndex);
    _saveCfiPosition();

    if (pageController.hasClients) {
      final currentPage = pageController.page?.round();
      if (currentPage != targetIndex) {
        pageController.jumpToPage(targetIndex);
      }
    }
    _scrollRequestId += 1;
    notifyListeners();
  }

  void navigateToSection(
    int index, {
    double? scrollPosition,
    int? sectionIndex,
  }) {
    if (_chapterEntries.isEmpty) {
      return;
    }

    if (index < 0 || index >= _chapterEntries.length) {
      return;
    }

    final entry = _entryForIndex(index);
    if (entry == null) {
      return;
    }

    var targetIndex = index;
    if (sectionIndex != null && sectionIndex != entry.sectionIndex) {
      final alternative = _entryIndexForSection(entry.rootIndex, sectionIndex);
      if (alternative != null) {
        targetIndex = alternative;
      }
    }

    final wantsAnchorAlignment = sectionIndex != null && scrollPosition == null;

    if (targetIndex != _currentChapterIndex) {
      goToChapter(
        targetIndex,
        scrollPosition: scrollPosition,
        sectionIndex: sectionIndex,
        alignToSectionAnchor: wantsAnchorAlignment,
      );
      return;
    }

    if (scrollPosition != null) {
      _scrollPosition = scrollPosition.clamp(0.0, 1.0);
      _updateCfiPosition();
      _scheduleScrollSave();
    }

    final resolvedEntry = _entryForIndex(targetIndex);
    _pendingSectionIndex = sectionIndex ?? resolvedEntry?.sectionIndex;
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
    final entry = _entryForIndex(_currentChapterIndex);
    if (_book == null || entry == null) {
      _currentCfiPosition = null;
      return;
    }

    _currentCfiPosition = EpubCfiUtil.generateCfi(
      book: _book,
      chapterIndex: entry.rootIndex,
      scrollPosition: _scrollPosition,
    );
  }

  Future<void> _savePosition(int chapterIndex) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getKeyForFile(filePath);
    final formatKey = _getFormatKeyForFile(filePath);
    await prefs.setInt(key, chapterIndex);
    await prefs.setBool(formatKey, true);
  }

  Future<int> _loadPosition() async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getKeyForFile(filePath);
    final formatKey = _getFormatKeyForFile(filePath);
    final position = prefs.get(key);
    final isFlattened = prefs.getBool(formatKey) ?? false;

    if (position is int) {
      if (!isFlattened && _chapterEntries.isNotEmpty) {
        final converted = _entryIndexForRoot(position) ?? position;
        await prefs.setInt(key, converted);
        await prefs.setBool(formatKey, true);
        return converted;
      }
      return position;
    }
    // If the stored value is not an int (e.g., a String from a previous app version),
    // default to 0. This makes the loading more robust.
    return 0;
  }

  static String _getKeyForFile(String filePath) {
    return 'epub_position_${filePath.hashCode}';
  }

  static String _getFormatKeyForFile(String filePath) {
    return 'epub_position_format_${filePath.hashCode}';
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

  void _rebuildChapterEntries() {
    _chapterEntries.clear();
    if (_book == null) {
      return;
    }

    final chapters = _book!.Chapters ?? [];
    for (var rootIndex = 0; rootIndex < chapters.length; rootIndex++) {
      final sections = _ensureChapterSections(rootIndex);
      for (final section in sections) {
        _chapterEntries.add(
          _ChapterEntry(
            rootIndex: rootIndex,
            sectionIndex: section.sectionIndex,
          ),
        );
      }
    }
  }

  _ChapterEntry? _entryForIndex(int index) {
    if (index < 0 || index >= _chapterEntries.length) {
      return null;
    }
    return _chapterEntries[index];
  }

  _ChapterSection? _sectionForEntry(_ChapterEntry entry) {
    final sections = _ensureChapterSections(entry.rootIndex);
    for (final section in sections) {
      if (section.sectionIndex == entry.sectionIndex) {
        return section;
      }
    }
    return null;
  }

  int? _entryIndexForSection(int rootIndex, int sectionIndex) {
    for (var i = 0; i < _chapterEntries.length; i++) {
      final entry = _chapterEntries[i];
      if (entry.rootIndex == rootIndex && entry.sectionIndex == sectionIndex) {
        return i;
      }
    }
    return null;
  }

  int? _entryIndexForRoot(int rootIndex) {
    for (var i = 0; i < _chapterEntries.length; i++) {
      if (_chapterEntries[i].rootIndex == rootIndex) {
        return i;
      }
    }
    return null;
  }

  int? _findEntryIndexForCfi(String cfi) {
    final idRef = EpubCfiUtil.extractSpineIdRef(cfi);
    if (idRef == null) {
      return null;
    }

    for (var i = 0; i < _chapterEntries.length; i++) {
      final section = _sectionForEntry(_chapterEntries[i]);
      if (section == null) {
        continue;
      }

      if (_matchesIdRef(
        idRef,
        anchor: section.anchor,
        basePath: section.basePath,
      )) {
        return i;
      }
    }

    return null;
  }

  bool _matchesIdRef(String idRef, {String? anchor, String? basePath}) {
    if (anchor != null && anchor.isNotEmpty && anchor == idRef) {
      return true;
    }

    if (basePath != null) {
      final sanitized = basePath.split('/').last;
      if (sanitized.contains(idRef)) {
        return true;
      }
      final withoutExtension = sanitized.replaceFirst(RegExp(r'\.[^.]+$'), '');
      if (withoutExtension == idRef) {
        return true;
      }
    }

    return false;
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
    if (_chapterEntries.isEmpty) {
      return const [];
    }

    final items = <ChapterNavItem>[];
    for (var i = 0; i < _chapterEntries.length; i++) {
      final entry = _chapterEntries[i];
      final section = _sectionForEntry(entry);
      if (section == null) {
        continue;
      }

      final title = section.title?.trim();
      items.add(
        ChapterNavItem(
          title: (title != null && title.isNotEmpty)
              ? title
              : 'Chapter ${i + 1}',
          chapterIndex: i,
          scrollRatio: 0.0,
          depth: section.depth,
          sectionIndex: section.sectionIndex,
        ),
      );
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
    final entry = _entryForIndex(chapterIndex);
    if (entry == null) {
      return const [];
    }

    final section = _sectionForEntry(entry);
    if (section == null) {
      return const [];
    }

    return <ChapterSectionViewModel>[
      ChapterSectionViewModel(
        html: section.html,
        depth: section.depth,
        sectionIndex: section.sectionIndex,
        startRatio: 0.0,
      ),
    ];
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

class _ChapterEntry {
  const _ChapterEntry({required this.rootIndex, required this.sectionIndex});

  final int rootIndex;
  final int sectionIndex;
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
