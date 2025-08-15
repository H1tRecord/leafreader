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
  bool _darkMode = false;
  bool _notifications = true;
  String _fontSizeOption = 'Medium';
  String _themeMode = 'System';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  // Load saved settings
  Future<void> _loadSettings() async {
    final themeMode = await PrefsHelper.getSelectedTheme();

    setState(() {
      _themeMode = themeMode;
      _darkMode = themeMode == 'Dark';
    });
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
          _buildSectionHeader('Display'),
          _buildSwitchTile(
            title: 'Dark Mode',
            subtitle: 'Enable dark theme for the app',
            value: _darkMode,
            onChanged: (value) {
              setState(() {
                _darkMode = value;
                _themeMode = value ? 'Dark' : 'Light';
              });
              // Apply theme change
              Provider.of<ThemeProvider>(
                context,
                listen: false,
              ).setThemeMode(_themeMode);
            },
          ),

          // Theme mode selection
          _buildDropdownTile(
            title: 'Theme Mode',
            value: _themeMode,
            items: const ['System', 'Light', 'Dark'],
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _themeMode = value;
                  _darkMode = value == 'Dark';
                });
                // Apply theme change
                Provider.of<ThemeProvider>(
                  context,
                  listen: false,
                ).setThemeMode(value);
              }
            },
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
          color: Theme.of(context).primaryColor,
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
      activeColor: Theme.of(context).primaryColor,
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
          Text(title, style: const TextStyle(fontSize: 16)),
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
      leading: Icon(icon, color: Theme.of(context).primaryColor),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
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
}
