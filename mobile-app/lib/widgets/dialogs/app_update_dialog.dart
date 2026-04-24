import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/services/version_service.dart';
import '../../l10n/app_localizations.dart';

class AppUpdateDialog extends StatefulWidget {
  final VersionInfo versionInfo;

  const AppUpdateDialog({
    super.key,
    required this.versionInfo,
  });

  @override
  State<AppUpdateDialog> createState() => _AppUpdateDialogState();
}

class _AppUpdateDialogState extends State<AppUpdateDialog> {
  CancelToken? _downloadCancelToken;
  bool _isDownloading = false;
  double? _downloadProgress;
  String? _downloadedFilePath;
  String? _statusMessage;

  @override
  void dispose() {
    _downloadCancelToken?.cancel('dialog disposed');
    super.dispose();
  }

  Future<void> _handleUpdateNow() async {
    if (_isDownloading) {
      return;
    }

    if (Platform.isAndroid) {
      final canInstall = await _ensureAndroidInstallPermission();
      if (!canInstall) {
        return;
      }

      if (_downloadedFilePath != null && File(_downloadedFilePath!).existsSync()) {
        await _openInstaller(_downloadedFilePath!);
        return;
      }

      await _downloadAndInstallAndroidUpdate();
      return;
    }

    final messenger = ScaffoldMessenger.maybeOf(context);
    final l10n = AppLocalizations.of(context);
    messenger?.showSnackBar(
      SnackBar(content: Text(l10n.updateAndroidInstallerOnly)),
    );

    final url = Uri.parse(widget.versionInfo.downloadUrl);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<bool> _ensureAndroidInstallPermission() async {
    if (!Platform.isAndroid) {
      return true;
    }

    var status = await Permission.requestInstallPackages.status;
    if (status.isGranted) {
      return true;
    }

    status = await Permission.requestInstallPackages.request();
    if (status.isGranted) {
      return true;
    }

    if (!mounted) {
      return false;
    }

    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          '${l10n.updateInstallerFailed}: Permission denied. Allow app installs for this app and try again.',
        ),
        action: SnackBarAction(
          label: l10n.openSystemSettings,
          onPressed: () async {
            final opened = await openAppSettings();
            if (!opened && mounted) {
              ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                SnackBar(content: Text(l10n.openSystemSettingsFailed)),
              );
            }
          },
        ),
      ),
    );

    return false;
  }

  Future<void> _downloadAndInstallAndroidUpdate() async {
    final dio = Dio();
    final l10n = AppLocalizations.of(context);
    final cancelToken = CancelToken();
    _downloadCancelToken = cancelToken;

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0;
      _statusMessage = null;
    });

    try {
      final tempDir = await getTemporaryDirectory();
      final updatesDir = Directory(p.join(tempDir.path, 'app-updates'));
      if (!await updatesDir.exists()) {
        await updatesDir.create(recursive: true);
      }

      final fileName = _buildUpdateFileName();
      final targetPath = p.join(updatesDir.path, fileName);
      final targetFile = File(targetPath);
      if (await targetFile.exists()) {
        await targetFile.delete();
      }

      await dio.download(
        widget.versionInfo.downloadUrl,
        targetPath,
        cancelToken: cancelToken,
        deleteOnError: true,
        onReceiveProgress: (received, total) {
          if (!mounted) {
            return;
          }

          setState(() {
            _downloadProgress = total > 0 ? received / total : null;
          });
        },
      );

      if (!mounted) {
        return;
      }

      _downloadedFilePath = targetPath;
      setState(() {
        _isDownloading = false;
        _downloadProgress = 1;
        _statusMessage = l10n.updateInstallPrompt;
      });

      await _openInstaller(targetPath);
    } on DioException catch (error) {
      if (!mounted || CancelToken.isCancel(error)) {
        return;
      }

      final messenger = ScaffoldMessenger.maybeOf(context);
      setState(() {
        _isDownloading = false;
        _downloadProgress = null;
      });
      messenger?.showSnackBar(
        SnackBar(
          content: Text('${l10n.updateDownloadFailed}: ${error.message ?? error.error ?? ''}'),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      final messenger = ScaffoldMessenger.maybeOf(context);
      setState(() {
        _isDownloading = false;
        _downloadProgress = null;
      });
      messenger?.showSnackBar(
        SnackBar(content: Text('${l10n.updateDownloadFailed}: $error')),
      );
    } finally {
      _downloadCancelToken = null;
    }
  }

  Future<void> _openInstaller(String filePath) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);

    try {
      final result = await OpenFile.open(filePath);
      if (!mounted || result.type == ResultType.done) {
        return;
      }

      messenger?.showSnackBar(
        SnackBar(content: Text('${l10n.updateInstallerFailed}: ${_mapOpenFileError(result)}')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      messenger?.showSnackBar(
        SnackBar(content: Text('${l10n.updateInstallerFailed}: $error')),
      );
    }
  }

  String _mapOpenFileError(OpenResult result) {
    switch (result.type) {
      case ResultType.noAppToOpen:
        return 'No installer was found on this device';
      case ResultType.fileNotFound:
        return 'Downloaded file was not found';
      case ResultType.permissionDenied:
        return 'Permission denied. Allow app installs for this app and try again';
      case ResultType.done:
        return result.message;
      default:
        return result.message;
    }
  }

  String _buildUpdateFileName() {
    final uri = Uri.tryParse(widget.versionInfo.downloadUrl);
    final candidate = uri?.pathSegments.isNotEmpty == true
        ? uri!.pathSegments.last
        : 'blue-video-${widget.versionInfo.latestVersion}.apk';
    final sanitized = candidate
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .trim();

    if (sanitized.toLowerCase().endsWith('.apk')) {
      return sanitized;
    }

    return 'blue-video-${widget.versionInfo.latestVersion}.apk';
  }

  String _buildDownloadProgressText(AppLocalizations l10n) {
    final progress = _downloadProgress;
    if (progress == null) {
      return '${l10n.updateDownloading}...';
    }

    final percent = (progress * 100).clamp(0, 100).round();
    return '${l10n.updateDownloading} ($percent%)...';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final versionInfo = widget.versionInfo;

    return PopScope(
      canPop: !versionInfo.forceUpdate && !_isDownloading,
      child: AlertDialog(
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.system_update,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                versionInfo.forceUpdate
                    ? l10n.updateRequired
                    : l10n.updateAvailable,
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Version info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.currentVersion,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        Text(
                          versionInfo.currentVersion,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const Icon(Icons.arrow_forward, color: Colors.grey),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          l10n.latestVersion,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        Text(
                          versionInfo.latestVersion,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Force update warning
              if (versionInfo.forceUpdate) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.forceUpdateMessage,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red[900],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Release notes
              Text(
                l10n.whatsNew,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                versionInfo.releaseNotes,
                style: const TextStyle(fontSize: 14),
              ),

              const SizedBox(height: 12),

              // Release date
              Row(
                children: [
                  const Icon(Icons.calendar_today,
                      size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(versionInfo.releaseDate),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),

              if (_isDownloading || _statusMessage != null || _downloadProgress == 1) ...[
                const SizedBox(height: 20),
                LinearProgressIndicator(
                  value: _downloadProgress,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(999),
                ),
                const SizedBox(height: 12),
                Text(
                  _isDownloading
                      ? _buildDownloadProgressText(l10n)
                      : (_statusMessage ?? l10n.updateInstallPrompt),
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ],
          ),
        ),
        actions: [
          if (!versionInfo.forceUpdate)
            TextButton(
              onPressed: _isDownloading
                  ? null
                  : () => Navigator.of(context).pop(),
              child: Text(l10n.later),
            ),
          ElevatedButton.icon(
            onPressed: _handleUpdateNow,
            icon: _isDownloading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.download),
            label: Text(l10n.updateNow),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  versionInfo.forceUpdate ? Colors.red : Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    } catch (e) {
      return isoDate;
    }
  }
}
