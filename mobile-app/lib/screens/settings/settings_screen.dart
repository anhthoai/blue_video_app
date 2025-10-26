import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/nsfw_settings_service.dart';
import '../../core/services/locale_service.dart';
import '../../l10n/app_localizations.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final currentLocale = ref.watch(localeProvider);
    
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
    
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings),
        backgroundColor: Colors.blue[50],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // App Information Section
          _buildSection(
            context,
            'App Information',
            [
              _buildListTile(
                context,
                icon: Icons.info_outline,
                title: 'App Version',
                subtitle: '1.0.0 (Test Build)',
                onTap: () {},
              ),
              _buildListTile(
                context,
                icon: Icons.bug_report,
                title: 'Test Instructions',
                subtitle: 'How to test the app features',
                onTap: () => context.push('/main/test-instructions'),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Account Section
          _buildSection(
            context,
            'Account',
            [
              _buildListTile(
                context,
                icon: Icons.person_outline,
                title: 'Profile Settings',
                subtitle: 'Manage your profile information',
                onTap: () => context.push('/main/profile/edit'),
              ),
              _buildListTile(
                context,
                icon: Icons.notifications_outlined,
                title: 'Notifications',
                subtitle: 'Manage notification preferences',
                onTap: () {},
              ),
              _buildListTile(
                context,
                icon: Icons.privacy_tip_outlined,
                title: 'Privacy & Security',
                subtitle: 'Manage your privacy settings',
                onTap: () {},
              ),
              _buildNsfwToggle(context, ref),
            ],
          ),

          const SizedBox(height: 24),

          // App Settings Section
          _buildSection(
            context,
            'App Settings',
            [
              _buildListTile(
                context,
                icon: Icons.dark_mode_outlined,
                title: 'Theme',
                subtitle: 'Light, Dark, or System',
                onTap: () {},
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
                title: 'Storage',
                subtitle: 'Manage app storage',
                onTap: () {},
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Support Section
          _buildSection(
            context,
            'Support',
            [
              _buildListTile(
                context,
                icon: Icons.help_outline,
                title: 'Help & Support',
                subtitle: 'Get help with the app',
                onTap: () {},
              ),
              _buildListTile(
                context,
                icon: Icons.feedback_outlined,
                title: 'Send Feedback',
                subtitle: 'Share your thoughts',
                onTap: () {},
              ),
              _buildListTile(
                context,
                icon: Icons.star_outline,
                title: 'Rate App',
                subtitle: 'Rate us on the app store',
                onTap: () {},
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Debug Section (for testing)
          _buildSection(
            context,
            'Debug (Testing Only)',
            [
              _buildListTile(
                context,
                icon: Icons.science_outlined,
                title: 'Mock Data Status',
                subtitle: 'Mock data is active for testing',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Mock data is currently active for testing purposes'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
              _buildListTile(
                context,
                icon: Icons.api_outlined,
                title: 'API Status',
                subtitle: 'No real API connections',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content:
                          Text('No real API connections - using mock data'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
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
                    title: const Text('Logout'),
                    content: const Text('Are you sure you want to logout?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        child: const Text('Logout'),
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
                          content: Text('Logout failed: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                }
              },
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
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

  Widget _buildNsfwToggle(BuildContext context, WidgetRef ref) {
    final nsfwSettings = ref.watch(nsfwSettingsProvider);

    return ListTile(
      leading: const Icon(Icons.explicit, color: Colors.orange),
      title: const Text('Show NSFW Content'),
      subtitle: Text(
        nsfwSettings.isNsfwViewingEnabled
            ? 'NSFW content is visible'
            : 'NSFW content is blurred (18+ required)',
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
                  title: const Text('Age Confirmation Required'),
                  content: const Text(
                    'You must be 18 years or older to view NSFW content.\n\nDo you confirm that you are 18 years or older?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                      ),
                      child: const Text('I am 18+'),
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
