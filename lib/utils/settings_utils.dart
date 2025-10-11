import 'package:flutter/material.dart';
import '../utils/theme_provider.dart';

Widget buildSettingsCard({
  required BuildContext context,
  required String title,
  required List<Widget> children,
  IconData? leadingIcon,
  Color? accentColor,
}) {
  final theme = Theme.of(context);
  final iconColor = accentColor ?? theme.colorScheme.primary;

  return Card(
    elevation: 2,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (leadingIcon != null)
                CircleAvatar(
                  radius: 20,
                  backgroundColor: iconColor.withOpacity(0.15),
                  child: Icon(leadingIcon, color: iconColor),
                ),
              if (leadingIcon != null) const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    ),
  );
}

Widget buildSectionHeader(BuildContext context, String title) {
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

Widget buildSwitchTile({
  required BuildContext context,
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

Widget buildDropdownTile({
  required BuildContext context,
  required String title,
  required String value,
  required List<String> items,
  required ValueChanged<String?> onChanged,
}) {
  final theme = Theme.of(context);
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 8),
      DropdownButtonFormField<String>(
        value: value,
        items: items
            .map((item) => DropdownMenuItem(value: item, child: Text(item)))
            .toList(),
        onChanged: onChanged,
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    ],
  );
}

Widget buildListTile({
  required BuildContext context,
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

Widget buildStaticInfoTile({
  required BuildContext context,
  required String title,
  required String subtitle,
  required IconData icon,
}) {
  return ListTile(
    leading: CircleAvatar(
      backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.12),
      child: Icon(icon, color: Theme.of(context).colorScheme.primary),
    ),
    title: Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    ),
    subtitle: Text(subtitle),
  );
}

Widget buildAccentColorCard(
  BuildContext context,
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
        color: color.withAlpha(204),
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
            color: Theme.of(context).shadowColor.withAlpha(51),
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
