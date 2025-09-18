import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import '../utils/prefs_helper.dart';
import '../screens/epub_reader_screen.dart';
import '../screens/pdf_reader_screen.dart';
import '../screens/txt_reader_screen.dart';

enum SortOption { name, date, type }

class HomeService with ChangeNotifier {
  List<FileSystemEntity> _files = [];
  List<FileSystemEntity> _filteredFiles = [];
  bool _isLoading = true;
  String? _selectedFolderPath;
  String? _errorMessage;
  final TextEditingController searchController = TextEditingController();

  // Sort settings
  SortOption _sortOption = SortOption.name;
  bool _sortAscending = true;
  
  // Multi-select functionality
  bool _isMultiSelectMode = false;
  final Set<FileSystemEntity> _selectedFiles = {};

  List<FileSystemEntity> get files => _files;
  List<FileSystemEntity> get filteredFiles => _filteredFiles;
  bool get isLoading => _isLoading;
  String? get selectedFolderPath => _selectedFolderPath;
  String? get errorMessage => _errorMessage;
  SortOption get sortOption => _sortOption;
  bool get sortAscending => _sortAscending;
  bool get isMultiSelectMode => _isMultiSelectMode;
  Set<FileSystemEntity> get selectedFiles => _selectedFiles;
  int get selectedCount => _selectedFiles.length;

  HomeService() {
    loadFiles();
    searchController.addListener(_filterFiles);
  }

  @override
  void dispose() {
    searchController.removeListener(_filterFiles);
    searchController.dispose();
    super.dispose();
  }

  void setSortOption(SortOption option) {
    // If selecting the same option, toggle direction
    if (_sortOption == option) {
      _sortAscending = !_sortAscending;
    } else {
      _sortOption = option;
      // Default to ascending for name, descending for date
      _sortAscending = option != SortOption.date;
    }

    _sortFiles();
    notifyListeners();
  }

  void _filterFiles() {
    final query = searchController.text.toLowerCase();
    if (query.isEmpty) {
      _filteredFiles = List.from(_files);
    } else {
      _filteredFiles = _files.where((file) {
        final fileName = path.basename(file.path).toLowerCase();
        return fileName.contains(query);
      }).toList();
    }

    // Apply current sort settings
    _sortFiles();
    notifyListeners();
  }

  void _sortFiles() {
    _filteredFiles.sort((a, b) {
      // Get the info needed for comparison
      final fileNameA = path.basename(a.path);
      final fileNameB = path.basename(b.path);
      final extensionA = path.extension(a.path).toLowerCase();
      final extensionB = path.extension(b.path).toLowerCase();
      final fileA = File(a.path);
      final fileB = File(b.path);

      // Different comparisons based on sort option
      int comparison;
      switch (_sortOption) {
        case SortOption.name:
          comparison = fileNameA.toLowerCase().compareTo(
            fileNameB.toLowerCase(),
          );
          break;
        case SortOption.date:
          comparison = fileB.lastModifiedSync().compareTo(
            fileA.lastModifiedSync(),
          );
          break;
        case SortOption.type:
          // First compare by extension, then by name
          comparison = extensionA.compareTo(extensionB);
          if (comparison == 0) {
            comparison = fileNameA.toLowerCase().compareTo(
              fileNameB.toLowerCase(),
            );
          }
          break;
      }

      // Apply ascending/descending
      return _sortAscending ? comparison : -comparison;
    });
  }

  Future<void> loadFiles() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _selectedFolderPath = await PrefsHelper.getSelectedFolder();

      if (_selectedFolderPath == null) {
        _isLoading = false;
        _errorMessage =
            'No folder selected. Please select a folder containing your books.';
        notifyListeners();
        return;
      }

      final directory = Directory(_selectedFolderPath!);
      if (!await directory.exists()) {
        _isLoading = false;
        _errorMessage =
            'Selected folder does not exist. Please choose another folder.';
        notifyListeners();
        return;
      }

      final List<FileSystemEntity> allFiles = await directory.list().toList();

      final supportedFiles = allFiles.where((file) {
        if (file is File) {
          final extension = path.extension(file.path).toLowerCase();
          return extension == '.txt' ||
              extension == '.epub' ||
              extension == '.pdf';
        }
        return false;
      }).toList();

      _files = supportedFiles;
      _filteredFiles = List.from(supportedFiles);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Error loading files: $e';
      notifyListeners();
    }
  }

  Future<void> selectFolder() async {
    try {
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select Books Folder',
      );

      if (selectedDirectory != null) {
        await PrefsHelper.saveSelectedFolder(selectedDirectory);
        loadFiles();
      }
    } catch (e) {
      _errorMessage = 'Error selecting folder: $e';
      notifyListeners();
    }
  }

  void openFile(BuildContext context, String filePath) {
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

  // Toggle multi-select mode
  void toggleMultiSelectMode() {
    _isMultiSelectMode = !_isMultiSelectMode;
    if (!_isMultiSelectMode) {
      // Clear selection when exiting multi-select mode
      _selectedFiles.clear();
    }
    notifyListeners();
  }
  
  // Toggle file selection
  void toggleFileSelection(FileSystemEntity file) {
    if (_selectedFiles.contains(file)) {
      _selectedFiles.remove(file);
      if (_selectedFiles.isEmpty) {
        // Exit multi-select mode if no files are selected
        _isMultiSelectMode = false;
      }
    } else {
      _selectedFiles.add(file);
    }
    notifyListeners();
  }
  
  // Inverse selection - select all unselected files and deselect all selected files
  void inverseSelection() {
    // Create a set of currently filtered files
    final Set<FileSystemEntity> filteredFilesSet = Set.from(_filteredFiles);
    
    // Create new set for the inverse selection
    final Set<FileSystemEntity> newSelection = {};
    
    // Add all filtered files that aren't currently selected
    for (final file in filteredFilesSet) {
      if (!_selectedFiles.contains(file)) {
        newSelection.add(file);
      }
    }
    
    // Update the selected files with the inverse selection
    _selectedFiles.clear();
    _selectedFiles.addAll(newSelection);
    
    // If nothing is selected after inversion, exit multi-select mode
    if (_selectedFiles.isEmpty) {
      _isMultiSelectMode = false;
    }
    
    notifyListeners();
  }
  
  // Check if a file is selected
  bool isFileSelected(FileSystemEntity file) {
    return _selectedFiles.contains(file);
  }
  
  // Delete selected files
  Future<void> deleteSelectedFiles(BuildContext context) async {
    if (_selectedFiles.isEmpty) return;
    
    final fileCount = _selectedFiles.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Selected Files'),
        content: Text(
          'Are you sure you want to delete $fileCount ${fileCount == 1 ? 'file' : 'files'}? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      int deletedCount = 0;
      
      // Create a copy of the selected files to iterate
      final filesToDelete = Set<FileSystemEntity>.from(_selectedFiles);
      
      for (final file in filesToDelete) {
        try {
          await file.delete();
          _files.remove(file);
          _filteredFiles.remove(file);
          deletedCount++;
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to delete "${path.basename(file.path)}": $e'),
              ),
            );
          }
        }
      }
      
      // Clear selection and exit multi-select mode
      _selectedFiles.clear();
      _isMultiSelectMode = false;
      notifyListeners();

      if (context.mounted && deletedCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted $deletedCount ${deletedCount == 1 ? 'file' : 'files'}.'),
          ),
        );
      }
    }
  }

  Future<void> deleteFile(BuildContext context, FileSystemEntity file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete File'),
        content: Text(
          'Are you sure you want to delete "${path.basename(file.path)}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await file.delete();
        _files.remove(file);
        _filteredFiles.remove(file);
        notifyListeners();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('"${path.basename(file.path)}" has been deleted.'),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error deleting file: $e')));
        }
      }
    }
  }
}
