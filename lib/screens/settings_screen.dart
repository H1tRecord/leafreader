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
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          buildSettingsCard(
            context: context,
            title: 'Appearance',
            leadingIcon: Icons.palette,
            children: [
              Consumer<ThemeProvider>(
                builder: (context, themeProvider, _) {
                  return buildDropdownTile(
                    context: context,
                    title: 'Theme Mode',
                    value: themeProvider.themeModeString,
                    items: const ['System', 'Light', 'Dark'],
                    onChanged: (value) {
                      if (value != null) {
                        themeProvider.setThemeMode(value);
                      }
                    },
                  );
                },
              ),
              const SizedBox(height: 16),
              Text(
                'Accent Color',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Consumer<ThemeProvider>(
                builder: (context, themeProvider, _) {
                  return SizedBox(
                    height: 64,
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
          const SizedBox(height: 20),
          buildSettingsCard(
            context: context,
            title: 'About',
            leadingIcon: Icons.info_outline,
            children: [
              buildStaticInfoTile(
                context: context,
                title: 'LeafReader',
                subtitle: 'Version 0.1.0',
                icon: Icons.apps,
              ),
              const Divider(height: 24),
              Text(
                'Project Team',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              _buildTeamMemberRow('Kenneth James Aninipot'),
              const SizedBox(height: 8),
              _buildTeamMemberRow('John Dio Marigundon'),
              const SizedBox(height: 8),
              _buildTeamMemberRow('Aaron Teston'),
              const SizedBox(height: 16),
              buildListTile(
                context: context,
                title: 'Help & Feedback',
                subtitle: 'Get help or share your thoughts',
                icon: Icons.help_outline,
                onTap: () {
                  _settingsService.showHelpAndFeedback(context);
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          buildSettingsCard(
            context: context,
            title: 'Reading Settings',
            leadingIcon: Icons.menu_book_outlined,
            children: [
              buildListTile(
                context: context,
                title: 'EPUB Reader',
                subtitle: 'Fonts, spacing, and appearance',
                icon: Icons.book,
                onTap: () {
                  _settingsService.showEpubReaderSettings(context);
                },
              ),
              buildListTile(
                context: context,
                title: 'Text Reader',
                subtitle: 'Customize plain text experience',
                icon: Icons.text_fields,
                onTap: () {
                  _settingsService.showTextReaderSettings(context);
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          buildSettingsCard(
            context: context,
            title: 'Developer Options',
            leadingIcon: Icons.build_circle_outlined,
            accentColor: Theme.of(context).colorScheme.tertiary,
            children: [
              buildListTile(
                context: context,
                title: 'Reset Onboarding',
                subtitle: 'Show onboarding screens on next launch',
                icon: Icons.refresh,
                onTap: () {
                  _settingsService.showResetOnboardingConfirmation(context);
                },
              ),
              buildListTile(
                context: context,
                title: 'Reset All Settings',
                subtitle: 'Restore defaults and theme selections',
                icon: Icons.restart_alt,
                onTap: () {
                  _settingsService.showResetAllSettingsConfirmation(context);
                },
              ),
              buildListTile(
                context: context,
                title: 'Reset Permissions',
                subtitle: 'Re-run platform permission prompts',
                icon: Icons.security,
                onTap: () {
                  _settingsService.showResetPermissionsConfirmation(context);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTeamMemberRow(String name) {
    return Row(
      children: [
        Icon(
          Icons.person,
          size: 18,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(name, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    );
  }
}
