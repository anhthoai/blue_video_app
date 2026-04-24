import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'version_service.dart';
import '../../widgets/dialogs/app_update_dialog.dart';

const String _appUpdateLastCheckAtKey = 'app_update_last_check_at';
const String _appUpdateOptionalPromptAtKey = 'app_update_optional_prompt_at';

class AppUpdateCoordinator {
  AppUpdateCoordinator({required this.versionService});

  final VersionService versionService;
  bool _isChecking = false;
  bool _isDialogVisible = false;

  Future<void> checkOnStartup(BuildContext context) {
    return _checkForUpdates(
      context,
      minimumInterval: Duration.zero,
      ignoreOptionalPromptCooldown: false,
    );
  }

  Future<void> checkOnResume(BuildContext context) {
    return _checkForUpdates(
      context,
      minimumInterval: const Duration(hours: 1),
      ignoreOptionalPromptCooldown: false,
    );
  }

  Future<void> _checkForUpdates(
    BuildContext context, {
    required Duration minimumInterval,
    required bool ignoreOptionalPromptCooldown,
  }) async {
    if (!context.mounted || _isChecking || _isDialogVisible) {
      return;
    }

    _isChecking = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final lastCheckTime = _readStoredDateTime(
        prefs.getString(_appUpdateLastCheckAtKey),
      );

      if (minimumInterval > Duration.zero && lastCheckTime != null) {
        final timeSinceLastCheck = now.difference(lastCheckTime);
        if (timeSinceLastCheck < minimumInterval) {
          debugPrint(
            '⏭️ Skipping version check (checked ${timeSinceLastCheck.inMinutes} minutes ago)',
          );
          return;
        }
      }

      await prefs.setString(_appUpdateLastCheckAtKey, now.toIso8601String());

      final versionInfo = await versionService.checkForUpdates();
      if (!context.mounted || versionInfo == null || !versionInfo.updateRequired) {
        return;
      }

      if (!versionInfo.forceUpdate && !ignoreOptionalPromptCooldown) {
        final nextOptionalPromptAt = _readStoredDateTime(
          prefs.getString(_appUpdateOptionalPromptAtKey),
        );
        if (nextOptionalPromptAt != null && now.isBefore(nextOptionalPromptAt)) {
          debugPrint(
            '⏭️ Skipping optional update dialog until ${nextOptionalPromptAt.toIso8601String()}',
          );
          return;
        }
      }

      _isDialogVisible = true;
      await showDialog<void>(
        context: context,
        barrierDismissible: !versionInfo.forceUpdate,
        builder: (dialogContext) => AppUpdateDialog(versionInfo: versionInfo),
      );

      if (!versionInfo.forceUpdate) {
        final nextOptionalPromptAt = DateTime.now().add(const Duration(hours: 24));
        await prefs.setString(
          _appUpdateOptionalPromptAtKey,
          nextOptionalPromptAt.toIso8601String(),
        );
      }
    } catch (e) {
      debugPrint('❌ Update check error: $e');
    } finally {
      _isChecking = false;
      _isDialogVisible = false;
    }
  }

  DateTime? _readStoredDateTime(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }

    return DateTime.tryParse(value);
  }
}

final appUpdateCoordinatorProvider = Provider<AppUpdateCoordinator>((ref) {
  final versionService = ref.watch(versionServiceProvider);
  return AppUpdateCoordinator(versionService: versionService);
});

class AppLifecycleObserver extends WidgetsBindingObserver {
  final BuildContext context;
  final AppUpdateCoordinator updateCoordinator;

  AppLifecycleObserver({
    required this.context,
    required this.updateCoordinator,
  });

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      updateCoordinator.checkOnResume(context);
    }
  }
}
