import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/locale_service.dart';
import '../../l10n/app_localizations.dart';

class LanguageSelectionScreen extends ConsumerWidget {
  const LanguageSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLocale = ref.watch(localeProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.selectLanguage),
        backgroundColor: Colors.blue[50],
      ),
      body: ListView(
        children: [
          _buildLanguageTile(
            context,
            ref,
            title: l10n.english,
            subtitle: 'English',
            locale: const Locale('en'),
            currentLocale: currentLocale,
            icon: '🇺🇸',
          ),
          const Divider(height: 1),
          _buildLanguageTile(
            context,
            ref,
            title: l10n.chinese,
            subtitle: '中文',
            locale: const Locale('zh'),
            currentLocale: currentLocale,
            icon: '🇨🇳',
          ),
          const Divider(height: 1),
          _buildLanguageTile(
            context,
            ref,
            title: l10n.japanese,
            subtitle: '日本語',
            locale: const Locale('ja'),
            currentLocale: currentLocale,
            icon: '🇯🇵',
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageTile(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required String subtitle,
    required Locale locale,
    required Locale currentLocale,
    required String icon,
  }) {
    final isSelected = locale.languageCode == currentLocale.languageCode;

    return ListTile(
      leading: Text(
        icon,
        style: const TextStyle(fontSize: 32),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle: Text(subtitle),
      trailing: isSelected
          ? const Icon(Icons.check_circle, color: Colors.blue)
          : null,
      onTap: () async {
        await ref.read(localeProvider.notifier).setLocale(locale);
        if (context.mounted) {
          // Show a snackbar to confirm
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Language changed to $subtitle'),
              duration: const Duration(seconds: 2),
            ),
          );
          // Go back to settings
          context.pop();
        }
      },
    );
  }
}

