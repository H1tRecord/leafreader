import 'package:flutter/material.dart';

import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:logging/logging.dart';
import '../utils/prefs_helper.dart';
import '../utils/theme_provider.dart';

enum OnboardingStep {
  welcome,
  permissions,
  folderSelection,
  themeSelection,
  tutorial,
}

final _logger = Logger('OnboardingService');

class OnboardingService with ChangeNotifier {
  OnboardingStep _currentStep = OnboardingStep.welcome;
  String _selectedThemeMode = 'System';
  String _selectedAccentColor = 'Green';
  String? _selectedFolderPath;
  final PageController pageController = PageController();

  OnboardingStep get currentStep => _currentStep;
  String get selectedThemeMode => _selectedThemeMode;
  String get selectedAccentColor => _selectedAccentColor;
  String? get selectedFolderPath => _selectedFolderPath;

  void init(ThemeProvider themeProvider) {
    _selectedThemeMode = themeProvider.themeModeString;
    _selectedAccentColor = themeProvider.accentColorString;
    notifyListeners();
  }

  void nextStep() {
    if (_currentStep.index < OnboardingStep.values.length - 1) {
      _currentStep = OnboardingStep.values[_currentStep.index + 1];
      pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      notifyListeners();
    }
  }

  void previousStep() {
    if (_currentStep.index > 0) {
      _currentStep = OnboardingStep.values[_currentStep.index - 1];
      pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      notifyListeners();
    }
  }

  String getButtonText() {
    switch (_currentStep) {
      case OnboardingStep.welcome:
        return 'Get Started';
      case OnboardingStep.permissions:
        return 'Continue';
      case OnboardingStep.folderSelection:
        return 'Next';
      case OnboardingStep.themeSelection:
        return 'Continue';
      case OnboardingStep.tutorial:
        return 'Finish';
    }
  }

  Future<void> skipOnboarding(BuildContext context) async {
    await PrefsHelper.setOnboardingCompleted();
    await PrefsHelper.saveSelectedTheme('System');
    await PrefsHelper.saveAccentColor('Green');
    if (context.mounted) {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  Future<void> completeOnboarding(BuildContext context) async {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    await PrefsHelper.setOnboardingCompleted();
    await themeProvider.setThemeMode(_selectedThemeMode);
    await themeProvider.setAccentColor(_selectedAccentColor);
    if (_selectedFolderPath != null) {
      await PrefsHelper.saveSelectedFolder(_selectedFolderPath!);
    }
    if (context.mounted) {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  Future<PermissionStatus> checkStoragePermission() async {
    PermissionStatus storageStatus = await Permission.storage.status;
    PermissionStatus? manageStatus;
    try {
      manageStatus = await Permission.manageExternalStorage.status;
    } catch (e) {
      _logger.warning("Error checking manageExternalStorage: $e");
    }
    if (storageStatus.isGranted || (manageStatus?.isGranted ?? false)) {
      return PermissionStatus.granted;
    }
    return storageStatus;
  }

  Future<void> requestStoragePermissions(
    BuildContext context, {
    bool showDialogs = true,
  }) async {
    try {
      await Permission.manageExternalStorage.request();
    } catch (e) {
      _logger.warning("Error requesting manageExternalStorage: $e");
    }
    PermissionStatus status = await Permission.storage.request();
    if (!status.isGranted) {
      status = await Permission.storage.request();
    }
    notifyListeners();

    if (status.isGranted) {
      nextStep();
    } else if (showDialogs && status.isPermanentlyDenied && context.mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Storage Permission Required'),
          content: const Text(
            'Storage permission is needed for LeafReader to access your books. Please enable it in app settings.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                openAppSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );
    } else if (showDialogs && context.mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Permission Required'),
          content: const Text(
            'Storage permission is required for LeafReader to access your books.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
            TextButton(
              onPressed: () => requestStoragePermissions(context),
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> selectFolder(BuildContext context) async {
    try {
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select Books Folder',
      );
      if (selectedDirectory != null) {
        _selectedFolderPath = selectedDirectory;
        notifyListeners();
      }
    } catch (e) {
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Folder Selection Error'),
            content: Text('Error selecting folder: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  selectFolder(context);
                },
                child: const Text('Try Again'),
              ),
            ],
          ),
        );
      }
    }
  }

  void setSelectedThemeMode(String mode, ThemeProvider themeProvider) {
    _selectedThemeMode = mode;
    themeProvider.setThemeMode(mode);
    notifyListeners();
  }

  void setSelectedAccentColor(String color, ThemeProvider themeProvider) {
    _selectedAccentColor = color;
    themeProvider.setAccentColor(color);
    notifyListeners();
  }

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
  }
}
