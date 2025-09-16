import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class PdfReaderScreen extends StatefulWidget {
  final String filePath;
  final String fileName;

  const PdfReaderScreen({
    super.key,
    required this.filePath,
    required this.fileName,
  });

  @override
  State<PdfReaderScreen> createState() => _PdfReaderScreenState();
}

class _PdfReaderScreenState extends State<PdfReaderScreen> {
  final PdfViewerController _pdfViewerController = PdfViewerController();
  final GlobalKey<SfPdfViewerState> _pdfViewerKey = GlobalKey();
  String? _errorMessage;
  bool _showScrollHead = true;
  bool _showPageNavigation = true;
  PdfPageLayoutMode _pageLayoutMode = PdfPageLayoutMode.continuous;

  // Search related variables
  PdfTextSearchResult _searchResult = PdfTextSearchResult();
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  // Debounce for search to avoid too many searches while typing
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    // Add listener to controller to update UI when page changes
    _pdfViewerController.addListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    // Trigger rebuild when controller changes (page navigation, zoom, etc.)
    setState(() {
      // This empty setState will rebuild the widget with updated controller values
    });
  }

  @override
  void dispose() {
    _pdfViewerController.removeListener(_onControllerChanged);
    _pdfViewerController.dispose();
    _searchController.dispose();
    // Clean up search result
    if (_searchResult.hasResult) {
      _searchResult.removeListener(_onSearchResultChanged);
      _searchResult.clear();
    }
    // Cancel any pending debounce timers
    _debounce?.cancel();
    super.dispose();
  }

  // Handle real-time search as text changes with debounce
  void _onSearchTextChanged(String text) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();

    // Only search if there's text to search for
    if (text.isEmpty) {
      if (_searchResult.hasResult) {
        _searchResult.removeListener(_onSearchResultChanged);
        _searchResult.clear();
        setState(() {});
      }
      return;
    }

    // Debounce for 300ms to avoid triggering search too frequently
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (text.isNotEmpty) {
        _startSearch(text);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _buildBody(),
      bottomNavigationBar: _showPageNavigation
          ? _buildBottomNavigationBar()
          : null,
    );
  }

  PreferredSizeWidget _buildAppBar() {
    // Show search bar in AppBar when searching is active
    if (_isSearching) {
      return AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // Cancel any pending search
            if (_debounce?.isActive ?? false) _debounce?.cancel();

            setState(() {
              _isSearching = false;
              if (_searchResult.hasResult) {
                _searchResult.removeListener(_onSearchResultChanged);
                _searchResult.clear();
              }
            });
          },
        ),
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Search in PDF',
            border: InputBorder.none,
            hintStyle: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          onChanged: _onSearchTextChanged,
          onSubmitted: (value) {
            if (value.isNotEmpty) {
              _startSearch(value);
            }
          },
        ),
        actions: [
          // Clear search text button
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                // Cancel any pending search
                if (_debounce?.isActive ?? false) _debounce?.cancel();

                setState(() {
                  _searchController.clear();
                  if (_searchResult.hasResult) {
                    _searchResult.removeListener(_onSearchResultChanged);
                    _searchResult.clear();
                  }
                });
              },
            ),
          // Execute search button - only show when we have text but need a manual search
          if (_searchController.text.isNotEmpty && !_searchResult.hasResult)
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: 'Search',
              onPressed: () {
                if (_searchController.text.isNotEmpty) {
                  _startSearch(_searchController.text);
                }
              },
            ),
        ],
      );
    }

    // Regular AppBar when not searching
    return AppBar(
      title: Text(widget.fileName),
      actions: [
        // Search button
        IconButton(
          icon: const Icon(Icons.search),
          tooltip: 'Search PDF',
          onPressed: () {
            setState(() {
              _isSearching = true;
              _searchController.clear();
            });
          },
        ),
        // Layout mode toggle
        IconButton(
          icon: _pageLayoutMode == PdfPageLayoutMode.continuous
              ? const Icon(Icons.view_agenda_outlined)
              : const Icon(Icons.auto_stories),
          tooltip: 'Toggle page layout',
          onPressed: _togglePageLayoutMode,
        ),
        // Zoom controls
        PopupMenuButton<String>(
          tooltip: 'More options',
          onSelected: _handleMenuSelection,
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'zoom_in',
              child: Row(
                children: [
                  Icon(Icons.zoom_in),
                  SizedBox(width: 8),
                  Text('Zoom in'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'zoom_out',
              child: Row(
                children: [
                  Icon(Icons.zoom_out),
                  SizedBox(width: 8),
                  Text('Zoom out'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'page_nav',
              child: Row(
                children: [
                  Icon(Icons.swap_vert),
                  SizedBox(width: 8),
                  Text('Toggle page navigation'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'scroll_head',
              child: Row(
                children: [
                  Icon(Icons.view_sidebar),
                  SizedBox(width: 8),
                  Text('Toggle scroll head'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Handle menu selections
  void _handleMenuSelection(String value) {
    switch (value) {
      case 'zoom_in':
        _pdfViewerController.zoomLevel = _pdfViewerController.zoomLevel + 0.25;
        break;
      case 'zoom_out':
        if (_pdfViewerController.zoomLevel > 0.5) {
          _pdfViewerController.zoomLevel =
              _pdfViewerController.zoomLevel - 0.25;
        }
        break;
      case 'page_nav':
        setState(() {
          _showPageNavigation = !_showPageNavigation;
        });
        break;
      case 'scroll_head':
        setState(() {
          _showScrollHead = !_showScrollHead;
        });
        break;
    }
  }

  // Toggle between continuous and single page layout
  void _togglePageLayoutMode() {
    setState(() {
      _pageLayoutMode = _pageLayoutMode == PdfPageLayoutMode.continuous
          ? PdfPageLayoutMode.single
          : PdfPageLayoutMode.continuous;
    });
  } // Build bottom navigation bar

  Widget _buildBottomNavigationBar() {
    // Get current values for page display
    final int currentPage = _pdfViewerController.pageNumber;
    final int totalPages = _pdfViewerController.pageCount;

    return BottomAppBar(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_left),
              tooltip: 'Previous page',
              onPressed: currentPage > 1
                  ? () {
                      _pdfViewerController.previousPage();
                    }
                  : null,
            ),
            GestureDetector(
              onTap: () {
                _showPageNavigationDialog();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 8.0,
                  horizontal: 12.0,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16.0),
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                child: Text(
                  'Page $currentPage of $totalPages',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_right),
              tooltip: 'Next page',
              onPressed: currentPage < totalPages
                  ? () {
                      _pdfViewerController.nextPage();
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  // Show a dialog to navigate to a specific page
  Future<void> _showPageNavigationDialog() async {
    // Get the current values before showing dialog
    final int currentPage = _pdfViewerController.pageNumber;
    final int totalPages = _pdfViewerController.pageCount;

    final TextEditingController pageController = TextEditingController();
    pageController.text = currentPage.toString();

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Go to page'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enter page number (1-$totalPages)',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: pageController,
              keyboardType: TextInputType.number,
              autofocus: true,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final int? pageNumber = int.tryParse(pageController.text);
              if (pageNumber != null &&
                  pageNumber > 0 &&
                  pageNumber <= totalPages) {
                _pdfViewerController.jumpToPage(pageNumber);
                // Force rebuild UI with new page number
                setState(() {});
              } else {
                // Show error for invalid page number
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Please enter a valid page number (1-$totalPages)',
                    ),
                  ),
                );
              }
              Navigator.pop(context);
            },
            child: const Text('Go'),
          ),
        ],
      ),
    );
  }

  // Search result update handler
  void _onSearchResultChanged() {
    if (_searchResult.isSearchCompleted) {
      setState(() {}); // Update UI

      // Only show alert when no results are found
      if (!_searchResult.hasResult) {
        // Clear any existing SnackBars first
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No results found for "${_searchController.text}"'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  // Start search in PDF
  void _startSearch(String searchText) {
    // Remove any existing listener first to prevent duplicates
    if (_searchResult.hasResult) {
      _searchResult.removeListener(_onSearchResultChanged);
      _searchResult.clear();
    }

    // Start the search with case insensitive option and enable searching for multiple words
    _searchResult = _pdfViewerController.searchText(
      searchText,
      // Use default search option which supports multiple word searches
    );

    // Set search mode active
    setState(() {
      _isSearching = true;
    });

    // On web platform, search is synchronous
    if (kIsWeb) {
      // Only show alert when no results are found
      if (!_searchResult.hasResult) {
        // Clear any existing SnackBars first
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No results found for "$searchText"'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
    // On mobile platforms, search is asynchronous
    else {
      // Add a listener to get notified when search is completed
      _searchResult.addListener(_onSearchResultChanged);
    }
  }

  // Build search results panel
  Widget _buildSearchResultsPanel() {
    if (!_isSearching || !_searchResult.hasResult) {
      return const SizedBox.shrink();
    }

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Material(
        elevation: 4,
        child: Container(
          color: Theme.of(context).colorScheme.surface,
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
          child: SafeArea(
            top: false,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Results count indicator
                Text(
                  'Result ${_searchResult.currentInstanceIndex} of ${_searchResult.totalInstanceCount}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                // Navigation controls
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Previous result button
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_up),
                      tooltip: 'Previous result',
                      onPressed: _searchResult.hasResult
                          ? () {
                              _searchResult.previousInstance();
                              setState(() {});
                            }
                          : null,
                    ),
                    // Next result button
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_down),
                      tooltip: 'Next result',
                      onPressed: _searchResult.hasResult
                          ? () {
                              _searchResult.nextInstance();
                              setState(() {});
                            }
                          : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Error Loading PDF',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(_errorMessage!, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    // Use SfPdfViewer for displaying the PDF
    return Stack(
      children: [
        SfPdfViewer.file(
          File(widget.filePath),
          key: _pdfViewerKey,
          controller: _pdfViewerController,
          canShowScrollHead: _showScrollHead,
          canShowScrollStatus: true,
          canShowPaginationDialog: true,
          pageLayoutMode: _pageLayoutMode,
          enableTextSelection: true,
          onTextSelectionChanged: (PdfTextSelectionChangedDetails details) {
            if (details.selectedText != null &&
                details.selectedText!.isNotEmpty) {
              debugPrint('Selected text: ${details.selectedText}');
              // You could implement a copy option or other text actions here
            }
          },
          onPageChanged: (PdfPageChangedDetails details) {
            // Force a rebuild when page changes to update UI
            setState(() {});
          },
        ),
        // Show search results panel
        _buildSearchResultsPanel(),
      ],
    );
  }
}
