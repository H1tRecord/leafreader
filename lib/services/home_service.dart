import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import '../utils/prefs_helper.dart';
import '../screens/epub_reader_screen.dart';
import '../screens/pdf_reader_screen.dart';
import '../screens/txt_reader_screen.dart';

class HomeService with ChangeNotifier {
  List<FileSystemEntity> _files = [];
  List<FileSystemEntity> _filteredFiles = [];
  bool _isLoading = true;
  String? _selectedFolderPath;
  String? _errorMessage;
  final TextEditingController searchController = TextEditingController();

  List<FileSystemEntity> get files => _files;
  List<FileSystemEntity> get filteredFiles => _filteredFiles;
  bool get isLoading => _isLoading;
  String? get selectedFolderPath => _selectedFolderPath;
  String? get errorMessage => _errorMessage;

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
    notifyListeners();
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
