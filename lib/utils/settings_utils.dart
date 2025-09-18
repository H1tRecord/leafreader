import 'package:flutter/material.dart';
import '../utils/theme_provider.dart';

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
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 16),
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
