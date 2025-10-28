import 'package:flutter/material.dart';
import 'version_service.dart';
import '../../widgets/dialogs/app_update_dialog.dart';

class AppLifecycleObserver extends WidgetsBindingObserver {
  final BuildContext context;
  final VersionService versionService;
  bool _hasShownUpdateDialog = false;
  DateTime? _lastCheckTime;

  AppLifecycleObserver({
    required this.context,
    required this.versionService,
  });

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Check for updates when app resumes from background
      _checkForUpdatesIfNeeded();
    }
  }

  Future<void> checkForUpdatesOnStartup() async {
    // Check for updates on app startup
    await _checkForUpdates();
  }

  Future<void> _checkForUpdatesIfNeeded() async {
    // Don't check too frequently (minimum 1 hour between checks)
    if (_lastCheckTime != null) {
      final timeSinceLastCheck = DateTime.now().difference(_lastCheckTime!);
      if (timeSinceLastCheck.inHours < 1) {
        print(
            '⏭️ Skipping version check (checked ${timeSinceLastCheck.inMinutes} minutes ago)');
        return;
      }
    }

    await _checkForUpdates();
  }

  Future<void> _checkForUpdates() async {
    try {
      _lastCheckTime = DateTime.now();

      final versionInfo = await versionService.checkForUpdates();

      if (versionInfo != null &&
          versionInfo.updateRequired &&
          context.mounted &&
          !_hasShownUpdateDialog) {
        _hasShownUpdateDialog = true;

        // Show update dialog
        showDialog(
          context: context,
          barrierDismissible: !versionInfo.forceUpdate,
          builder: (context) => AppUpdateDialog(versionInfo: versionInfo),
        ).then((_) {
          // Reset flag after dialog is dismissed (only for optional updates)
          if (!versionInfo.forceUpdate) {
            Future.delayed(const Duration(hours: 24), () {
              _hasShownUpdateDialog = false;
            });
          }
        });
      }
    } catch (e) {
      print('❌ Update check error: $e');
    }
  }
}
