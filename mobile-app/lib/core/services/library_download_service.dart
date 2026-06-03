import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/library_item_model.dart';
import 'api_service.dart';

class LibraryDownloadService {
  LibraryDownloadService._();

  static final LibraryDownloadService instance = LibraryDownloadService._();

  final ApiService _apiService = ApiService();

  Future<void> downloadLibraryItem(
    BuildContext context, {
    required LibraryItemModel item,
    String? suggestedName,
    Future<void> Function()? onCoinsCharged,
  }) async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      final response = await _apiService.authorizeLibraryItemDownload(item.id);
      final data = response['data'] as Map<String, dynamic>? ?? const {};

      final downloadUrl = data['downloadUrl']?.toString().trim();
      if (downloadUrl == null || downloadUrl.isEmpty) {
        throw Exception('Download URL unavailable for this item');
      }

      final uri = Uri.tryParse(downloadUrl);
      if (uri == null || !uri.scheme.startsWith('http')) {
        throw Exception('Invalid download URL');
      }

      final coinsCharged = _readInt(data['coinsCharged']);
      final remainingBalance = _readInt(data['remainingCoinBalance']);

      if (coinsCharged > 0 && onCoinsCharged != null) {
        await onCoinsCharged();
      }

      if (!context.mounted) {
        return;
      }

      final fileName = (suggestedName != null && suggestedName.trim().isNotEmpty)
          ? suggestedName.trim()
          : item.displayTitle;
      final savedPath = await _downloadToDevice(
        context,
        uri,
        fileName,
      );

      if (!context.mounted) {
        return;
      }

      final coinMessage = coinsCharged > 0 ? ' Charged $coinsCharged coins.' : '';
      final balanceMessage = remainingBalance > 0
          ? ' Remaining balance: $remainingBalance coins.'
          : '';

      messenger.showSnackBar(
        SnackBar(
          content: Text('Saved ${p.basename(savedPath)}.$coinMessage$balanceMessage'),
          action: SnackBarAction(
            label: 'Open',
            onPressed: () async {
              try {
                final result = await OpenFile.open(savedPath);
                if (result.type != ResultType.done) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Failed to open file: ${result.message}')),
                  );
                }
              } catch (error) {
                messenger.showSnackBar(
                  SnackBar(content: Text('Failed to open file: $error')),
                );
              }
            },
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Download failed: ${_extractErrorMessage(error)}')),
      );
    }
  }

  Future<String> _downloadToDevice(
    BuildContext context,
    Uri url,
    String suggestedName,
  ) async {
    final dio = Dio();
    final progressNotifier = ValueNotifier<double?>(null);
    final cancelToken = CancelToken();
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
      final downloadsDir = await _resolveDownloadDirectory();
      final sanitized = _sanitizeFileName(suggestedName);
      final targetPath = await _uniqueFilePath(downloadsDir, sanitized);

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

      return targetPath;
    } finally {
      progressNotifier.dispose();
      if (navigator.mounted && navigator.canPop()) {
        navigator.pop();
      }
    }
  }

  Future<void> _ensureStoragePermission() async {
    if (!Platform.isAndroid) {
      return;
    }

    final manageStatus = await Permission.manageExternalStorage.status;
    if (manageStatus.isGranted) {
      return;
    }

    if (manageStatus.isPermanentlyDenied) {
      throw Exception('Storage permission denied. Enable access in system settings.');
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
    await _ensureStoragePermission();

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

    return getTemporaryDirectory();
  }

  Future<String> _uniqueFilePath(Directory directory, String fileName) async {
    final base = p.basenameWithoutExtension(fileName);
    final extension = p.extension(fileName);
    var candidate = p.join(directory.path, fileName);
    var counter = 1;

    while (await File(candidate).exists()) {
      candidate = p.join(directory.path, '$base ($counter)$extension');
      counter += 1;
    }

    return candidate;
  }

  String _sanitizeFileName(String input) {
    final trimmed = input.trim().isEmpty ? 'library-file' : input.trim();
    final cleaned = trimmed.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final withoutControl = cleaned.replaceAll(RegExp(r'[\x00-\x1F]'), '');
    final compressed = withoutControl.replaceAll(RegExp(r'\s+'), ' ').trim();
    return compressed.isEmpty ? 'library-file' : compressed;
  }

  int _readInt(dynamic value) {
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse('$value') ?? 0;
  }

  String _extractErrorMessage(Object error) {
    final raw = error.toString();
    final apiError = RegExp(r'API Error: \d+ - (\{.*\})').firstMatch(raw);

    if (apiError != null) {
      final body = apiError.group(1);
      if (body != null) {
        try {
          final decoded = json.decode(body);
          if (decoded is Map<String, dynamic>) {
            final message = decoded['message']?.toString().trim();
            if (message != null && message.isNotEmpty) {
              return message;
            }
          }
        } catch (_) {
          // Keep fallback error below.
        }
      }
    }

    return raw.replaceFirst('Exception: ', '').trim();
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
        builder: (_, progress, __) {
          final percent =
              progress == null ? null : (progress * 100).clamp(0, 100).toDouble();
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LinearProgressIndicator(value: progress),
              const SizedBox(height: 12),
              Text(
                percent == null
                    ? 'Downloading...'
                    : 'Downloading... ${percent.toStringAsFixed(1)}%',
              ),
            ],
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () {
            cancelToken.cancel('Cancelled by user');
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
