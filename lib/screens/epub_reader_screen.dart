import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:epub_view/epub_view.dart';
import '../utils/reader_position_helper.dart';

class EpubReaderScreen extends StatefulWidget {
  final String filePath;
  final String fileName;

  const EpubReaderScreen({
    super.key,
    required this.filePath,
    required this.fileName,
  });

  @override
  State<EpubReaderScreen> createState() => _EpubReaderScreenState();
}

class _EpubReaderScreenState extends State<EpubReaderScreen> {
  late EpubController _epubController;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadEpub();
  }

  Future<void> _loadEpub() async {
    try {
      // Try to get saved position
      final savedPosition = await ReaderPositionHelper.getPosition(
        widget.filePath,
      );

      _epubController = EpubController(
        document: EpubDocument.openFile(File(widget.filePath)),
        // Use saved position if available
        epubCfi: savedPosition,
      );

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error loading EPUB file: $e';
      });
    }
  }

  @override
  void dispose() {
    // Always dispose the controller if it was initialized
    if (!_isLoading) {
      _epubController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Use WillPopScope to detect when user navigates back
    return WillPopScope(
      onWillPop: () async {
        // Save position when navigating back if reader is loaded
        if (!_isLoading && _errorMessage == null) {
          final cfi = _epubController.generateEpubCfi();
          if (cfi != null) {
            await ReaderPositionHelper.savePosition(widget.filePath, cfi);
          }
        }
        return true; // Allow navigation
      },
      child: Scaffold(
        extendBody:
            true, // Allow content to go behind the bottom navigation bar
        appBar: AppBar(
          title: !_isLoading && _errorMessage == null
              ? EpubViewActualChapter(
                  controller: _epubController,
                  builder: (chapterValue) {
                    // If there's a chapter title, display it; otherwise, fall back to the filename
                    final chapterTitle = chapterValue?.chapter?.Title?.trim();
                    final displayTitle =
                        chapterTitle != null && chapterTitle.isNotEmpty
                        ? chapterTitle
                        : widget.fileName;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          displayTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (chapterValue != null) ...[
                          const SizedBox(height: 2),
                          // Reading progress indicator
                          LinearProgressIndicator(
                            value: chapterValue.progress / 100,
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.surfaceVariant,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).colorScheme.primary,
                            ),
                            minHeight: 3,
                          ),
                        ],
                      ],
                    );
                  },
                )
              : Text(widget.fileName),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1.0),
            child: Container(
              color: Theme.of(context).dividerColor.withOpacity(0.2),
              height: 1.0,
            ),
          ),
          actions: [
            // Save reading position button
            IconButton(
              icon: const Icon(Icons.bookmark_add),
              onPressed: !_isLoading && _errorMessage == null
                  ? () async {
                      final cfi = _epubController.generateEpubCfi();
                      if (cfi != null) {
                        final saved = await ReaderPositionHelper.savePosition(
                          widget.filePath,
                          cfi,
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              saved
                                  ? 'Reading position saved'
                                  : 'Failed to save position',
                            ),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      }
                    }
                  : null,
              tooltip: 'Save Position',
            ),
            // Chapter navigation button
            IconButton(
              icon: const Icon(Icons.list),
              onPressed: !_isLoading && _errorMessage == null
                  ? () {
                      _showChaptersDialog();
                    }
                  : null,
              tooltip: 'Chapters',
            ),
            // Settings button (for future implementation)
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: !_isLoading && _errorMessage == null
                  ? () {
                      // TODO: Implement reader settings
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Reader settings coming soon!'),
                        ),
                      );
                    }
                  : null,
              tooltip: 'Settings',
            ),
          ],
        ),
        body: _buildBody(),
        // Bottom navigation bar for quick chapter navigation
        bottomNavigationBar: !_isLoading && _errorMessage == null
            ? _buildBottomNavigationBar()
            : null,
      ),
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
              Icon(
                Icons.error_outline,
                size: 60,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Failed to load EPUB file',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    // Create a gesture detector for swipe navigation
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if (!_isLoading && _errorMessage == null) {
          final currentValue = _epubController.currentValue;
          if (currentValue == null) return;

          // Get current position
          final currentIndex = currentValue.position.index;

          // Swipe from right to left (next page)
          if (details.primaryVelocity! < 0) {
            _epubController.scrollTo(
              index: currentIndex + 1,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
          // Swipe from left to right (previous page)
          else if (details.primaryVelocity! > 0) {
            if (currentIndex > 0) {
              _epubController.scrollTo(
                index: currentIndex - 1,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            }
          }
        }
      },
      // Use keyboard detection for navigation (left/right arrow keys)
      child: RawKeyboardListener(
        focusNode: FocusNode()..requestFocus(),
        onKey: (event) {
          if (!_isLoading && _errorMessage == null) {
            // Only handle key up events to avoid duplicate navigation
            if (event is! RawKeyUpEvent) return;

            final currentValue = _epubController.currentValue;
            if (currentValue == null) return;

            // Get current position
            final currentIndex = currentValue.position.index;

            // Navigate using arrow keys
            if (event.logicalKey.keyLabel == 'Arrow Right') {
              // Next page - increase index by 1
              _epubController.scrollTo(
                index: currentIndex + 1,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            } else if (event.logicalKey.keyLabel == 'Arrow Left') {
              // Previous page - decrease index by 1 if possible
              if (currentIndex > 0) {
                _epubController.scrollTo(
                  index: currentIndex - 1,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
              }
            }
          }
        },
        child: EpubView(
          controller: _epubController,
          builders: EpubViewBuilders<DefaultBuilderOptions>(
            options: const DefaultBuilderOptions(
              textStyle: TextStyle(height: 1.25, fontSize: 16),
              paragraphPadding: EdgeInsets.symmetric(horizontal: 16),
              chapterPadding: EdgeInsets.all(8),
            ),
            chapterDividerBuilder: (_) => const Divider(),
          ),
          onChapterChanged: (value) {
            // Update the app bar title with the current chapter
            setState(() {});
          },
          onDocumentLoaded: (document) {
            // Document successfully loaded
          },
          onDocumentError: (error) {
            // Handle document loading error
            setState(() {
              _errorMessage = 'Error loading document: $error';
            });
          },
        ),
      ),
    );
  }

  // Build a bottom navigation bar with chapter navigation controls
  Widget _buildBottomNavigationBar() {
    // Get current chapter info
    final currentValue = _epubController.currentValue;
    if (currentValue == null) return const SizedBox.shrink();

    final chapters = _epubController.tableOfContents();
    if (chapters.isEmpty) return const SizedBox.shrink();

    // Calculate current chapter index
    final int currentChapterIndex = currentValue.chapterNumber - 1;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, -1),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Previous chapter button
            IconButton(
              icon: const Icon(Icons.skip_previous),
              onPressed: currentChapterIndex > 0
                  ? () {
                      _epubController.scrollTo(
                        index: chapters[currentChapterIndex - 1].startIndex,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    }
                  : null,
              tooltip: 'Previous Chapter',
            ),
            // Show chapter info
            TextButton(
              onPressed: () => _showChaptersDialog(),
              child: Text(
                'Chapter ${currentValue.chapterNumber} of ${chapters.length}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            // Next chapter button
            IconButton(
              icon: const Icon(Icons.skip_next),
              onPressed: currentChapterIndex < chapters.length - 1
                  ? () {
                      _epubController.scrollTo(
                        index: chapters[currentChapterIndex + 1].startIndex,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    }
                  : null,
              tooltip: 'Next Chapter',
            ),
          ],
        ),
      ),
    );
  }

  void _showChaptersDialog() {
    final chapters = _epubController.tableOfContents();
    // Get current chapter for highlighting
    final currentValue = _epubController.currentValue;

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Chapters',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                      tooltip: 'Close',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Divider(),
                chapters.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Center(child: Text('No chapters found')),
                      )
                    : Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: chapters.length,
                          itemBuilder: (context, index) {
                            final chapter = chapters[index];
                            // Check if this is the current chapter for highlighting
                            final bool isCurrentChapter =
                                currentValue?.chapterNumber == index + 1;

                            return ListTile(
                              title: Text(
                                chapter.title ?? 'Chapter ${index + 1}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: isCurrentChapter
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                              leading: isCurrentChapter
                                  ? Icon(
                                      Icons.bookmark,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    )
                                  : const SizedBox(
                                      width: 24,
                                    ), // Same width as icon for alignment
                              tileColor: isCurrentChapter
                                  ? Theme.of(context)
                                        .colorScheme
                                        .primaryContainer
                                        .withOpacity(0.3)
                                  : null,
                              onTap: () {
                                // Using the scrollTo method to navigate to the chapter's start index
                                _epubController.scrollTo(
                                  index: chapter.startIndex,
                                  alignment: 0.0, // Align to top
                                  duration: const Duration(milliseconds: 300),
                                );
                                Navigator.pop(context);
                              },
                            );
                          },
                        ),
                      ),
              ],
            ),
          ),
        );
      },
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
    );
  }
}
