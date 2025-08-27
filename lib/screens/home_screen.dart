import 'package:flutter/material.dart';
import 'dart:io';
import '../utils/prefs_helper.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import './epub_reader_screen.dart';
import './pdf_reader_screen.dart';
import './txt_reader_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<FileSystemEntity> _files = [];
  List<FileSystemEntity> _filteredFiles = [];
  bool _isLoading = true;
  String? _selectedFolderPath;
  String? _errorMessage;
  bool _isGridView = false; // Toggle between list and grid view
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadFiles();
    _searchController.addListener(_filterFiles);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Filter files based on search query
  void _filterFiles() {
    final query = _searchController.text.toLowerCase();

    setState(() {
      if (query.isEmpty) {
        _filteredFiles = List.from(_files);
      } else {
        _filteredFiles = _files.where((file) {
          final fileName = path.basename(file.path).toLowerCase();
          return fileName.contains(query);
        }).toList();
      }
    });
  }

  // Load files from the selected folder
  Future<void> _loadFiles() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Get the selected folder path from preferences
      _selectedFolderPath = await PrefsHelper.getSelectedFolder();

      // If no folder is selected, prompt the user to select one
      if (_selectedFolderPath == null) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'No folder selected. Please select a folder containing your books.';
        });
        return;
      }

      // Check if the directory exists
      final directory = Directory(_selectedFolderPath!);
      if (!await directory.exists()) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Selected folder does not exist. Please choose another folder.';
        });
        return;
      }

      // List all files in the directory
      final List<FileSystemEntity> allFiles = await directory.list().toList();

      // Filter for supported file types
      final supportedFiles = allFiles.where((file) {
        if (file is File) {
          final extension = path.extension(file.path).toLowerCase();
          return extension == '.txt' ||
              extension == '.epub' ||
              extension == '.pdf';
        }
        return false;
      }).toList();

      setState(() {
        _files = supportedFiles;
        _filteredFiles = List.from(supportedFiles);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error loading files: $e';
      });
    }
  }

  // Select a new folder
  Future<void> _selectFolder() async {
    try {
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select Books Folder',
      );

      if (selectedDirectory != null) {
        // Save the selected folder path
        await PrefsHelper.saveSelectedFolder(selectedDirectory);
        // Reload the files
        _loadFiles();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error selecting folder: $e';
      });
    }
  }

  // Get appropriate icon for file type
  IconData _getFileIcon(String filePath) {
    final extension = path.extension(filePath).toLowerCase();

    switch (extension) {
      case '.pdf':
        return Icons.picture_as_pdf;
      case '.epub':
        return Icons.book;
      case '.txt':
        return Icons.description;
      default:
        return Icons.insert_drive_file;
    }
  }

  // Open file based on its type
  void _openFile(String filePath) {
    final fileName = path.basename(filePath);
    final extension = path.extension(filePath).toLowerCase();

    switch (extension) {
      case '.epub':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                EpubReaderScreen(filePath: filePath, fileName: fileName),
          ),
        );
        break;
      case '.pdf':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                PdfReaderScreen(filePath: filePath, fileName: fileName),
          ),
        );
        break;
      case '.txt':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                TxtReaderScreen(filePath: filePath, fileName: fileName),
          ),
        );
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unsupported file type: $extension')),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search books...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withAlpha(153), // 0.6 * 255 = ~153
                  ),
                ),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                onSubmitted: (_) {
                  // Keep the search active after submission
                },
              )
            : const Text('LeafReader'),
        actions: [
          // Search toggle
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  // Clear search when closing
                  _searchController.clear();
                }
              });
            },
            tooltip: _isSearching ? 'Cancel Search' : 'Search',
          ),
          // Toggle view icon
          IconButton(
            icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
            onPressed: () {
              setState(() {
                _isGridView = !_isGridView;
              });
            },
            tooltip: _isGridView ? 'List View' : 'Grid View',
          ),
          // Settings icon
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // Navigate to settings screen
              Navigator.of(
                context,
              ).pushNamed('/settings').then((_) => _loadFiles());
            },
            tooltip: 'Settings',
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: _selectFolder,
        tooltip: 'Change Folder',
        child: const Icon(Icons.folder),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
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
              _errorMessage!,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _selectFolder,
              icon: const Icon(Icons.folder),
              label: const Text('Select Folder'),
            ),
          ],
        ),
      );
    }

    // Show empty state when no files are found
    if (_files.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.library_books,
              size: 60,
              color: Theme.of(
                context,
              ).colorScheme.primary.withAlpha(128), // 0.5 * 255 = ~128
            ),
            const SizedBox(height: 16),
            Text(
              'No books found',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Add TXT, EPUB, or PDF files to the selected folder',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Text(
              'Current folder:',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                _selectedFolderPath ?? 'No folder selected',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }

    // Show a message when search returns no results but there are files in the folder
    if (_filteredFiles.isEmpty && _files.isNotEmpty) {
      return RefreshIndicator(
        onRefresh: _loadFiles,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.3),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.search_off,
                    size: 60,
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withAlpha(128), // 0.5 * 255 = ~128
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No matching books found',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Try a different search term',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      _searchController.clear();
                    },
                    child: const Text('Clear Search'),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Show folder path at the top
    return Column(
      children: [
        // Display current folder path
        Container(
          padding: const EdgeInsets.all(8.0),
          color: Theme.of(context).colorScheme.surfaceContainerHighest
              .withAlpha(77), // 0.3 * 255 = ~77
          width: double.infinity,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Folder: ${_selectedFolderPath ?? "None"}',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_filteredFiles.length != _files.length)
                Text(
                  '${_filteredFiles.length} of ${_files.length} books',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                ),
            ],
          ),
        ),

        // Display files in either list or grid view with pull-to-refresh
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadFiles,
            child: _isGridView ? _buildGridView() : _buildListView(),
          ),
        ),
      ],
    );
  }

  // List view of files
  Widget _buildListView() {
    return ListView.builder(
      controller: _scrollController,
      physics:
          const AlwaysScrollableScrollPhysics(), // Enable scrolling even when content doesn't overflow
      padding: const EdgeInsets.all(8),
      itemCount: _filteredFiles.length,
      itemBuilder: (context, index) {
        final file = _filteredFiles[index];
        final fileName = path.basename(file.path);
        final fileExtension = path.extension(file.path).toLowerCase();

        return Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: ListTile(
            leading: Icon(
              _getFileIcon(file.path),
              color: Theme.of(context).colorScheme.primary,
              size: 36,
            ),
            title: Text(
              fileName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              'Type: ${fileExtension.substring(1).toUpperCase()}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            trailing: IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () {
                // TODO: Show file options (Open, Delete, etc.)
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Options for $fileName')),
                );
              },
            ),
            onTap: () {
              _openFile(file.path);
            },
          ),
        );
      },
    );
  }

  // Grid view of files
  Widget _buildGridView() {
    return GridView.builder(
      controller: _scrollController,
      physics:
          const AlwaysScrollableScrollPhysics(), // Enable scrolling even when content doesn't overflow
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, // Display 2 items per row
        childAspectRatio: 0.8, // Height is greater than width
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: _filteredFiles.length,
      itemBuilder: (context, index) {
        final file = _filteredFiles[index];
        final fileName = path.basename(file.path);
        final fileExtension = path.extension(file.path).toLowerCase();

        return Card(
          elevation: 3,
          child: InkWell(
            onTap: () {
              _openFile(file.path);
            },
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  flex: 3,
                  child: Center(
                    child: Icon(
                      _getFileIcon(file.path),
                      color: Theme.of(context).colorScheme.primary,
                      size: 50,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      children: [
                        Text(
                          fileName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          fileExtension.substring(1).toUpperCase(),
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
    );
  }
}
