import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../utils/prefs_helper.dart';
import '../utils/theme_provider.dart';

class SettingsService {
  static const List<String> _sharedFontOptions = <String>[
    'Default',
    'Serif',
    'Sans-serif',
    'Monospace',
    'Times New Roman',
    'Courier New',
  ];

  String _ensureValidFontSelection(String value) {
    return _sharedFontOptions.contains(value) ? value : 'Default';
  }

  ({String? fontFamily, List<String>? fallback}) _resolveSettingsFont(
    String selection,
  ) {
    switch (selection) {
      case 'Serif':
      case 'Times New Roman':
        return (fontFamily: 'Times New Roman', fallback: const ['serif']);
      case 'Sans-serif':
        return (
          fontFamily: 'sans-serif',
          fallback: const ['Arial', 'sans-serif'],
        );
      case 'Monospace':
        return (
          fontFamily: 'monospace',
          fallback: const ['Courier New', 'monospace'],
        );
      case 'Courier New':
        return (fontFamily: 'Courier New', fallback: const ['monospace']);
      default:
        return (fontFamily: null, fallback: null);
    }
  }

  TextStyle _settingsPreviewStyle(BuildContext context, String selection) {
    final base = Theme.of(context).textTheme.bodyMedium;
    final resolved = _resolveSettingsFont(selection);
    return TextStyle(
      fontSize: base?.fontSize,
      fontWeight: base?.fontWeight,
      color: Theme.of(context).colorScheme.onSurface,
      fontFamily: resolved.fontFamily,
      fontFamilyFallback: resolved.fallback,
    );
  }

  // Show confirmation dialog before resetting onboarding
  void showResetOnboardingConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Onboarding?'),
        content: const Text(
          'This will reset the onboarding process. The next time you launch the app, '
          'you will see the onboarding screens again. This is meant for debugging purposes only.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              // Reset the onboarding completion status
              await PrefsHelper.resetOnboarding();

              // Close the dialog
              if (!context.mounted) return;
              Navigator.of(context).pop();

              // Show confirmation dialog instead of snackbar
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Onboarding Reset'),
                  content: const Text(
                    'Onboarding has been reset successfully. Restart the app to see the onboarding screens.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  // Show confirmation dialog before resetting all settings
  void showResetAllSettingsConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset All Settings?'),
        content: const Text(
          'This will reset all app settings to their default values. '
          'The next time you launch the app, you will see the onboarding screens again. '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              // Reset all app settings
              await PrefsHelper.resetAllSettings();

              // Reset theme to system default
              if (context.mounted) {
                Provider.of<ThemeProvider>(
                  context,
                  listen: false,
                ).setThemeMode('System');
                Provider.of<ThemeProvider>(
                  context,
                  listen: false,
                ).setAccentColor('Green');
              }

              // Close the dialog
              if (!context.mounted) return;
              Navigator.of(context).pop();

              // Show confirmation dialog instead of snackbar
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Settings Reset Complete'),
                  content: const Text(
                    'All settings have been reset to defaults. Restart the app to see changes.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            },
            child: const Text('Reset All'),
          ),
        ],
      ),
    );
  }

  // Show EPUB reader settings dialog
  void showEpubReaderSettings(BuildContext context) async {
    double epubFontSize = await PrefsHelper.getEpubFontSize();
    String epubFontFamily = _ensureValidFontSelection(
      await PrefsHelper.getEpubFontFamily(),
    );

    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
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
                            'EPUB Reader Settings',
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
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Font Size: ${epubFontSize.toStringAsFixed(1)}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Slider(
                            value: epubFontSize,
                            min: 10.0,
                            max: 30.0,
                            divisions: 20,
                            label: epubFontSize.toStringAsFixed(1),
                            onChanged: (value) {
                              setModalState(() {
                                epubFontSize = value;
                              });
                            },
                            onChangeEnd: (value) {
                              PrefsHelper.saveEpubFontSize(value);
                            },
                          ),
                        ],
                      ),
                    ),
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
                            value: epubFontFamily,
                            items: _sharedFontOptions
                                .map(
                                  (family) => DropdownMenuItem(
                                    value: family,
                                    child: Text(
                                      family,
                                      style: _settingsPreviewStyle(
                                        context,
                                        family,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setModalState(() {
                                  epubFontFamily = value;
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
                          if (Platform.isAndroid)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                'Some fonts rely on device support. If a selection looks the same, the font is not available on this device.',
                                style: Theme.of(context).textTheme.bodySmall,
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
    );
  }

  // Show Text reader settings dialog
  void showTextReaderSettings(BuildContext context) async {
    double textFontSize = await PrefsHelper.getTextFontSize();
    String textFontFamily = _ensureValidFontSelection(
      await PrefsHelper.getTextFontFamily(),
    );

    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
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
                            'Text Reader Settings',
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
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Font Size: ${textFontSize.toStringAsFixed(1)}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Slider(
                            value: textFontSize,
                            min: 8.0,
                            max: 32.0,
                            divisions: 24,
                            label: textFontSize.toStringAsFixed(1),
                            onChanged: (value) {
                              setModalState(() {
                                textFontSize = value;
                              });
                            },
                            onChangeEnd: (value) {
                              PrefsHelper.saveTextFontSize(value);
                            },
                          ),
                        ],
                      ),
                    ),
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
                            value: textFontFamily,
                            items: _sharedFontOptions
                                .map(
                                  (family) => DropdownMenuItem(
                                    value: family,
                                    child: Text(
                                      family,
                                      style: _settingsPreviewStyle(
                                        context,
                                        family,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setModalState(() {
                                  textFontFamily = value;
                                });
                                PrefsHelper.saveTextFontFamily(value);
                              }
                            },
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                            ),
                          ),
                          if (Platform.isAndroid)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                'Some fonts rely on device support. If a selection looks the same, the font is not available on this device.',
                                style: Theme.of(context).textTheme.bodySmall,
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
    );
  }

  // Show confirmation dialog before resetting permissions
  void showResetPermissionsConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Permissions?'),
        content: const Text(
          'This will reset all app permissions. You\'ll need to grant permissions again '
          'the next time they\'re required. This is useful if you\'re experiencing permission issues.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              // Open app settings to let user manually reset permissions
              await openAppSettings();

              // Close the dialog
              if (!context.mounted) return;
              Navigator.of(context).pop();

              // Show confirmation dialog with instructions
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Reset Permissions'),
                  content: const Text(
                    'The app settings page has been opened. To reset permissions:\n\n'
                    '1. Find LeafReader in the list\n'
                    '2. Tap on Permissions\n'
                    '3. Disable and re-enable storage permissions',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void showHelpAndFeedback(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Help & Feedback',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'We would love to hear from you. For questions, bug reports, or suggestions, reach out via:',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.email_outlined),
                  title: const Text('Support Email'),
                  subtitle: const Text('support@leafreader.app'),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.chat_bubble_outline),
                  title: const Text('Community Channel'),
                  subtitle: const Text('Join the LeafReader discussion group'),
                ),
                const SizedBox(height: 12),
                Text(
                  'We typically respond within two business days.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).hintColor,
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
