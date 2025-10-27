import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/nsfw_settings_service.dart';
import '../../core/services/locale_service.dart';
import '../../core/services/theme_service.dart';
import '../../l10n/app_localizations.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final currentLocale = ref.watch(localeProvider);
    final currentTheme = ref.watch(themeProvider);

    String getLanguageName(String languageCode) {
      switch (languageCode) {
        case 'zh':
          return '中文';
        case 'ja':
          return '日本語';
        case 'en':
        default:
          return 'English';
      }
    }

    String getThemeName(AppThemeMode theme) {
      switch (theme) {
        case AppThemeMode.light:
          return l10n.lightMode;
        case AppThemeMode.dark:
          return l10n.darkMode;
        case AppThemeMode.system:
          return l10n.systemDefault;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // App Information Section
          _buildSection(
            context,
            l10n.appInformation,
            [
              _buildListTile(
                context,
                icon: Icons.info_outline,
                title: l10n.appVersion,
                subtitle: '1.0.0 (Test Build)',
                onTap: () {},
              ),
              _buildListTile(
                context,
                icon: Icons.bug_report,
                title: l10n.testInstructions,
                subtitle: l10n.testInstructionsSubtitle,
                onTap: () => context.push('/main/test-instructions'),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Account Section
          _buildSection(
            context,
            l10n.account,
            [
              _buildListTile(
                context,
                icon: Icons.person_outline,
                title: l10n.profileSettings,
                subtitle: l10n.profileSettingsSubtitle,
                onTap: () => context.push('/main/profile/edit'),
              ),
              _buildListTile(
                context,
                icon: Icons.notifications_outlined,
                title: l10n.notifications,
                subtitle: l10n.notificationsSubtitle,
                onTap: () {},
              ),
              _buildListTile(
                context,
                icon: Icons.privacy_tip_outlined,
                title: l10n.privacySecurity,
                subtitle: l10n.privacySecuritySubtitle,
                onTap: () {},
              ),
              _buildNsfwToggle(context, ref, l10n),
            ],
          ),

          const SizedBox(height: 24),

          // App Settings Section
          _buildSection(
            context,
            l10n.appSettings,
            [
              _buildListTile(
                context,
                icon: Icons.dark_mode_outlined,
                title: l10n.theme,
                subtitle: getThemeName(currentTheme),
                onTap: () => context.push('/main/settings/theme'),
              ),
              _buildListTile(
                context,
                icon: Icons.language_outlined,
                title: l10n.language,
                subtitle: getLanguageName(currentLocale.languageCode),
                onTap: () => context.push('/main/settings/language'),
              ),
              _buildListTile(
                context,
                icon: Icons.storage_outlined,
                title: l10n.storage,
                subtitle: l10n.storageSubtitle,
                onTap: () {},
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Support Section
          _buildSection(
            context,
            l10n.support,
            [
              _buildListTile(
                context,
                icon: Icons.help_outline,
                title: l10n.helpSupport,
                subtitle: l10n.helpSupportSubtitle,
                onTap: () {},
              ),
              _buildListTile(
                context,
                icon: Icons.feedback_outlined,
                title: l10n.sendFeedback,
                subtitle: l10n.sendFeedbackSubtitle,
                onTap: () {},
              ),
              _buildListTile(
                context,
                icon: Icons.star_outline,
                title: l10n.rateApp,
                subtitle: l10n.rateAppSubtitle,
                onTap: () {},
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Logout Button
          Center(
            child: ElevatedButton.icon(
              onPressed: () async {
                // Show confirmation dialog
                final shouldLogout = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(l10n.logoutConfirmTitle),
                    content: Text(l10n.logoutConfirmMessage),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(l10n.cancel),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        child: Text(l10n.logout),
                      ),
                    ],
                  ),
                );

                if (shouldLogout == true && context.mounted) {
                  try {
                    final authService = ref.read(authServiceProvider);
                    await authService.signOut();

                    if (context.mounted) {
                      context.go('/auth/login');
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${l10n.logoutFailed}: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                }
              },
              icon: const Icon(Icons.logout),
              label: Text(l10n.logout),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSection(
      BuildContext context, String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        Card(
          elevation: 1,
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildListTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.blue),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  Widget _buildNsfwToggle(
      BuildContext context, WidgetRef ref, AppLocalizations l10n) {
    final nsfwSettings = ref.watch(nsfwSettingsProvider);

    return ListTile(
      leading: const Icon(Icons.explicit, color: Colors.orange),
      title: Text(l10n.showNsfwContent),
      subtitle: Text(
        nsfwSettings.isNsfwViewingEnabled
            ? l10n.nsfwContentVisible
            : l10n.nsfwContentBlurred,
      ),
      trailing: Switch(
        value: nsfwSettings.isNsfwViewingEnabled,
        onChanged: (value) async {
          if (value) {
            // Enabling NSFW - check if age confirmed
            if (!nsfwSettings.isAgeConfirmed) {
              // Show age confirmation dialog
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

              if (confirmed == true) {
                // Confirm age first
                await ref.read(nsfwSettingsProvider.notifier).confirmAge();
                // Then enable NSFW
                await ref
                    .read(nsfwSettingsProvider.notifier)
                    .enableNsfwViewing();
              }
            } else {
              // Age already confirmed, just enable
              await ref.read(nsfwSettingsProvider.notifier).enableNsfwViewing();
            }
          } else {
            // Disabling NSFW
            await ref.read(nsfwSettingsProvider.notifier).disableNsfwViewing();
          }
        },
      ),
    );
  }
}
