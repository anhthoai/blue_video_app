import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/theme_service.dart';
import '../../l10n/app_localizations.dart';

class ThemeSelectionScreen extends ConsumerWidget {
  const ThemeSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final currentTheme = ref.watch(themeProvider);

    final List<Map<String, dynamic>> themes = [
      {
        'mode': AppThemeMode.light,
        'name': l10n.lightMode,
        'icon': Icons.light_mode,
      },
      {
        'mode': AppThemeMode.dark,
        'name': l10n.darkMode,
        'icon': Icons.dark_mode,
      },
      {
        'mode': AppThemeMode.system,
        'name': l10n.systemDefault,
        'icon': Icons.settings_suggest,
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.theme),
      ),
      body: ListView.builder(
        itemCount: themes.length,
        itemBuilder: (context, index) {
          final theme = themes[index];
          final isSelected = currentTheme == theme['mode'];
          return ListTile(
            leading: Icon(
              theme['icon'] as IconData,
              size: 28,
              color: isSelected ? Colors.blue : Colors.grey,
            ),
            title: Text(theme['name'] as String),
            trailing:
                isSelected ? const Icon(Icons.check, color: Colors.blue) : null,
            onTap: () {
              ref
                  .read(themeProvider.notifier)
                  .setTheme(theme['mode'] as AppThemeMode);
              context.pop(); // Go back to settings screen
            },
          );
        },
      ),
    );
  }
}
