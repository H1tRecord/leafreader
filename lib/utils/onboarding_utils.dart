import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/onboarding_service.dart';
import '../utils/theme_provider.dart';

const String _logoAssetPath = 'assets/Leaf_Reader_Logo.png';

Widget buildWelcomeStep(BuildContext context) {
  return Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
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
                      ).colorScheme.primary.withAlpha(26),
                      shape: BoxShape.circle,
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        _logoAssetPath,
                        height: 100,
                        width: 100,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          Icons.menu_book,
                          size: 72,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 32),
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
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
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
                      ).colorScheme.primary.withAlpha(51),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).shadowColor.withAlpha(26),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      buildFeatureItem(
                        context,
                        Icons.library_books,
                        'Organize your entire book collection',
                      ),
                      const Divider(),
                      buildFeatureItem(
                        context,
                        Icons.colorize,
                        'Customize reading experience',
                      ),
                      const Divider(),
                      buildFeatureItem(
                        context,
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

Widget buildFeatureItem(BuildContext context, IconData icon, String text) {
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

Widget buildPermissionsStep(BuildContext context, OnboardingService service) {
  return Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: FutureBuilder<PermissionStatus>(
        future: service.checkStoragePermission(),
        builder: (context, snapshot) {
          bool isPermissionGranted = snapshot.data == PermissionStatus.granted;
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
                    await service.requestStoragePermissions(
                      context,
                      showDialogs: false,
                    );
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
                    color: Theme.of(context).colorScheme.primary.withAlpha(26),
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

Widget buildFolderSelectionStep(
  BuildContext context,
  OnboardingService service,
) {
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
                    service.selectedFolderPath ?? 'No folder selected',
                    style: Theme.of(context).textTheme.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.folder),
                  onPressed: () => service.selectFolder(context),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

Widget buildThemeSelectionStep(
  BuildContext context,
  OnboardingService service,
) {
  final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
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
        Text('Theme Mode', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),
        buildThemeOption(
          context,
          service,
          themeProvider,
          'System',
          Icons.brightness_auto,
          'Uses your device theme',
        ),
        buildThemeOption(
          context,
          service,
          themeProvider,
          'Light',
          Icons.light_mode,
          'Always use light theme',
        ),
        buildThemeOption(
          context,
          service,
          themeProvider,
          'Dark',
          Icons.dark_mode,
          'Always use dark theme',
        ),
        const SizedBox(height: 24),
        Text('Accent Color', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),
        SizedBox(
          height: 120,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              buildThemeCard(
                context,
                service,
                themeProvider,
                'Green',
                Colors.green,
              ),
              buildThemeCard(
                context,
                service,
                themeProvider,
                'Blue',
                Colors.blue,
              ),
              buildThemeCard(
                context,
                service,
                themeProvider,
                'Purple',
                Colors.purple,
              ),
              buildThemeCard(
                context,
                service,
                themeProvider,
                'Orange',
                Colors.orange,
              ),
              buildThemeCard(
                context,
                service,
                themeProvider,
                'Red',
                Colors.red,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget buildThemeOption(
  BuildContext context,
  OnboardingService service,
  ThemeProvider themeProvider,
  String name,
  IconData icon,
  String description,
) {
  final isSelected = service.selectedThemeMode == name;
  return InkWell(
    onTap: () => service.setSelectedThemeMode(name, themeProvider),
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
            ? Theme.of(context).colorScheme.primary.withAlpha(26)
            : null,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurface,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: Theme.of(context).textTheme.titleMedium),
                Text(description, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

Widget buildThemeCard(
  BuildContext context,
  OnboardingService service,
  ThemeProvider themeProvider,
  String name,
  Color color,
) {
  final isSelected = service.selectedAccentColor == name;
  return GestureDetector(
    onTap: () => service.setSelectedAccentColor(name, themeProvider),
    child: Container(
      width: 100,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: isSelected
            ? Border.all(
                color: Theme.of(context).colorScheme.onSurface,
                width: 3,
              )
            : null,
      ),
      child: isSelected
          ? const Icon(Icons.check, color: Colors.white, size: 40)
          : null,
    ),
  );
}

Widget buildTutorialStep(BuildContext context) {
  return Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.school,
            size: 80,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 32),
          Text(
            'You\'re All Set!',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'You can change these settings anytime from the settings menu.',
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

void showLoadingDialog(BuildContext context, String message) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      content: Row(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(width: 16),
          Text(message),
        ],
      ),
    ),
  );
}
