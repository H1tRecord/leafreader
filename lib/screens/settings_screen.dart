import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/prefs_helper.dart';
import '../utils/theme_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Settings
  bool _notifications = true;
  String _fontSizeOption = 'Medium';

  // We'll get theme mode directly from provider instead of maintaining separate state

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  // Load saved settings
  Future<void> _loadSettings() async {
    // We'll get theme settings directly from the provider when needed
    // This is just for other settings that might be added later
  }

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
          _buildSectionHeader('Appearance'),

          // Theme mode selection
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, _) {
              return _buildDropdownTile(
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
                          _buildAccentColorCard(
                            'Green',
                            Colors.green,
                            themeProvider,
                          ),
                          _buildAccentColorCard(
                            'Blue',
                            Colors.blue,
                            themeProvider,
                          ),
                          _buildAccentColorCard(
                            'Purple',
                            Colors.purple,
                            themeProvider,
                          ),
                          _buildAccentColorCard(
                            'Orange',
                            Colors.orange,
                            themeProvider,
                          ),
                          _buildAccentColorCard(
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

          _buildDropdownTile(
            title: 'Font Size',
            value: _fontSizeOption,
            items: const ['Small', 'Medium', 'Large', 'Extra Large'],
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _fontSizeOption = value;
                });
                // TODO: Implement font size change
              }
            },
          ),

          _buildSectionHeader('Notifications'),
          _buildSwitchTile(
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

          _buildSectionHeader('Account'),
          _buildListTile(
            title: 'Profile',
            subtitle: 'Edit your profile information',
            icon: Icons.person,
            onTap: () {
              // TODO: Navigate to profile page
            },
          ),

          _buildListTile(
            title: 'Privacy',
            subtitle: 'Manage your privacy settings',
            icon: Icons.privacy_tip,
            onTap: () {
              // TODO: Navigate to privacy settings
            },
          ),

          _buildSectionHeader('About'),
          _buildListTile(
            title: 'About LeafReader',
            subtitle: 'Learn more about the app',
            icon: Icons.info_outline,
            onTap: () {
              // TODO: Show about dialog
            },
          ),

          _buildListTile(
            title: 'Help & Feedback',
            subtitle: 'Get help or send feedback',
            icon: Icons.help_outline,
            onTap: () {
              // TODO: Navigate to help page
            },
          ),

          _buildSectionHeader('Developer Options'),
          _buildListTile(
            title: 'Reset Onboarding',
            subtitle: 'Restart the onboarding process on next app launch',
            icon: Icons.refresh,
            onTap: () {
              _showResetOnboardingConfirmation();
            },
          ),
          _buildListTile(
            title: 'Reset All Settings',
            subtitle: 'Reset all app settings to default values',
            icon: Icons.restart_alt,
            onTap: () {
              _showResetAllSettingsConfirmation();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
      activeColor: Theme.of(context).colorScheme.primary,
    );
  }

  Widget _buildDropdownTile({
    required String title,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(fontSize: 16),
          ),
          DropdownButton<String>(
            value: value,
            items: items
                .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                .toList(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildListTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[400]
            : Colors.grey[600],
      ),
      onTap: onTap,
    );
  }

  // Show confirmation dialog before resetting onboarding
  void _showResetOnboardingConfirmation() {
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

              // Show confirmation
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Onboarding reset successful. Restart the app to see onboarding.',
                  ),
                  duration: Duration(seconds: 4),
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
  void _showResetAllSettingsConfirmation() {
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

              // Close the dialog
              if (!context.mounted) return;
              Navigator.of(context).pop();

              // Show confirmation
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'All settings have been reset to defaults. Restart the app to see changes.',
                  ),
                  duration: Duration(seconds: 4),
                ),
              );
            },
            child: const Text('Reset All'),
          ),
        ],
      ),
    );
  }

  // Build an accent color selection card
  Widget _buildAccentColorCard(
    String name,
    Color color,
    ThemeProvider themeProvider,
  ) {
    final bool isSelected = themeProvider.accentColorString == name;

    return GestureDetector(
      onTap: () {
        // Apply accent color change immediately
        themeProvider.setAccentColor(name);
      },
      child: Container(
        width: 80,
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
              const Icon(Icons.check_circle, color: Colors.white, size: 18),
            Text(
              name,
              style: const TextStyle(
                color: Colors
                    .white, // Keep white for contrast on colored backgrounds
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
