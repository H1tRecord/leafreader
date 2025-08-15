import 'dart:io';
import 'package:flutter/material.dart';
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
        appBar: AppBar(
          title: !_isLoading && _errorMessage == null
              ? EpubViewActualChapter(
                  controller: _epubController,
                  builder: (chapterValue) {
                    // If there's a chapter title, display it; otherwise, fall back to the filename
                    final chapterTitle = chapterValue?.chapter?.Title?.trim();
                    return Text(
                      chapterTitle != null && chapterTitle.isNotEmpty
                          ? chapterTitle
                          : widget.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    );
                  },
                )
              : Text(widget.fileName),
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

    return EpubView(
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
    );
  }

  void _showChaptersDialog() {
    final chapters = _epubController.tableOfContents();

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Chapters', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              const Divider(),
              Expanded(
                child: chapters.isEmpty
                    ? const Center(child: Text('No chapters found'))
                    : ListView.builder(
                        itemCount: chapters.length,
                        itemBuilder: (context, index) {
                          final chapter = chapters[index];
                          return ListTile(
                            title: Text(
                              chapter.title ?? 'Chapter ${index + 1}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () {
                              // Using the scrollTo method to navigate to the chapter's start index
                              _epubController.scrollTo(
                                index: chapter.startIndex,
                              );
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
    );
  }
}
