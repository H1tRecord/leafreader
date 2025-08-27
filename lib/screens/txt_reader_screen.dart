import 'dart:io';
import 'package:flutter/material.dart';
import 'dart:async';

class TxtReaderScreen extends StatefulWidget {
  final String filePath;
  final String fileName;

  const TxtReaderScreen({
    super.key,
    required this.filePath,
    required this.fileName,
  });

  @override
  State<TxtReaderScreen> createState() => _TxtReaderScreenState();
}

class _TxtReaderScreenState extends State<TxtReaderScreen> {
  String? _content;
  String? _errorMessage;
  bool _isLoading = true;
  double _fontSize = 16.0;
  final ScrollController _scrollController = ScrollController();

  // Search related variables
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  List<int> _searchResults = [];
  int _currentSearchIndex = -1;

  // Debounce for search to avoid too many searches while typing
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // Load the text file content
  Future<void> _loadContent() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final file = File(widget.filePath);
      final content = await file.readAsString();

      setState(() {
        _content = content;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading file: $e';
        _isLoading = false;
      });
    }
  }

  // Handle search text changes with debounce
  void _onSearchTextChanged(String text) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();

    // Only search if there's text to search for
    if (text.isEmpty) {
      setState(() {
        _searchResults = [];
        _currentSearchIndex = -1;
      });
      return;
    }

    // Debounce for 300ms to avoid triggering search too frequently
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _performSearch(text);
    });
  }

  // Perform search in text content
  void _performSearch(String query) {
    if (_content == null || query.isEmpty) {
      setState(() {
        _searchResults = [];
        _currentSearchIndex = -1;
      });
      return;
    }

    final results = <int>[];
    final content = _content!.toLowerCase();
    final searchText = query.toLowerCase();

    int index = content.indexOf(searchText);
    while (index != -1) {
      results.add(index);
      index = content.indexOf(searchText, index + 1);
    }

    setState(() {
      _searchResults = results;
      _currentSearchIndex = results.isEmpty ? -1 : 0;
    });

    if (results.isNotEmpty) {
      _scrollToCurrentResult();
    } else {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No results found for "$query"'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // Scroll to the current search result
  void _scrollToCurrentResult() {
    if (_currentSearchIndex < 0 || _searchResults.isEmpty) return;

    final index = _searchResults[_currentSearchIndex];
    final textBefore = _content!.substring(0, index);
    final linesBefore = '\n'.allMatches(textBefore).length;

    // Approximate position - this will get us close to the result
    final estimatedPosition =
        linesBefore * 20.0; // 20 pixels per line is an estimate

    _scrollController.animateTo(
      estimatedPosition,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
    );
  }

  // Navigate to next search result
  void _nextSearchResult() {
    if (_searchResults.isEmpty) return;

    setState(() {
      _currentSearchIndex = (_currentSearchIndex + 1) % _searchResults.length;
    });

    _scrollToCurrentResult();
  }

  // Navigate to previous search result
  void _previousSearchResult() {
    if (_searchResults.isEmpty) return;

    setState(() {
      _currentSearchIndex =
          (_currentSearchIndex - 1 + _searchResults.length) %
          _searchResults.length;
    });

    _scrollToCurrentResult();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: _buildAppBar(), body: _buildBody());
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
              _searchResults = [];
              _currentSearchIndex = -1;
            });
          },
        ),
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Search in text',
            border: InputBorder.none,
            hintStyle: TextStyle(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withAlpha(153), // 0.6 * 255 ≈ 153
            ),
          ),
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          onChanged: _onSearchTextChanged,
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
                  _searchResults = [];
                  _currentSearchIndex = -1;
                });
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
          tooltip: 'Search text',
          onPressed: () {
            setState(() {
              _isSearching = true;
              _searchController.clear();
            });
          },
        ),
        // Font size controls
        IconButton(
          icon: const Icon(Icons.text_decrease),
          tooltip: 'Decrease font size',
          onPressed: () {
            setState(() {
              _fontSize = (_fontSize - 1).clamp(8.0, 32.0);
            });
          },
        ),
        IconButton(
          icon: const Icon(Icons.text_increase),
          tooltip: 'Increase font size',
          onPressed: () {
            setState(() {
              _fontSize = (_fontSize + 1).clamp(8.0, 32.0);
            });
          },
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

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
                'Error Loading Text File',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(_errorMessage!, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        // Text content with scrolling
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            controller: _scrollController,
            child: RichText(text: _buildTextSpan()),
          ),
        ),

        // Search navigation panel if we have results
        if (_isSearching && _searchResults.isNotEmpty)
          _buildSearchNavigationPanel(),
      ],
    );
  }

  // Build text span with highlighted search results if any
  TextSpan _buildTextSpan() {
    if (_content == null) {
      return const TextSpan(text: '');
    }

    // If no search results, return the plain text
    if (!_isSearching || _searchResults.isEmpty) {
      return TextSpan(
        text: _content,
        style: TextStyle(fontSize: _fontSize),
      );
    }

    // If we have search results, highlight them
    final content = _content!;
    final searchText = _searchController.text;
    final spans = <TextSpan>[];

    int lastEnd = 0;

    for (int i = 0; i < _searchResults.length; i++) {
      final start = _searchResults[i];
      final end = start + searchText.length;

      // Add text before the search result
      if (start > lastEnd) {
        spans.add(
          TextSpan(
            text: content.substring(lastEnd, start),
            style: TextStyle(fontSize: _fontSize),
          ),
        );
      }

      // Add the highlighted search result
      spans.add(
        TextSpan(
          text: content.substring(start, end),
          style: TextStyle(
            fontSize: _fontSize,
            backgroundColor: i == _currentSearchIndex
                ? Colors.orange.withAlpha(
                    179,
                  ) // Current result (0.7 * 255 ≈ 179)
                : Colors.yellow.withAlpha(77), // Other results (0.3 * 255 ≈ 77)
            fontWeight: i == _currentSearchIndex
                ? FontWeight.bold
                : FontWeight.normal,
          ),
        ),
      );

      lastEnd = end;
    }

    // Add remaining text
    if (lastEnd < content.length) {
      spans.add(
        TextSpan(
          text: content.substring(lastEnd),
          style: TextStyle(fontSize: _fontSize),
        ),
      );
    }

    return TextSpan(children: spans);
  }

  // Build search navigation panel
  Widget _buildSearchNavigationPanel() {
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
                  'Result ${_currentSearchIndex + 1} of ${_searchResults.length}',
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
                      onPressed: _previousSearchResult,
                    ),
                    // Next result button
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_down),
                      tooltip: 'Next result',
                      onPressed: _nextSearchResult,
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
}
