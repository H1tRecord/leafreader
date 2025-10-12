import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import '../services/epub_reader_service.dart';

PreferredSizeWidget buildAppBar(
  BuildContext context,
  EpubReaderService service,
  String fileName,
) {
  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;

  return AppBar(
    backgroundColor: colorScheme.surface,
    foregroundColor: colorScheme.onSurface,
    elevation: 0,
    centerTitle: false,
    toolbarHeight: 72,
    titleSpacing: 0,
    leadingWidth: 56,
    leading: IconButton(
      icon: const Icon(Icons.arrow_back),
      tooltip: 'Back',
      onPressed: () => Navigator.of(context).maybePop(),
    ),
    title: Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            fileName,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            'EPUB Reader',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    ),
    actions: [
      IconButton(
        icon: const Icon(Icons.settings),
        tooltip: 'Reader Settings',
        onPressed: () => showFontSettingsDialog(context, service),
      ),
      IconButton(
        icon: const Icon(Icons.search),
        tooltip: 'Search',
        onPressed: () => showSearchDialog(context, service),
      ),
      IconButton(
        icon: const Icon(Icons.menu_book),
        tooltip: 'Chapter List',
        onPressed: () => showChaptersDialog(context, service),
      ),
      const SizedBox(width: 4),
    ],
    bottom: PreferredSize(
      preferredSize: const Size.fromHeight(1),
      child: Divider(
        height: 1,
        thickness: 1,
        color: colorScheme.outlineVariant,
      ),
    ),
  );
}

Widget buildBody(BuildContext context, EpubReaderService service) {
  if (service.isLoading) {
    return const Center(child: CircularProgressIndicator());
  }

  if (service.errorMessage != null) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(service.errorMessage!),
      ),
    );
  }

  return PageView.builder(
    controller: service.pageController,
    itemCount: service.chapterCount,
    itemBuilder: (context, index) {
      return _EpubChapterView(service: service, chapterIndex: index);
    },
    onPageChanged: (index) {
      service.goToChapter(index);
    },
  );
}

enum _EpubSearchScope { chapter, book }

Future<void> showSearchDialog(
  BuildContext context,
  EpubReaderService service,
) async {
  final queryController = TextEditingController();

  _EpubSearchScope scope = _EpubSearchScope.chapter;
  List<EpubSearchHit> hits = [];
  bool isSearching = false;
  String? statusMessage = 'Enter a search term to begin.';
  String activeQuery = '';

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (modalContext) {
      return StatefulBuilder(
        builder: (modalContext, setModalState) {
          Future<void> handleSearch() async {
            final query = queryController.text.trim();
            if (query.isEmpty) {
              service.setActiveSearchHighlight(null);
              setModalState(() {
                isSearching = false;
                hits = [];
                statusMessage = 'Enter a search term to begin.';
                activeQuery = '';
              });
              return;
            }

            setModalState(() {
              isSearching = true;
              hits = [];
              statusMessage = null;
              activeQuery = query;
            });
            service.setActiveSearchHighlight(query);

            try {
              final results = await service.searchForText(
                query,
                entireBook: scope == _EpubSearchScope.book,
              );
              if (!modalContext.mounted) {
                return;
              }
              setModalState(() {
                isSearching = false;
                hits = results;
                statusMessage = results.isEmpty ? 'No matches found.' : null;
              });
            } catch (_) {
              if (!modalContext.mounted) {
                return;
              }
              setModalState(() {
                isSearching = false;
                hits = [];
                statusMessage = 'Unable to complete search.';
              });
            }
          }

          Widget buildResults() {
            if (isSearching) {
              return const Center(child: CircularProgressIndicator());
            }

            if (hits.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    statusMessage ?? 'No results yet.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            return ListView.separated(
              itemCount: hits.length,
              separatorBuilder: (context, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final hit = hits[index];
                final percent = (hit.scrollRatio * 100)
                    .clamp(0, 100)
                    .toStringAsFixed(0);
                return ListTile(
                  onTap: () {
                    FocusScope.of(modalContext).unfocus();
                    service.setActiveSearchHighlight(activeQuery);
                    Navigator.of(modalContext).pop();
                    service.navigateToSection(
                      hit.chapterIndex,
                      scrollPosition: hit.scrollRatio,
                      sectionIndex: hit.sectionIndex,
                    );
                  },
                  title: Text(hit.chapterTitle),
                  subtitle: _buildHighlightedSnippet(
                    modalContext,
                    hit.snippet,
                    activeQuery,
                  ),
                  trailing: Text('$percent%'),
                );
              },
            );
          }

          return SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(modalContext).viewInsets.bottom,
              ),
              child: SizedBox(
                height: MediaQuery.of(modalContext).size.height * 0.75,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Search EPUB',
                              style: Theme.of(
                                modalContext,
                              ).textTheme.titleLarge,
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(modalContext).pop(),
                            icon: const Icon(Icons.close),
                            tooltip: 'Close',
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: queryController,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => handleSearch(),
                        onChanged: (value) {
                          if (value.trim().isEmpty) {
                            service.setActiveSearchHighlight(null);
                          }
                        },
                        decoration: const InputDecoration(
                          labelText: 'Search query',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Wrap(
                        spacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('Current chapter'),
                            selected: scope == _EpubSearchScope.chapter,
                            onSelected: (selected) {
                              if (selected &&
                                  scope != _EpubSearchScope.chapter) {
                                setModalState(() {
                                  scope = _EpubSearchScope.chapter;
                                });
                                if (activeQuery.isNotEmpty) {
                                  handleSearch();
                                }
                              }
                            },
                          ),
                          ChoiceChip(
                            label: const Text('Entire book'),
                            selected: scope == _EpubSearchScope.book,
                            onSelected: (selected) {
                              if (selected && scope != _EpubSearchScope.book) {
                                setModalState(() {
                                  scope = _EpubSearchScope.book;
                                });
                                if (activeQuery.isNotEmpty) {
                                  handleSearch();
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.icon(
                          onPressed: isSearching ? null : handleSearch,
                          icon: const Icon(Icons.search),
                          label: const Text('Search'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(child: buildResults()),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

Widget _buildHighlightedSnippet(
  BuildContext context,
  String snippet,
  String query,
) {
  if (query.isEmpty) {
    return Text(snippet, maxLines: 3, overflow: TextOverflow.ellipsis);
  }

  final theme = Theme.of(context);
  final lowerSnippet = snippet.toLowerCase();
  final lowerQuery = query.toLowerCase();
  final spans = <TextSpan>[];
  var searchStart = 0;

  while (true) {
    final matchIndex = lowerSnippet.indexOf(lowerQuery, searchStart);
    if (matchIndex == -1) {
      if (searchStart < snippet.length) {
        spans.add(TextSpan(text: snippet.substring(searchStart)));
      }
      break;
    }

    if (matchIndex > searchStart) {
      spans.add(TextSpan(text: snippet.substring(searchStart, matchIndex)));
    }

    final matchEnd = matchIndex + lowerQuery.length;
    spans.add(
      TextSpan(
        text: snippet.substring(matchIndex, matchEnd),
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.primary,
        ),
      ),
    );
    searchStart = matchEnd;
  }

  return RichText(
    maxLines: 3,
    overflow: TextOverflow.ellipsis,
    text: TextSpan(style: theme.textTheme.bodyMedium, children: spans),
  );
}

void showChaptersDialog(BuildContext context, EpubReaderService service) {
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Chapters'),
        content: SizedBox(
          width: double.maxFinite,
          child: Builder(
            builder: (context) {
              final items = service.getNavigationItems();
              if (items.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No chapters available.'),
                  ),
                );
              }

              return ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  final isTopLevel = item.depth == 0;
                  final contentPadding = EdgeInsets.only(
                    left: 16.0 + (item.depth * 16.0),
                    right: 16.0,
                  );

                  return ListTile(
                    dense: !isTopLevel,
                    contentPadding: contentPadding,
                    title: Text(
                      item.title,
                      style: isTopLevel
                          ? Theme.of(context).textTheme.titleMedium
                          : Theme.of(context).textTheme.bodyMedium,
                    ),
                    onTap: () {
                      service.goToChapter(item.chapterIndex);
                      Navigator.pop(context);
                    },
                  );
                },
              );
            },
          ),
        ),
      );
    },
  );
}

class _EpubChapterView extends StatefulWidget {
  final EpubReaderService service;
  final int chapterIndex;

  const _EpubChapterView({required this.service, required this.chapterIndex});

  @override
  State<_EpubChapterView> createState() => _EpubChapterViewState();
}

class _EpubChapterViewState extends State<_EpubChapterView> {
  late final ScrollController _controller;
  bool _hasRestored = false;
  int _restoreAttempts = 0;
  double _currentProgress = 0.0;
  late int _lastScrollRequestId;
  final Map<int, GlobalKey> _sectionKeys = <int, GlobalKey>{};

  @override
  void initState() {
    super.initState();
    _controller = ScrollController();
    _controller.addListener(_handleScroll);
    if (widget.chapterIndex == widget.service.currentChapterIndex) {
      _currentProgress = widget.service.scrollPosition.clamp(0.0, 1.0);
    }
    _lastScrollRequestId = widget.service.scrollRequestId;
    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreScroll());
  }

  @override
  void dispose() {
    _controller.removeListener(_handleScroll);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _EpubChapterView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final currentChapter = widget.service.currentChapterIndex;
    if (widget.chapterIndex == currentChapter &&
        oldWidget.service.currentChapterIndex != currentChapter) {
      _hasRestored = false;
      _restoreAttempts = 0;
      _currentProgress = widget.service.scrollPosition.clamp(0.0, 1.0);
      _lastScrollRequestId = widget.service.scrollRequestId;
      WidgetsBinding.instance.addPostFrameCallback((_) => _restoreScroll());
    }

    if (widget.chapterIndex == currentChapter) {
      final requestId = widget.service.scrollRequestId;
      if (requestId != _lastScrollRequestId) {
        _lastScrollRequestId = requestId;
        _hasRestored = false;
        _restoreAttempts = 0;
        _currentProgress = widget.service.scrollPosition.clamp(0.0, 1.0);
        WidgetsBinding.instance.addPostFrameCallback((_) => _restoreScroll());
      }
    }
  }

  void _handleScroll() {
    if (widget.chapterIndex != widget.service.currentChapterIndex) {
      return;
    }

    if (!_controller.hasClients) {
      return;
    }

    final maxScroll = _controller.position.maxScrollExtent;
    if (maxScroll <= 0) {
      widget.service.updateScrollPosition(0.0);
      if (_currentProgress != 0.0) {
        setState(() {
          _currentProgress = 0.0;
        });
      }
      return;
    }

    final position = (_controller.offset / maxScroll).clamp(0.0, 1.0);
    widget.service.updateScrollPosition(position.toDouble());
    if ((position - _currentProgress).abs() > 0.001) {
      setState(() {
        _currentProgress = position.toDouble();
      });
    }
  }

  Future<void> _restoreScroll() async {
    if (!mounted) {
      return;
    }

    if (_hasRestored ||
        widget.chapterIndex != widget.service.currentChapterIndex) {
      return;
    }

    if (!_controller.hasClients) {
      _scheduleRetry();
      return;
    }

    final pendingSection = widget.service.pendingSectionIndex;
    final shouldAlignToAnchor =
        widget.service.pendingSectionShouldAlignToAnchor;
    if (pendingSection != null && shouldAlignToAnchor) {
      final key = _sectionKeys[pendingSection];
      final context = key?.currentContext;
      if (context == null) {
        _scheduleRetry();
        return;
      }

      await Scrollable.ensureVisible(
        context,
        alignment: 0.0,
        duration: Duration.zero,
        curve: Curves.linear,
      );

      final maxScrollAfter = _controller.position.maxScrollExtent;
      final progress = maxScrollAfter <= 0
          ? 0.0
          : (_controller.offset / maxScrollAfter).clamp(0.0, 1.0);
      if (mounted && (progress - _currentProgress).abs() > 0.001) {
        setState(() {
          _currentProgress = progress.toDouble();
        });
      }

      widget.service.markSectionNavigationHandled();
      _hasRestored = true;
      return;
    }

    final maxScroll = _controller.position.maxScrollExtent;
    final targetRatio = widget.service.scrollPosition.clamp(0.0, 1.0);
    final targetOffset = (maxScroll * targetRatio).clamp(0.0, maxScroll);

    if (maxScroll <= 0 && targetRatio > 0 && _restoreAttempts < 5) {
      _scheduleRetry();
      return;
    }

    if (targetOffset > 0) {
      _controller.jumpTo(targetOffset);
    }
    if ((_currentProgress - targetRatio).abs() > 0.001) {
      setState(() {
        _currentProgress = targetRatio.toDouble();
      });
    }
    _hasRestored = true;
  }

  void _scheduleRetry() {
    if (_restoreAttempts >= 5) {
      _hasRestored = true;
      return;
    }
    _restoreAttempts += 1;
    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreScroll());
  }

  void _syncSectionKeys(List<ChapterSectionViewModel> sections) {
    final ids = sections.map((section) => section.scrollKey).toSet();
    _sectionKeys.removeWhere((key, _) => !ids.contains(key));
    for (final section in sections) {
      _sectionKeys.putIfAbsent(section.scrollKey, () => GlobalKey());
    }
  }

  int _resolveCurrentSectionIndex(List<ChapterSectionViewModel> sections) {
    if (sections.isEmpty) {
      return -1;
    }

    const tolerance = 0.0005;
    final progress = _currentProgress.clamp(0.0, 1.0) + tolerance;

    for (var i = 0; i < sections.length; i++) {
      final start = sections[i].startRatio;
      final end = i + 1 < sections.length
          ? sections[i + 1].startRatio
          : 1.0 + tolerance;
      if (progress >= start && progress < end) {
        return i;
      }
    }

    return sections.length - 1;
  }

  void _handlePrevious(
    List<ChapterSectionViewModel> sections,
    int currentSectionIndex,
  ) {
    if (currentSectionIndex > 0 && currentSectionIndex <= sections.length - 1) {
      final target = sections[currentSectionIndex - 1];
      widget.service.navigateToSection(
        widget.chapterIndex,
        sectionIndex: target.sectionIndex,
        scrollPosition: target.startRatio,
      );
      return;
    }

    if (widget.chapterIndex <= 0) {
      return;
    }

    widget.service.goToChapter(widget.chapterIndex - 1);
  }

  void _handleNext(
    List<ChapterSectionViewModel> sections,
    int currentSectionIndex,
  ) {
    if (currentSectionIndex >= 0 && currentSectionIndex < sections.length - 1) {
      final target = sections[currentSectionIndex + 1];
      widget.service.navigateToSection(
        widget.chapterIndex,
        sectionIndex: target.sectionIndex,
        scrollPosition: target.startRatio,
      );
      return;
    }

    final totalChapters = widget.service.chapterCount;
    if (widget.chapterIndex >= totalChapters - 1) {
      return;
    }

    widget.service.goToChapter(widget.chapterIndex + 1);
  }

  Map<String, Style> _buildHtmlStyles({
    required Color textColor,
    required Color backgroundColor,
    required Color emphasisBackground,
    required Color codeBackground,
    required Color tableBorderColor,
    required Color primaryColor,
    required Color highlightBackground,
    required Color highlightForeground,
  }) {
    final fontFamily = _mapFontFamilyToSystem(widget.service.fontFamily);
    final fontSize = widget.service.fontSize;

    return {
      'html': Style(backgroundColor: backgroundColor),
      'body': Style(
        fontFamily: fontFamily,
        fontSize: FontSize(fontSize),
        color: textColor,
        backgroundColor: backgroundColor,
        lineHeight: const LineHeight(1.6),
      ),
      'p': Style(
        fontFamily: fontFamily,
        fontSize: FontSize(fontSize),
        color: textColor,
      ),
      'div': Style(
        fontFamily: fontFamily,
        fontSize: FontSize(fontSize),
        color: textColor,
      ),
      'span': Style(
        fontFamily: fontFamily,
        fontSize: FontSize(fontSize),
        color: textColor,
      ),
      'li': Style(color: textColor),
      'h1': Style(color: textColor),
      'h2': Style(color: textColor),
      'h3': Style(color: textColor),
      'h4': Style(color: textColor),
      'h5': Style(color: textColor),
      'h6': Style(color: textColor),
      'img': Style(
        padding: HtmlPaddings.zero,
        margin: Margins.symmetric(vertical: 8),
        alignment: Alignment.center,
        width: Width.auto(),
        height: Height.auto(),
      ),
      'blockquote': Style(
        margin: Margins.symmetric(vertical: 12, horizontal: 8),
        padding: HtmlPaddings.all(12),
        backgroundColor: emphasisBackground,
        border: Border(left: BorderSide(width: 4, color: primaryColor)),
        fontStyle: FontStyle.italic,
        color: textColor,
      ),
      'code': Style(
        backgroundColor: codeBackground,
        padding: HtmlPaddings.all(8),
        fontFamily: 'monospace',
        color: textColor,
      ),
      'pre': Style(
        backgroundColor: codeBackground,
        padding: HtmlPaddings.all(12),
        fontFamily: 'monospace',
        color: textColor,
      ),
      'ul': Style(
        margin: Margins.symmetric(vertical: 8, horizontal: 12),
        color: textColor,
      ),
      'ol': Style(
        margin: Margins.symmetric(vertical: 8, horizontal: 12),
        color: textColor,
      ),
      'table': Style(
        margin: Margins.symmetric(vertical: 12),
        padding: HtmlPaddings.all(8),
        backgroundColor: emphasisBackground,
        color: textColor,
        border: Border.all(color: tableBorderColor),
      ),
      'th': Style(fontWeight: FontWeight.bold, color: textColor),
      'td': Style(color: textColor),
      'a': Style(color: primaryColor, textDecoration: TextDecoration.underline),
      'strong': Style(color: textColor),
      'em': Style(color: textColor),
      'mark': Style(
        backgroundColor: highlightBackground,
        color: highlightForeground,
        padding: HtmlPaddings.symmetric(horizontal: 2, vertical: 1),
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_lastScrollRequestId != widget.service.scrollRequestId) {
      _lastScrollRequestId = widget.service.scrollRequestId;
      _hasRestored = false;
      _restoreAttempts = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) => _restoreScroll());
    }

    final chapterCount = widget.service.chapterCount;
    final hasPrevious = widget.chapterIndex > 0;
    final hasNext = chapterCount > 0 && widget.chapterIndex < chapterCount - 1;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textColor = colorScheme.onSurface;
    final backgroundColor = colorScheme.surface;
    final emphasisBackground = theme.brightness == Brightness.dark
        ? colorScheme.surfaceVariant.withOpacity(0.25)
        : colorScheme.surfaceVariant.withOpacity(0.55);
    final codeBackground = theme.brightness == Brightness.dark
        ? colorScheme.surfaceVariant.withOpacity(0.35)
        : colorScheme.surfaceVariant.withOpacity(0.75);
    final tableBorderColor = colorScheme.outlineVariant;
    final highlightTerm = widget.service.activeSearchHighlight;
    final highlightBackground = theme.brightness == Brightness.dark
        ? colorScheme.tertiaryContainer.withOpacity(0.75)
        : colorScheme.tertiaryContainer;
    final highlightForeground = colorScheme.onTertiaryContainer;
    final sections = widget.service.getRenderedSections(widget.chapterIndex);
    _syncSectionKeys(sections);
    final currentSectionIndex = _resolveCurrentSectionIndex(sections);
    final hasPreviousSection = currentSectionIndex > 0;
    final hasNextSection =
        currentSectionIndex >= 0 && currentSectionIndex < sections.length - 1;
    final enablePrevious = hasPreviousSection || hasPrevious;
    final enableNext = hasNextSection || hasNext;

    return Column(
      children: [
        Expanded(
          child: Scrollbar(
            controller: _controller,
            thumbVisibility: true,
            interactive: true,
            child: Builder(
              builder: (context) {
                final htmlStyles = _buildHtmlStyles(
                  textColor: textColor,
                  backgroundColor: backgroundColor,
                  emphasisBackground: emphasisBackground,
                  codeBackground: codeBackground,
                  tableBorderColor: tableBorderColor,
                  primaryColor: colorScheme.primary,
                  highlightBackground: highlightBackground,
                  highlightForeground: highlightForeground,
                );

                if (sections.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'No content available.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  controller: _controller,
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  cacheExtent:
                      400.0, // Keep pre-built content small to avoid frame drops.
                  itemCount: sections.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final section = sections[index];
                    return Padding(
                      key: _sectionKeys[section.scrollKey],
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: _SectionHtmlView(
                        section: section,
                        highlightTerm: highlightTerm,
                        backgroundColor: backgroundColor,
                        htmlStyles: htmlStyles,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: enablePrevious
                        ? () => _handlePrevious(sections, currentSectionIndex)
                        : null,
                    icon: const Icon(Icons.chevron_left),
                    label: const Text('Previous'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: enableNext
                        ? () => _handleNext(sections, currentSectionIndex)
                        : null,
                    icon: const Icon(Icons.chevron_right),
                    label: const Text('Next'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionHtmlView extends StatefulWidget {
  const _SectionHtmlView({
    required this.section,
    required this.highlightTerm,
    required this.backgroundColor,
    required this.htmlStyles,
  });

  final ChapterSectionViewModel section;
  final String? highlightTerm;
  final Color backgroundColor;
  final Map<String, Style> htmlStyles;

  @override
  State<_SectionHtmlView> createState() => _SectionHtmlViewState();
}

class _SectionHtmlViewState extends State<_SectionHtmlView>
    with AutomaticKeepAliveClientMixin {
  late String _renderedHtml;

  @override
  void initState() {
    super.initState();
    _renderedHtml = _generateRenderedHtml();
  }

  @override
  void didUpdateWidget(covariant _SectionHtmlView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.section.html != widget.section.html ||
        oldWidget.highlightTerm != widget.highlightTerm) {
      final nextHtml = _generateRenderedHtml();
      if (_renderedHtml != nextHtml) {
        setState(() {
          _renderedHtml = nextHtml;
        });
      }
    }
  }

  String _generateRenderedHtml() {
    return _renderHtmlWithHighlight(widget.section.html, widget.highlightTerm);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ColoredBox(
      color: widget.backgroundColor,
      child: SelectionArea(
        child: Html(data: _renderedHtml, style: widget.htmlStyles),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}

String _renderHtmlWithHighlight(String html, String? term) {
  final query = term?.trim();
  if (query == null || query.isEmpty) {
    return html;
  }

  try {
    final fragment = html_parser.parseFragment(html);
    _stripExistingHighlights(fragment.nodes);
    final pattern = RegExp(RegExp.escape(query), caseSensitive: false);
    _applyHighlightToNodes(fragment.nodes, pattern);
    return fragment.outerHtml;
  } catch (_) {
    return html;
  }
}

void _stripExistingHighlights(List<dom.Node> nodes) {
  for (final node in List<dom.Node>.from(nodes)) {
    if (node is dom.Element) {
      final name = node.localName?.toLowerCase();
      if (name == 'mark' && node.classes.contains('search-highlight')) {
        final parent = node.parent;
        if (parent != null) {
          final children = node.nodes.toList();
          for (final child in children) {
            parent.insertBefore(child, node);
          }
          node.remove();
          continue;
        }
      }
      _stripExistingHighlights(node.nodes);
    }
  }
}

void _applyHighlightToNodes(List<dom.Node> nodes, RegExp pattern) {
  for (final node in List<dom.Node>.from(nodes)) {
    if (node is dom.Element) {
      if (_shouldSkipElement(node)) {
        continue;
      }
      _applyHighlightToNodes(node.nodes, pattern);
    } else if (node is dom.Text) {
      final text = node.text;
      final matches = pattern.allMatches(text).toList();
      if (matches.isEmpty) {
        continue;
      }

      final parent = node.parent;
      if (parent == null) {
        continue;
      }

      final newNodes = <dom.Node>[];
      var currentIndex = 0;
      for (final match in matches) {
        if (match.start > currentIndex) {
          newNodes.add(dom.Text(text.substring(currentIndex, match.start)));
        }
        final highlight = dom.Element.tag('mark')
          ..classes.add('search-highlight')
          ..text = text.substring(match.start, match.end);
        newNodes.add(highlight);
        currentIndex = match.end;
      }
      if (currentIndex < text.length) {
        newNodes.add(dom.Text(text.substring(currentIndex)));
      }

      for (final newNode in newNodes) {
        parent.insertBefore(newNode, node);
      }
      node.remove();
    }
  }
}

bool _shouldSkipElement(dom.Element element) {
  final name = element.localName?.toLowerCase();
  if (name == null) {
    return false;
  }
  return name == 'script' || name == 'style';
}

// Helper function to map font family names to system font families
String? _mapFontFamilyToSystem(String fontName) {
  switch (fontName) {
    case 'Serif':
      return 'serif';
    case 'Sans-serif':
      return 'sans-serif';
    case 'Monospace':
      return 'monospace';
    case 'Roboto':
      return 'Roboto, sans-serif';
    case 'Helvetica':
      return '"Helvetica Neue", Helvetica, Arial, sans-serif';
    case 'Georgia':
      return 'Georgia, serif';
    case 'Times New Roman':
      return '"Times New Roman", Times, serif';
    case 'Courier New':
      return '"Courier New", Courier, monospace';
    case 'Default':
    default:
      return null; // Use the default system font
  }
}

void showFontSettingsDialog(BuildContext context, EpubReaderService service) {
  // Available font families that match the app's settings
  final availableFonts = [
    'Default',
    'Serif',
    'Sans-serif',
    'Monospace',
    'Roboto',
    'Helvetica',
    'Georgia',
    'Times New Roman',
    'Courier New',
  ];

  // Font size adjustment values
  double tempFontSize = service.fontSize;
  String tempFontFamily = service.fontFamily;

  // Make sure the current font family is in the available fonts list
  if (!availableFonts.contains(tempFontFamily)) {
    tempFontFamily =
        'Default'; // Fallback to default if current font isn't in the list
  }

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setModalState) {
          return SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Reader Settings',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                          tooltip: 'Close',
                        ),
                      ],
                    ),
                  ),
                  const Divider(),

                  // Font Size
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Font Size: ${tempFontSize.toStringAsFixed(1)}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Slider(
                          value: tempFontSize,
                          min: 10.0,
                          max: 30.0,
                          divisions: 20,
                          label: tempFontSize.toStringAsFixed(1),
                          onChanged: (value) {
                            setModalState(() {
                              tempFontSize = value;
                            });
                          },
                          onChangeEnd: (value) async {
                            await service.updateFontSize(value);
                          },
                        ),
                      ],
                    ),
                  ),

                  // Font Family
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Font Family',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: tempFontFamily,
                          items: availableFonts
                              .map(
                                (family) => DropdownMenuItem(
                                  value: family,
                                  child: Text(family),
                                ),
                              )
                              .toList(),
                          onChanged: (value) async {
                            if (value != null) {
                              setModalState(() {
                                tempFontFamily = value;
                              });
                              await service.updateFontFamily(value);
                            }
                          },
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await service.resetFontSettings();
                          if (!context.mounted) return;
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reset to Defaults'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
