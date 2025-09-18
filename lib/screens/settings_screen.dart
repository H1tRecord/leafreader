import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/settings_service.dart';
import '../utils/settings_utils.dart';
import '../utils/theme_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsService _settingsService = SettingsService();
  bool _notifications = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        children: [
          buildSectionHeader(context, 'Appearance'),

          // Theme mode selection
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, _) {
              return buildDropdownTile(
                context: context,
                title: 'Theme Mode',
                value: themeProvider.themeModeString,
                items: const ['System', 'Light', 'Dark'],
                onChanged: (value) {
                  if (value != null) {
                    // Apply theme change
                    themeProvider.setThemeMode(value);
                  }
                },
              );
            },
          ),

          // Accent color selection
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Accent Color',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontSize: 16),
                ),
                const SizedBox(height: 12),
                Consumer<ThemeProvider>(
                  builder: (context, themeProvider, _) {
                    return SizedBox(
                      height: 60,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          buildAccentColorCard(
                            context,
                            'Green',
                            Colors.green,
                            themeProvider,
                          ),
                          buildAccentColorCard(
                            context,
                            'Blue',
                            Colors.blue,
                            themeProvider,
                          ),
                          buildAccentColorCard(
                            context,
                            'Purple',
                            Colors.purple,
                            themeProvider,
                          ),
                          buildAccentColorCard(
                            context,
                            'Orange',
                            Colors.orange,
                            themeProvider,
                          ),
                          buildAccentColorCard(
                            context,
                            'Red',
                            Colors.red,
                            themeProvider,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          buildSectionHeader(context, 'Notifications'),
          buildSwitchTile(
            context: context,
            title: 'Enable Notifications',
            subtitle: 'Receive app notifications',
            value: _notifications,
            onChanged: (value) {
              setState(() {
                _notifications = value;
              });
              // TODO: Implement notifications toggle
            },
          ),

          buildSectionHeader(context, 'Account'),
          buildListTile(
            context: context,
            title: 'Profile',
            subtitle: 'Edit your profile information',
            icon: Icons.person,
            onTap: () {
              // TODO: Navigate to profile page
            },
          ),

          buildListTile(
            context: context,
            title: 'Privacy',
            subtitle: 'Manage your privacy settings',
            icon: Icons.privacy_tip,
            onTap: () {
              // TODO: Navigate to privacy settings
            },
          ),

          buildSectionHeader(context, 'About'),
          buildListTile(
            context: context,
            title: 'About LeafReader',
            subtitle: 'Learn more about the app',
            icon: Icons.info_outline,
            onTap: () {
              // TODO: Show about dialog
            },
          ),

          buildListTile(
            context: context,
            title: 'Help & Feedback',
            subtitle: 'Get help or send feedback',
            icon: Icons.help_outline,
            onTap: () {
              // TODO: Navigate to help page
            },
          ),

          buildSectionHeader(context, 'Reading Settings'),
          buildListTile(
            context: context,
            title: 'EPUB Reader Settings',
            subtitle: 'Configure font size and style for EPUB files',
            icon: Icons.book,
            onTap: () {
              _settingsService.showEpubReaderSettings(context);
            },
          ),
          buildListTile(
            context: context,
            title: 'Text Reader Settings',
            subtitle: 'Configure font size and style for text files',
            icon: Icons.text_fields,
            onTap: () {
              _settingsService.showTextReaderSettings(context);
            },
          ),

          buildSectionHeader(context, 'Developer Options'),
          buildListTile(
            context: context,
            title: 'Reset Onboarding',
            subtitle: 'Restart the onboarding process on next app launch',
            icon: Icons.refresh,
            onTap: () {
              _settingsService.showResetOnboardingConfirmation(context);
            },
          ),
          buildListTile(
            context: context,
            title: 'Reset All Settings',
            subtitle: 'Reset all app settings to default values',
            icon: Icons.restart_alt,
            onTap: () {
              _settingsService.showResetAllSettingsConfirmation(context);
            },
          ),
          buildListTile(
            context: context,
            title: 'Reset Permissions',
            subtitle: 'Reset app permissions and request them again',
            icon: Icons.security,
            onTap: () {
              _settingsService.showResetPermissionsConfirmation(context);
            },
          ),
        ],
      ),
    );
  }
}
