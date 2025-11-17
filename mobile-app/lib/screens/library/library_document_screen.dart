import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/library_navigation.dart';

class LibraryDocumentScreen extends StatelessWidget {
  const LibraryDocumentScreen({super.key, required this.args});

  final LibraryDocumentArgs args;

  @override
  Widget build(BuildContext context) {
    final item = args.item;
    final downloadUrl = item.streamUrl ?? item.fileUrl;

    return Scaffold(
      appBar: AppBar(
        title: Text(item.displayTitle),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            Icon(
              Icons.insert_drive_file,
              size: 96,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              item.displayTitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            if (item.mimeType != null && item.mimeType!.isNotEmpty)
              Text(
                item.mimeType!,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Colors.grey[600]),
              ),
            if (item.fileSize != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _formatBytes(item.fileSize!),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.grey[600]),
                ),
              ),
            const Spacer(),
            Text(
              'Viewer not available. Download the file to open it with an external application.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: downloadUrl != null && downloadUrl.isNotEmpty
                    ? () => _handleDownload(
                          context,
                          url: downloadUrl,
                          suggestedName: item.displayTitle,
                        )
                    : null,
                icon: const Icon(Icons.download),
                label: const Text('Download'),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _handleDownload(
    BuildContext context, {
    required String url,
    required String suggestedName,
  }) async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      final uri = Uri.tryParse(url);
      if (uri == null) {
        throw Exception('Invalid download URL.');
      }

      if (uri.scheme.startsWith('http')) {
        await _ensureStoragePermission();
        await _downloadToDevice(context, uri, suggestedName);
        return;
      }

      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw Exception('Unable to open download link.');
      }
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Download failed: $error')),
      );
    }
  }

  Future<void> _downloadToDevice(
    BuildContext context,
    Uri url,
    String suggestedName,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final dio = Dio();
    final progressNotifier = ValueNotifier<double?>(null);
    final cancelToken = CancelToken();

    final downloadsDir = await _resolveDownloadDirectory();
    final sanitized = _sanitizeFileName(suggestedName);
    final targetPath = await _uniqueFilePath(downloadsDir, sanitized);

    final navigator = Navigator.of(context, rootNavigator: true);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DownloadProgressDialog(
        progressNotifier: progressNotifier,
        cancelToken: cancelToken,
      ),
    );

    try {
      await dio.download(
        url.toString(),
        targetPath,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          if (total <= 0) {
            progressNotifier.value = null;
          } else {
            progressNotifier.value = received / total;
          }
        },
      );

      messenger.showSnackBar(
        SnackBar(
          content: Text('Saved to ${p.basename(targetPath)}'),
        ),
      );
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Download cancelled.')),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(content: Text('Download failed: ${error.message}')),
        );
      }
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Download failed: $error')),
      );
    } finally {
      progressNotifier.dispose();
      if (navigator.mounted && navigator.canPop()) {
        navigator.pop();
      }
    }
  }

  Future<void> _ensureStoragePermission() async {
    if (!Platform.isAndroid) return;

    final manageStatus = await Permission.manageExternalStorage.status;
    if (manageStatus.isGranted) {
      return;
    }

    if (manageStatus.isPermanentlyDenied) {
      throw Exception(
          'Storage permission denied. Please enable access in settings.');
    }

    var status = await Permission.manageExternalStorage.request();
    if (status.isGranted) {
      return;
    }

    status = await Permission.storage.request();
    if (!status.isGranted) {
      throw Exception('Storage permission denied.');
    }
  }

  Future<Directory> _resolveDownloadDirectory() async {
    if (Platform.isAndroid) {
      final publicDownloads = Directory('/storage/emulated/0/Download');
      if (publicDownloads.existsSync()) {
        return publicDownloads;
      }
    }

    final downloadsDir = await getDownloadsDirectory();
    if (downloadsDir != null) {
      return downloadsDir;
    }
    return await getTemporaryDirectory();
  }

  Future<String> _uniqueFilePath(Directory directory, String fileName) async {
    final base = p.basenameWithoutExtension(fileName);
    final extension = p.extension(fileName);
    var candidate = p.join(directory.path, fileName);
    var counter = 1;

    while (File(candidate).existsSync()) {
      candidate = p.join(directory.path, '$base($counter)$extension');
      counter += 1;
    }
    return candidate;
  }

  String _sanitizeFileName(String name) {
    final sanitized = name
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (sanitized.isEmpty) {
      return 'document';
    }
    return sanitized;
  }

  String _formatBytes(int bytes) {
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var size = bytes.toDouble();
    var index = 0;
    while (size >= 1024 && index < suffixes.length - 1) {
      size /= 1024;
      index++;
    }
    return '${size.toStringAsFixed(1)} ${suffixes[index]}';
  }
}

class _DownloadProgressDialog extends StatelessWidget {
  const _DownloadProgressDialog({
    required this.progressNotifier,
    required this.cancelToken,
  });

  final ValueNotifier<double?> progressNotifier;
  final CancelToken cancelToken;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Downloading'),
      content: ValueListenableBuilder<double?>(
        valueListenable: progressNotifier,
        builder: (context, progress, _) {
          final percent =
              progress != null ? (progress * 100).clamp(0, 100) : null;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LinearProgressIndicator(value: progress),
              const SizedBox(height: 12),
              Text(
                percent == null
                    ? 'Downloading...'
                    : '${percent.toStringAsFixed(0)}%',
              ),
            ],
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () {
            if (!cancelToken.isCancelled) {
              cancelToken.cancel('cancelled');
            }
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
