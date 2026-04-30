import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/services/nsfw_settings_service.dart';
import '../../l10n/app_localizations.dart';
import 'privacy_policy_screen.dart';

class PrivacySettingsScreen extends ConsumerWidget {
  const PrivacySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final nsfwSettings = ref.watch(nsfwSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.privacySecurity),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.privacySecurity,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.privacySecuritySubtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 1,
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.explicit, color: Colors.orange),
                  title: Text(l10n.showNsfwContent),
                  subtitle: Text(
                    nsfwSettings.isNsfwViewingEnabled
                        ? l10n.nsfwContentVisible
                        : l10n.nsfwContentBlurred,
                  ),
                  value: nsfwSettings.isNsfwViewingEnabled,
                  onChanged: (value) async {
                    await _toggleNsfwPreference(
                      context,
                      ref,
                      l10n,
                      enabled: value,
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.policy_outlined),
                  title: Text(l10n.privacyPolicy),
                  subtitle: Text(l10n.privacyPolicySubtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openPrivacyPolicy(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.settings_outlined),
                  title: Text(l10n.openSystemSettings),
                  subtitle: Text(l10n.privacySecuritySubtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openSystemSettings(context, l10n),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleNsfwPreference(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n, {
    required bool enabled,
  }) async {
    final nsfwSettings = ref.read(nsfwSettingsProvider);
    final notifier = ref.read(nsfwSettingsProvider.notifier);

    if (!enabled) {
      await notifier.disableNsfwViewing();
      return;
    }

    if (!nsfwSettings.isAgeConfirmed) {
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Text(l10n.ageConfirmationRequired),
          content: Text(l10n.ageConfirmationMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
              ),
              child: Text(l10n.iAm18Plus),
            ),
          ],
        ),
      );

      if (confirmed != true) {
        return;
      }

      await notifier.confirmAge();
    }

    await notifier.enableNsfwViewing();
  }

  Future<void> _openPrivacyPolicy(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const PrivacyPolicyScreen(),
      ),
    );
  }

  Future<void> _openSystemSettings(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    final opened = await openAppSettings();
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.openSystemSettingsFailed)),
      );
    }
  }
}