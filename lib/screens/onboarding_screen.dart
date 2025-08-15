import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../utils/prefs_helper.dart';
import '../utils/theme_provider.dart';

// Enum to track onboarding steps
enum OnboardingStep { welcome, permissions, folderSelection, themeSelection }

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
    if (_currentStep == OnboardingStep.themeSelection) {
      _completeOnboarding();
      return;
    }

    setState(() {
      _currentStep = OnboardingStep.values[_currentStep.index + 1];
    });
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  // Skip onboarding and go to home
  Future<void> _skipOnboarding() async {
    // Save that onboarding was completed with default values
    await PrefsHelper.setOnboardingCompleted();
    await PrefsHelper.saveSelectedTheme('System');
    await PrefsHelper.saveAccentColor('Green');

    // No folder is selected in skip case, app will ask for it later if needed

    Navigator.of(context).pushReplacementNamed('/home');
  }

  // Complete onboarding and save preferences
  Future<void> _completeOnboarding() async {
    // Save all selected preferences
    await PrefsHelper.setOnboardingCompleted();

    // Ensure both theme mode and accent color are saved
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    // Apply and save theme mode
    await themeProvider.setThemeMode(_selectedThemeMode);

    // Apply and save accent color
    await themeProvider.setAccentColor(_selectedAccentColor);

    // Save folder path if selected
    if (_selectedFolderPath != null) {
      await PrefsHelper.saveSelectedFolder(_selectedFolderPath!);
    }

    Navigator.of(context).pushReplacementNamed('/home');
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

  Future<void> _requestStoragePermissions() async {
    // For Android 11+ (API level 30+)
    try {
      // Try the MANAGE_EXTERNAL_STORAGE permission for Android 11+
      await Permission.manageExternalStorage.request();
    } catch (e) {
      print("Error requesting manageExternalStorage: $e");
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
    } else if (status.isPermanentlyDenied) {
      // Show a dialog explaining that the permission is required and
      // direct the user to app settings
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
    } else {
      // Permission denied but not permanently
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Storage permission is required to use this app'),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error selecting folder: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextButton(
                  onPressed: _skipOnboarding,
                  child: const Text('Skip'),
                ),
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

            // Main content area
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildWelcomeStep(),
                  _buildPermissionsStep(),
                  _buildFolderSelectionStep(),
                  _buildThemeSelectionStep(),
                ],
              ),
            ),

            // Next/Continue button
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () async {
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
                          // Show loading indicator while requesting permission
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Requesting storage permission...'),
                              duration: Duration(seconds: 1),
                            ),
                          );

                          // Request permissions - this should show the popup
                          await _requestStoragePermissions();

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
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please select a folder'),
                            ),
                          );
                        }
                        break;
                      case OnboardingStep.themeSelection:
                        _completeOnboarding();
                        break;
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    _currentStep == OnboardingStep.themeSelection
                        ? 'Get Started'
                        : 'Continue',
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Welcome step
  Widget _buildWelcomeStep() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.menu_book,
              size: 100,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 32),
            Text(
              'Welcome to LeafReader',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Your digital bookshelf for all your reading needs',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Text(
              'Let\'s set up your reading experience in a few simple steps',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
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

                      // Request permissions and explicitly trigger the popup
                      await _requestStoragePermissions();

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
                      ).colorScheme.primary.withOpacity(0.1),
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
              ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
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
          color: color.withOpacity(0.8),
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
              color: Theme.of(context).shadowColor.withOpacity(0.2),
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
