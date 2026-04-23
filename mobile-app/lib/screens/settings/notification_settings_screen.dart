import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../l10n/app_localizations.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  late Future<PermissionStatus> _notificationStatusFuture;

  @override
  void initState() {
    super.initState();
    _notificationStatusFuture = Permission.notification.status;
  }

  Future<void> _refreshStatus() async {
    setState(() {
      _notificationStatusFuture = Permission.notification.status;
    });
  }

  Future<void> _requestPermission() async {
    await Permission.notification.request();
    await _refreshStatus();
  }

  Future<void> _openSystemSettings(AppLocalizations l10n) async {
    final opened = await openAppSettings();
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.openSystemSettingsFailed)),
      );
    }
  }

  String _statusLabel(AppLocalizations l10n, PermissionStatus status) {
    if (status.isGranted) {
      return l10n.notificationsEnabled;
    }

    if (status.isDenied || status.isPermanentlyDenied) {
      return l10n.notificationsDisabled;
    }

    return l10n.notificationsRestricted;
  }

  Color _statusColor(PermissionStatus status, ColorScheme colorScheme) {
    if (status.isGranted) {
      return Colors.green;
    }

    if (status.isDenied || status.isPermanentlyDenied) {
      return colorScheme.error;
    }

    return Colors.orange;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.notifications),
      ),
      body: FutureBuilder<PermissionStatus>(
        future: _notificationStatusFuture,
        builder: (context, snapshot) {
          final status = snapshot.data ?? PermissionStatus.denied;
          final statusColor = _statusColor(status, theme.colorScheme);

          return ListView(
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
                        l10n.notificationAccess,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.notificationsSubtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.notifications_active,
                                color: statusColor, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              _statusLabel(l10n, status),
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: statusColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
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
                    ListTile(
                      leading: Icon(Icons.tune, color: theme.colorScheme.primary),
                      title: Text(l10n.requestNotificationPermission),
                      subtitle: Text(l10n.notificationAccess),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _requestPermission,
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.settings_outlined),
                      title: Text(l10n.openSystemSettings),
                      subtitle: Text(l10n.notificationsSubtitle),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _openSystemSettings(l10n),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}