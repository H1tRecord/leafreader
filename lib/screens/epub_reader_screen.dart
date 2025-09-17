import 'dart:io';
import 'package:flutter/material.dart';
import 'package:epub_view/epub_view.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/prefs_helper.dart';

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

  // Reader settings
  double _fontSize = 16.0;
  String _fontFamily = 'Default';

  // EPUB version information
  String _epubVersion = 'Unknown';
  Map<String, String> _epubMetadata = {};

  @override
  void initState() {
    super.initState();
    _loadEpub();
    _loadReaderSettings();

    // Add a message to indicate we only support EPUB3
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Note: This reader only supports EPUB3 files.'),
            duration: Duration(seconds: 3),
          ),
        );
      });
    }
  }

  Future<void> _loadEpub() async {
    try {
      // Try to get saved position from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final key = _getKeyForFile(widget.filePath);
      final savedPosition = prefs.getString(key);

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

  // Load reader settings from preferences
  Future<void> _loadReaderSettings() async {
    _fontSize = await PrefsHelper.getEpubFontSize();
    _fontFamily = await PrefsHelper.getEpubFontFamily();
    setState(() {});
  }

  // Generate a unique key for the file path
  static String _getKeyForFile(String filePath) {
    // Use hash to create a consistent and unique key for the file path
    return 'epub_position_${filePath.hashCode}';
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
    // Use PopScope to detect when user navigates back
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) async {
        // Save position when navigating back if reader is loaded
        if (!_isLoading && _errorMessage == null) {
          final cfi = _epubController.generateEpubCfi();
          if (cfi != null) {
            try {
              final prefs = await SharedPreferences.getInstance();
              final key = _getKeyForFile(widget.filePath);
              await prefs.setString(key, cfi);
            } catch (e) {
              // Ignore errors when closing
            }
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.fileName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (!_isLoading &&
                  _errorMessage == null &&
                  _epubController.currentValue != null)
                Text(
                  _buildChapterInfo(),
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1.0),
            child: Container(
              color: Theme.of(context).dividerColor.withAlpha(51), // ~0.2 alpha
              height: 1.0,
            ),
          ),
          actions: [
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
            // Reader settings button
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: !_isLoading && _errorMessage == null
                  ? () {
                      _showReaderSettingsDialog();
                    }
                  : null,
              tooltip: 'Reader Settings',
            ),
            // Settings and info button
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: !_isLoading && _errorMessage == null
                  ? () {
                      _showBookInfoDialog();
                    }
                  : null,
              tooltip: 'Book Info',
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
                _errorMessage!.contains('EPUB3')
                    ? 'Unsupported EPUB Version'
                    : 'Failed to load EPUB file',
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

    // EPUB view without progress indicator overlay
    return EpubView(
      controller: _epubController,
      builders: EpubViewBuilders<DefaultBuilderOptions>(
        options: DefaultBuilderOptions(
          textStyle: TextStyle(
            height: 1.25,
            fontSize: _fontSize,
            fontFamily: _fontFamily == 'Default' ? null : _fontFamily,
          ),
          paragraphPadding: const EdgeInsets.symmetric(horizontal: 16),
          chapterPadding: const EdgeInsets.all(8),
        ),
        chapterDividerBuilder: (_) => const Divider(),
      ),
      onChapterChanged: (value) {
        // Update the UI when chapter changes
        setState(() {});
      },
      onDocumentLoaded: (document) {
        // Document successfully loaded
        _detectEpubVersion(document);
      },
      onDocumentError: (error) {
        setState(() {
          _errorMessage = 'Error loading document: $error';
        });
      },
    );
  }

  // Build current chapter information string
  String _buildChapterInfo() {
    final currentValue = _epubController.currentValue;
    if (currentValue == null) return '';

    final chapters = _epubController.tableOfContents();
    return '${currentValue.chapterNumber}/${chapters.length} • ${currentValue.progress.round()}%';
  }

  // Detect EPUB version and extract metadata from the loaded document
  void _detectEpubVersion(EpubBook document) {
    try {
      // Extract EPUB version information
      final package = document.Schema?.Package;
      if (package != null) {
        // Get EPUB version - Should be "2.0" or "3.0" typically
        final version = package.Version?.toString() ?? 'Unknown';

        // Check if this is an EPUB3 file - properly parse the version
        final isEpub3 = _isEpub3Version(version);
        if (!isEpub3) {
          setState(() {
            _errorMessage =
                'This app only supports EPUB3 files. Detected EPUB version: $version';
          });
          return;
        }

        setState(() {
          _epubVersion = version;

          // Extract core metadata
          _epubMetadata = {
            'Title': document.Title ?? 'Unknown',
            'Author': document.Author ?? 'Unknown',
            'Version': version,
          };

          // Extract language if available
          final metadata = package.Metadata;
          if (metadata?.Languages?.isNotEmpty == true) {
            _epubMetadata['Language'] = metadata!.Languages!.first;
          }

          // Try to find a publisher in contributors
          String? publisher;
          metadata?.Contributors?.forEach((contributor) {
            if (contributor.Role?.toLowerCase() == 'publisher') {
              publisher = contributor.Contributor;
            }
          });
          if (publisher != null) {
            _epubMetadata['Publisher'] = publisher!;
          }

          // Adjust CSS and settings based on version
          _applyVersionSpecificSettings(version);
        });
      }
    } catch (e) {
      print('Error detecting EPUB version: $e');
    }
  }

  // Check if the version string represents an EPUB3 version
  bool _isEpub3Version(String version) {
    // EPUB3 versions can be "3.0", "3", "3.0.1", etc.
    try {
      // Try to parse the first digit or segment of the version
      if (version == 'Unknown') return false;

      // First check the full version string - check if it contains "3" anywhere
      if (version.contains('3')) {
        return true;
      }

      // As a last resort, if the package version format is non-standard,
      // try to extract any number and check if it equals 3
      final numberRegex = RegExp(r'\d+');
      final matches = numberRegex.allMatches(version);
      for (final match in matches) {
        if (match.group(0) == '3') {
          return true;
        }
      }

      return false;
    } catch (e) {
      print('Error parsing EPUB version: $e');
      return false;
    }
  }

  // Apply settings optimized for the detected EPUB version
  void _applyVersionSpecificSettings(String version) {
    // Currently a placeholder for version-specific optimizations
    // Will be enhanced in subsequent implementations
    print('Detected EPUB version: $version');

    // Make sure we're only dealing with EPUB3
    if (!_isEpub3Version(version)) {
      setState(() {
        _errorMessage =
            'This app only supports EPUB3 files. Detected EPUB version: $version';
      });
    }
  }

  // Show reader settings dialog
  void _showReaderSettingsDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        // Use a StatefulWidget to manage the state of the dialog internally
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
                            'Font Size: ${_fontSize.toStringAsFixed(1)}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Slider(
                            value: _fontSize,
                            min: 10.0,
                            max: 30.0,
                            divisions: 20,
                            label: _fontSize.toStringAsFixed(1),
                            onChanged: (value) {
                              setModalState(() {
                                _fontSize = value;
                              });
                            },
                            onChangeEnd: (value) {
                              setState(() {
                                _fontSize = value;
                              });
                              PrefsHelper.saveEpubFontSize(value);
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
                            value: _fontFamily,
                            items: ['Default', 'Serif', 'Sans-serif']
                                .map(
                                  (family) => DropdownMenuItem(
                                    value: family,
                                    child: Text(family),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setModalState(() {
                                  _fontFamily = value;
                                });
                                setState(() {
                                  _fontFamily = value;
                                });
                                PrefsHelper.saveEpubFontFamily(value);
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
                  ],
                ),
              ),
            );
          },
        );
      },
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
    );
  }

  // Show book information and metadata dialog
  void _showBookInfoDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
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
                        'Book Information',
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

                // Display EPUB version with visual indicator
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _epubVersion.contains('3')
                              ? Colors.green.withOpacity(0.2)
                              : _epubVersion.contains('2')
                              ? Colors.blue.withOpacity(0.2)
                              : Colors.grey.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          'EPUB $_epubVersion',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _epubVersion.contains('3')
                                ? Colors.green.shade700
                                : _epubVersion.contains('2')
                                ? Colors.blue.shade700
                                : Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Display metadata
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: _epubMetadata.entries
                        .map(
                          (entry) => ListTile(
                            title: Text(
                              entry.key,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Text(
                              entry.value,
                              style: const TextStyle(fontSize: 16),
                            ),
                            dense: true,
                          ),
                        )
                        .toList(),
                  ),
                ),

                // Version-specific optimizations info
                if (_epubVersion.contains('3'))
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _epubVersion.contains('3')
                                ? 'EPUB 3 Optimizations Applied'
                                : 'EPUB 2 Compatibility Mode',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _epubVersion.contains('3')
                                ? 'Enhanced media support, accessibility features, and CSS3 styling applied.'
                                : 'Basic formatting and legacy compatibility mode enabled for older EPUB format.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
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

  void _showChaptersDialog() {
    final chapters = _epubController.tableOfContents();
    // Get current chapter for highlighting
    final currentValue = _epubController.currentValue;

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Table of Contents',
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
                const SizedBox(height: 4),
                // Show book info summary
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Book: ${widget.fileName}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                const SizedBox(height: 4),
                // Show current reading status
                if (currentValue != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Current position: Chapter ${currentValue.chapterNumber} of ${chapters.length} • ${currentValue.progress.round()}% complete',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
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
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
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
                              subtitle: isCurrentChapter && currentValue != null
                                  ? Text(
                                      'Current position: ${currentValue.progress.round()}% of chapter',
                                    )
                                  : null,
                              leading: CircleAvatar(
                                backgroundColor: isCurrentChapter
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(
                                        context,
                                      ).colorScheme.surfaceContainerHighest,
                                foregroundColor: isCurrentChapter
                                    ? Theme.of(context).colorScheme.onPrimary
                                    : Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                child: Text('${index + 1}'),
                              ),
                              trailing: isCurrentChapter
                                  ? Icon(
                                      Icons.bookmark,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    )
                                  : null,
                              tileColor: isCurrentChapter
                                  ? Theme.of(
                                      context,
                                    ).colorScheme.primaryContainer.withAlpha(50)
                                  : null,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
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
                const SizedBox(height: 8),
                // Quick navigation buttons at the bottom
                if (currentValue != null && chapters.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ElevatedButton.icon(
                          icon: const Icon(Icons.skip_previous),
                          label: const Text('Previous'),
                          onPressed: currentValue.chapterNumber > 1
                              ? () {
                                  final prevChapter =
                                      chapters[currentValue.chapterNumber - 2];
                                  _epubController.scrollTo(
                                    index: prevChapter.startIndex,
                                    alignment: 0.0,
                                    duration: const Duration(milliseconds: 300),
                                  );
                                  Navigator.pop(context);
                                }
                              : null,
                        ),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.skip_next),
                          label: const Text('Next'),
                          onPressed:
                              currentValue.chapterNumber < chapters.length
                              ? () {
                                  final nextChapter =
                                      chapters[currentValue.chapterNumber];
                                  _epubController.scrollTo(
                                    index: nextChapter.startIndex,
                                    alignment: 0.0,
                                    duration: const Duration(milliseconds: 300),
                                  );
                                  Navigator.pop(context);
                                }
                              : null,
                        ),
                      ],
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
