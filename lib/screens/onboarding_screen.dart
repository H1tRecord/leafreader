import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For HapticFeedback
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:logging/logging.dart';
import '../utils/prefs_helper.dart';
import '../utils/theme_provider.dart';

// Enum to track onboarding steps
enum OnboardingStep {
  welcome,
  permissions,
  folderSelection,
  themeSelection,
  tutorial,
}

// Logger for this class
final _logger = Logger('OnboardingScreen');

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  // Current step in the onboarding process
  OnboardingStep _currentStep = OnboardingStep.welcome;

  // Selected theme mode (System/Light/Dark)
  String _selectedThemeMode = 'System';

  // Selected accent color
  String _selectedAccentColor = 'Green';

  // Selected folder path
  String? _selectedFolderPath;

  // Page controller for the step pages
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();

    // Initialize theme values from the provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
      setState(() {
        _selectedThemeMode = themeProvider.themeModeString;
        _selectedAccentColor = themeProvider.accentColorString;
      });
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // Navigate to the next step
  void _nextStep() {
    setState(() {
      _currentStep = OnboardingStep.values[_currentStep.index + 1];
    });
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  // Navigate to the previous step
  void _previousStep() {
    setState(() {
      _currentStep = OnboardingStep.values[_currentStep.index - 1];
    });
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  // Get the button text based on the current step
  String _getButtonText() {
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

  // Skip onboarding and go to home
  Future<void> _skipOnboarding() async {
    // Save that onboarding was completed with default values
    await PrefsHelper.setOnboardingCompleted();
    await PrefsHelper.saveSelectedTheme('System');
    await PrefsHelper.saveAccentColor('Green');

    // No folder is selected in skip case, app will ask for it later if needed

    // Check if the widget is still mounted before using context
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  // Complete onboarding and save preferences
  Future<void> _completeOnboarding() async {
    // Get theme provider before any async operations
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    // Get a local copy of the path
    final selectedPath = _selectedFolderPath;

    // Save all selected preferences
    await PrefsHelper.setOnboardingCompleted();

    // Apply and save theme mode
    await themeProvider.setThemeMode(_selectedThemeMode);

    // Apply and save accent color
    await themeProvider.setAccentColor(_selectedAccentColor);

    // Save folder path if selected
    if (selectedPath != null) {
      await PrefsHelper.saveSelectedFolder(selectedPath);
    }

    // Check if widget is still mounted before navigating
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  } // Request storage permissions

  // Check current storage permission status
  Future<PermissionStatus> _checkStoragePermission() async {
    // First check for regular storage permission
    PermissionStatus storageStatus = await Permission.storage.status;

    // For Android 11 (API level 30) and above, also check manage external storage
    PermissionStatus? manageStatus;
    try {
      manageStatus = await Permission.manageExternalStorage.status;
    } catch (e) {
      // This might not be supported on all devices, ignore errors
    }

    // If either permission is granted, we consider it granted
    if (storageStatus.isGranted ||
        (manageStatus != null && manageStatus.isGranted)) {
      return PermissionStatus.granted;
    }

    return storageStatus;
  }

  Future<void> _requestStoragePermissions({bool showDialogs = true}) async {
    // For Android 11+ (API level 30+)
    try {
      // Try the MANAGE_EXTERNAL_STORAGE permission for Android 11+
      await Permission.manageExternalStorage.request();
    } catch (e) {
      _logger.warning("Error requesting manageExternalStorage: $e");
      // Continue anyway as not all devices support this
    }

    // Request the basic storage permission - this should trigger the popup
    PermissionStatus status = await Permission.storage.request();

    // On some devices, may need to request it again to show the popup
    if (!status.isGranted) {
      // Try once more
      status = await Permission.storage.request();
    }

    // Force UI update regardless of result
    setState(() {});

    // Check if permission was granted
    if (status.isGranted) {
      _nextStep();
    } else if (showDialogs && status.isPermanentlyDenied) {
      // Show a dialog explaining that the permission is required and
      // direct the user to app settings - only if showDialogs is true
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Storage Permission Required'),
          content: const Text(
            'Storage permission is needed for LeafReader to access your books. '
            'Please enable it in app settings.',
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
    } else if (showDialogs) {
      // Permission denied but not permanently - show dialog only if showDialogs is true
      if (!mounted) return;
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
              onPressed: () => _requestStoragePermissions(),
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }
  }

  // Select folder
  Future<void> _selectFolder() async {
    try {
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select Books Folder',
      );

      if (selectedDirectory != null) {
        setState(() {
          _selectedFolderPath = selectedDirectory;
        });
      }
    } catch (e) {
      if (!mounted) return;
      // Show dialog instead of snackbar for error
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
                _selectFolder(); // Try again
              },
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top navigation row with skip button and page indicator
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Page indicator with dots
                  Row(
                    children: List.generate(
                      OnboardingStep.values.length,
                      (index) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: index == _currentStep.index
                              ? Theme.of(context).colorScheme.primary
                              : (Theme.of(context).brightness == Brightness.dark
                                    ? Colors.grey[600]
                                    : Colors.grey[300]),
                        ),
                      ),
                    ),
                  ),

                  // Skip button (don't show on the last tutorial step)
                  if (_currentStep != OnboardingStep.tutorial)
                    TextButton(
                      onPressed: _skipOnboarding,
                      child: Text(
                        'Skip',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Progress indicator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: LinearProgressIndicator(
                value: (_currentStep.index + 1) / OnboardingStep.values.length,
                backgroundColor: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[800]
                    : Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.primary,
                ),
              ),
            ),

            // Main content area with animated transitions
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    transitionBuilder:
                        (Widget child, Animation<double> animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: child,
                          );
                        },
                    child: _buildWelcomeStep(),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    transitionBuilder:
                        (Widget child, Animation<double> animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: child,
                          );
                        },
                    child: _buildPermissionsStep(),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    transitionBuilder:
                        (Widget child, Animation<double> animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: child,
                          );
                        },
                    child: _buildFolderSelectionStep(),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    transitionBuilder:
                        (Widget child, Animation<double> animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: child,
                          );
                        },
                    child: _buildThemeSelectionStep(),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    transitionBuilder:
                        (Widget child, Animation<double> animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: child,
                          );
                        },
                    child: _buildTutorialStep(),
                  ),
                ],
              ),
            ),

            // Navigation buttons (Previous and Next/Continue)
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Previous button (hidden on first step)
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 300),
                    opacity: _currentStep == OnboardingStep.welcome ? 0.0 : 1.0,
                    child: SizedBox(
                      width: 120,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _currentStep == OnboardingStep.welcome
                            ? null
                            : () {
                                HapticFeedback.lightImpact();
                                _previousStep();
                              },
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 1,
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          foregroundColor: Theme.of(
                            context,
                          ).colorScheme.onSurfaceVariant,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.arrow_back, size: 18),
                            const SizedBox(width: 8),
                            const Text(
                              'Previous',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Next/Continue button
                  SizedBox(
                    width: 120,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () async {
                        // Add visual feedback animation when button is pressed
                        HapticFeedback.lightImpact();

                        switch (_currentStep) {
                          case OnboardingStep.welcome:
                            _nextStep();
                            break;
                          case OnboardingStep.permissions:
                            // Check if permission is already granted
                            PermissionStatus status =
                                await _checkStoragePermission();
                            if (status.isGranted) {
                              _nextStep(); // If granted, proceed to next step
                            } else {
                              // Show loading popup instead of snackbar
                              _showLoadingDialog(
                                'Requesting storage permissions...',
                              );

                              // Request permissions with dialogs enabled (show alerts)
                              await _requestStoragePermissions(
                                showDialogs: true,
                              );

                              // Close the loading dialog if it's still showing
                              if (mounted && Navigator.of(context).canPop()) {
                                Navigator.of(context).pop();
                              }

                              // Check permission status again after request
                              status = await _checkStoragePermission();
                              if (status.isGranted) {
                                _nextStep(); // If granted, proceed to next step
                              }
                            }
                            break;
                          case OnboardingStep.folderSelection:
                            if (_selectedFolderPath != null) {
                              _nextStep();
                            } else {
                              // Show dialog instead of snackbar
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('No Folder Selected'),
                                  content: const Text(
                                    'Please select a folder to continue.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(),
                                      child: const Text('OK'),
                                    ),
                                  ],
                                ),
                              );
                            }
                            break;
                          case OnboardingStep.themeSelection:
                            _nextStep(); // Move to tutorial step instead of completing
                            break;
                          case OnboardingStep.tutorial:
                            _completeOnboarding(); // Complete onboarding after tutorial
                            break;
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 1,
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        foregroundColor: Theme.of(
                          context,
                        ).colorScheme.onSurfaceVariant,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _getButtonText(),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            _currentStep == OnboardingStep.tutorial
                                ? Icons.check
                                : Icons.arrow_forward,
                            size: 18,
                          ),
                        ],
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
  }

  // Welcome step with animated elements
  Widget _buildWelcomeStep() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo with animation
            TweenAnimationBuilder<double>(
              duration: const Duration(seconds: 1),
              tween: Tween<double>(begin: 0.0, end: 1.0),
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: Opacity(
                    opacity: value,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withAlpha(26), // 0.1 * 255 = ~26
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.menu_book,
                        size: 100,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 32),

            // Title with staggered animation
            TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 800),
              tween: Tween<double>(begin: 0.0, end: 1.0),
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, 20 * (1 - value)),
                    child: Text(
                      'Welcome to LeafReader',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 16),

            // Subtitle with animation
            TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 800),
              tween: Tween<double>(begin: 0.0, end: 1.0),
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Text(
                    'Your digital bookshelf for all your reading needs',
                    style: Theme.of(context).textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                );
              },
            ),

            const SizedBox(height: 24),

            // Feature container
            TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 800),
              tween: Tween<double>(begin: 0.0, end: 1.0),
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withAlpha(51), // 0.2 * 255 = ~51
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(
                            context,
                          ).shadowColor.withAlpha(26), // 0.1 * 255 = ~26
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _buildFeatureItem(
                          Icons.library_books,
                          'Organize your entire book collection',
                        ),
                        const Divider(),
                        _buildFeatureItem(
                          Icons.colorize,
                          'Customize reading experience',
                        ),
                        const Divider(),
                        _buildFeatureItem(
                          Icons.bookmark,
                          'Track reading progress',
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // Helper for welcome screen feature items
  Widget _buildFeatureItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }

  // Permissions step
  Widget _buildPermissionsStep() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: FutureBuilder<PermissionStatus>(
          future: _checkStoragePermission(),
          builder: (context, snapshot) {
            bool isPermissionGranted =
                snapshot.data == PermissionStatus.granted;

            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isPermissionGranted ? Icons.check_circle : Icons.folder_open,
                  size: 80,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 32),
                Text(
                  isPermissionGranted
                      ? 'Storage Access Granted'
                      : 'Storage Access Required',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'LeafReader needs access to your device storage to find and manage your books.',
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Text(
                  'This permission is essential for the app to function properly.',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                if (!isPermissionGranted)
                  ElevatedButton.icon(
                    onPressed: () async {
                      // Show loading indicator
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Requesting storage permission...'),
                          duration: Duration(seconds: 1),
                        ),
                      );

                      // Request permissions without showing dialogs
                      await _requestStoragePermissions(showDialogs: false);

                      // Refresh UI after request
                      setState(() {});
                    },
                    icon: const Icon(Icons.perm_media),
                    label: const Text('Grant Storage Permission'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                if (isPermissionGranted)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withAlpha(26), // 0.1 * 255 = ~26
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Theme.of(context).primaryColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Permission Granted',
                          style: TextStyle(
                            color: Theme.of(context).primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  // Folder selection step
  Widget _buildFolderSelectionStep() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.create_new_folder,
              size: 80,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 32),
            Text(
              'Choose Your Books Folder',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Select a folder where your books are stored or where you want to save them.',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            // Selected folder display
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey[700]!
                      : Colors.grey[300]!,
                ),
                borderRadius: BorderRadius.circular(8),
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[800]
                    : Colors.grey[50],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _selectedFolderPath ?? 'No folder selected',
                      style: Theme.of(context).textTheme.bodyMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.folder),
                    onPressed: _selectFolder,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Theme selection step
  Widget _buildThemeSelectionStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Icon(
              Icons.palette,
              size: 80,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'Personalize Your App',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'Select your preferred appearance for the app.',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 32),

          // Theme mode options (System, Light, Dark)
          Text('Theme Mode', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),

          _buildThemeOption(
            'System',
            Icons.brightness_auto,
            'Uses your device theme',
          ),
          _buildThemeOption(
            'Light',
            Icons.light_mode,
            'Always use light theme',
          ),
          _buildThemeOption('Dark', Icons.dark_mode, 'Always use dark theme'),

          const SizedBox(height: 24),

          // Accent color options
          Text('Accent Color', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),

          // Accent color cards
          SizedBox(
            height: 120,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildThemeCard('Green', Colors.green),
                _buildThemeCard('Blue', Colors.blue),
                _buildThemeCard('Purple', Colors.purple),
                _buildThemeCard('Orange', Colors.orange),
                _buildThemeCard('Red', Colors.red),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Theme option item
  Widget _buildThemeOption(String name, IconData icon, String description) {
    final isSelected = _selectedThemeMode == name;

    return InkWell(
      onTap: () async {
        // Set state locally for UI update
        setState(() {
          _selectedThemeMode = name;
        });
        // Apply theme change immediately for preview
        // Use await to ensure the theme is applied before continuing
        await Provider.of<ThemeProvider>(
          context,
          listen: false,
        ).setThemeMode(name);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).brightness == Brightness.dark
                ? Colors.grey[600]!
                : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withAlpha(
                  26,
                ) // 0.1 * 255 = ~26
              : Theme.of(context).brightness == Brightness.dark
              ? Colors.grey[800]
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey[400]
                  : Colors.grey[600],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).brightness == Brightness.dark
                          ? Colors.white70
                          : Colors.black87,
                    ),
                  ),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: Theme.of(context).colorScheme.primary,
              ),
          ],
        ),
      ),
    );
  }

  // Tutorial step to help users get started
  Widget _buildTutorialStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Icon(
              Icons.school,
              size: 80,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'Getting Started',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'Here\'s a quick tour of LeafReader\'s key features',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 32),

          // Library view tutorial
          _buildTutorialItem(
            title: 'Library',
            description:
                'Browse your book collection sorted by title, author, or recently read',
            icon: Icons.library_books,
          ),

          // Reading view tutorial
          _buildTutorialItem(
            title: 'Reading Experience',
            description:
                'Customize fonts, margins, and colors for comfortable reading',
            icon: Icons.menu_book,
          ),

          // Bookmarks tutorial
          _buildTutorialItem(
            title: 'Bookmarks & Notes',
            description:
                'Save your progress and add notes to important passages',
            icon: Icons.bookmark,
          ),

          // Settings tutorial
          _buildTutorialItem(
            title: 'Settings',
            description:
                'Customize the app to your preferences anytime from the settings menu',
            icon: Icons.settings,
          ),

          const SizedBox(height: 24),

          // Ready to start message
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withAlpha(26), // 0.1 * 255 = ~26
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Theme.of(context).colorScheme.primary),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.celebration,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'You\'re all set! Click Finish to start using LeafReader.',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to build tutorial items with consistent style
  Widget _buildTutorialItem({
    required String title,
    required String description,
    required IconData icon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[800]
            : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey[700]!
              : Colors.grey[300]!,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(
              context,
            ).shadowColor.withAlpha(26), // 0.1 * 255 = ~26
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withAlpha(26), // 0.1 * 255 = ~26
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: Theme.of(context).colorScheme.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Show a loading dialog with custom message
  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text(message),
            ],
          ),
        );
      },
    );

    // Automatically dismiss the dialog after 1.5 seconds
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    });
  }

  // Theme color card
  Widget _buildThemeCard(String name, Color color) {
    final isSelected = _selectedAccentColor == name;

    return GestureDetector(
      onTap: () async {
        setState(() {
          _selectedAccentColor = name;
        });
        // Apply accent color change immediately for preview
        // Use await to ensure the theme is applied before continuing
        await Provider.of<ThemeProvider>(
          context,
          listen: false,
        ).setAccentColor(name);
      },
      child: Container(
        width: 100,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: color.withAlpha(204), // 0.8 * 255 = ~204
          borderRadius: BorderRadius.circular(8),
          border: isSelected
              ? Border.all(color: Colors.white, width: 3)
              : Border.all(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey[700]!
                      : Colors.grey[300]!,
                  width: 1,
                ),
          boxShadow: [
            BoxShadow(
              color: Theme.of(
                context,
              ).shadowColor.withAlpha(51), // 0.2 * 255 = ~51
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isSelected)
              const Icon(Icons.check_circle, color: Colors.white, size: 32),
            Text(
              name,
              style: const TextStyle(
                color: Colors
                    .white, // Keep white for contrast on colored backgrounds
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
