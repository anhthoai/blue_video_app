import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/services/auth_service.dart';
import '../../core/services/locale_service.dart';
import '../../core/services/theme_service.dart';
import '../../l10n/app_localizations.dart';
import 'privacy_policy_screen.dart';
import '../../widgets/common/app_logo.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final currentLocale = ref.watch(localeProvider);
    final currentTheme = ref.watch(themeProvider);
    final authService = ref.watch(authServiceProvider);
    final isAdmin = authService.isAdmin;

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

    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final versionText = snapshot.hasData
            ? '${snapshot.data!.version} (${snapshot.data!.buildNumber})'
            : '...';

        return Scaffold(
          appBar: AppBar(
            title: Text(l10n.settings),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildOverviewCard(context, l10n, versionText),
              const SizedBox(height: 24),
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
                    icon: Icons.lock_outline,
                    title: 'Change Password',
                    subtitle: 'Update the password for this account',
                    onTap: () => context.push('/main/settings/change-password'),
                  ),
                  _buildListTile(
                    context,
                    icon: Icons.notifications_outlined,
                    title: l10n.notifications,
                    subtitle: l10n.notificationsSubtitle,
                    onTap: () => context.push('/main/settings/notifications'),
                  ),
                  _buildListTile(
                    context,
                    icon: Icons.privacy_tip_outlined,
                    title: l10n.privacySecurity,
                    subtitle: l10n.privacySecuritySubtitle,
                    onTap: () => context.push('/main/settings/privacy'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
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
                    onTap: () => _confirmClearCache(context, l10n),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildSection(
                context,
                l10n.support,
                [
                  _buildListTile(
                    context,
                    icon: Icons.policy_outlined,
                    title: l10n.privacyPolicy,
                    subtitle: l10n.privacyPolicySubtitle,
                    onTap: () => _openPrivacyPolicy(context),
                  ),
                  _buildListTile(
                    context,
                    icon: Icons.feedback_outlined,
                    title: l10n.sendFeedback,
                    subtitle: l10n.sendFeedbackSubtitle,
                    onTap: () => context.push('/main/settings/feedback'),
                  ),
                ],
              ),
              if (isAdmin) ...[
                const SizedBox(height: 24),
                _buildSection(
                  context,
                  'Admin',
                  [
                    _buildListTile(
                      context,
                      icon: Icons.admin_panel_settings_outlined,
                      title: 'Management Dashboard',
                      subtitle: 'Statistics, videos, categories, users',
                      onTap: () => context.push('/main/settings/admin'),
                    ),
                    _buildListTile(
                      context,
                      icon: Icons.flag_outlined,
                      title: 'Reports',
                      subtitle: 'Review and moderate reports',
                      onTap: () => context.push('/main/settings/admin/reports'),
                    ),
                    _buildListTile(
                      context,
                      icon: Icons.mark_email_read_outlined,
                      title: 'Feedback Inbox',
                      subtitle: 'Reply to user feedback',
                      onTap: () =>
                          context.push('/main/settings/admin/feedback'),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              _buildSection(
                context,
                l10n.appInformation,
                [
                  _buildListTile(
                    context,
                    icon: Icons.info_outline,
                    title: l10n.appVersion,
                    subtitle: versionText,
                    onTap: () =>
                        _showAppInformation(context, l10n, versionText),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Center(
                child: ElevatedButton.icon(
                  onPressed: () => _confirmLogout(context, ref, l10n),
                  icon: const Icon(Icons.logout),
                  label: Text(l10n.logout),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOverviewCard(
    BuildContext context,
    AppLocalizations l10n,
    String versionText,
  ) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 1,
      child: InkWell(
        onTap: () => _showAppInformation(context, l10n, versionText),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              const AppLogo(
                size: 72,
                borderRadius: 18,
                padding: EdgeInsets.all(10),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.appName,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${l10n.appVersion} $versionText',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      l10n.appInformation,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.info_outline,
                color: theme.colorScheme.primary,
              ),
            ],
          ),
        ),
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

  Future<void> _showAppInformation(
    BuildContext context,
    AppLocalizations l10n,
    String versionText,
  ) async {
    showAboutDialog(
      context: context,
      applicationName: l10n.appName,
      applicationVersion: versionText,
      applicationIcon: const AppLogo(
        size: 56,
        borderRadius: 14,
        padding: EdgeInsets.all(8),
      ),
    );
  }

  Future<void> _openPrivacyPolicy(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const PrivacyPolicyScreen(),
      ),
    );
  }

  Future<void> _confirmClearCache(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.storage),
        content: Text(l10n.clearCacheMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.clearCacheAction),
          ),
        ],
      ),
    );

    if (shouldClear != true) {
      return;
    }

    final tempDirectory = await getTemporaryDirectory();
    await _deleteDirectoryContents(tempDirectory);
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.cacheCleared)),
      );
    }
  }

  Future<void> _deleteDirectoryContents(Directory directory) async {
    if (!await directory.exists()) {
      return;
    }

    await for (final entity in directory.list()) {
      try {
        await entity.delete(recursive: true);
      } catch (_) {}
    }
  }

  Future<void> _confirmLogout(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
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

    if (shouldLogout != true || !context.mounted) {
      return;
    }

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
}
