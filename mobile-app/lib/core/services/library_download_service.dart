import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
    var requiredCoins = 0;
    var currentBalance = 0;

    try {
      final quoteResponse = await _apiService.getLibraryItemDownloadQuote(item.id);
      final quoteData = quoteResponse['data'] as Map<String, dynamic>? ?? const {};

      requiredCoins = _readInt(quoteData['requiredCoins']);
      currentBalance = _readInt(quoteData['currentBalance']);
      final shortfall = (requiredCoins - currentBalance).clamp(0, requiredCoins);
      final canAfford = quoteData['canAfford'] == true || shortfall == 0;

      if (!context.mounted) {
        return;
      }

      final action = await _showDownloadConfirmationDialog(
        context,
        title: item.displayTitle,
        requiredCoins: requiredCoins,
        currentBalance: currentBalance,
        canAfford: canAfford,
      );

      if (action == _DownloadAction.recharge) {
        if (context.mounted) {
          await context.push('/main/coin-recharge');
        }
        return;
      }

      if (action != _DownloadAction.downloadNow) {
        return;
      }

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
      final hasRemainingBalance = data['remainingCoinBalance'] != null;

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
      final balanceMessage = hasRemainingBalance
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
      if (context.mounted && _isInsufficientCoinsError(error)) {
        final parsedBalance = _extractCurrentBalance(error);
        await _showInsufficientCoinsDialog(
          context,
          requiredCoins: requiredCoins,
          currentBalance: parsedBalance ?? currentBalance,
        );
        return;
      }

      messenger.showSnackBar(
        SnackBar(content: Text('Download failed: ${_extractErrorMessage(error)}')),
      );
    }
  }

  Future<_DownloadAction?> _showDownloadConfirmationDialog(
    BuildContext context, {
    required String title,
    required int requiredCoins,
    required int currentBalance,
    required bool canAfford,
  }) async {
    final shortfall = (requiredCoins - currentBalance).clamp(0, requiredCoins);
    return showDialog<_DownloadAction>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        return AlertDialog(
          title: const Text('Download file'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 12),
              _InfoRow(
                icon: Icons.download,
                label: 'Download cost',
                value: requiredCoins == 0 ? 'Free' : '$requiredCoins coins',
              ),
              const SizedBox(height: 8),
              _InfoRow(
                icon: Icons.account_balance_wallet,
                label: 'Your balance',
                value: '$currentBalance coins',
              ),
              if (!canAfford) ...[
                const SizedBox(height: 12),
                Text(
                  'Need $shortfall more coins to continue.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(_DownloadAction.cancel);
              },
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(dialogContext).pop(
                  canAfford ? _DownloadAction.downloadNow : _DownloadAction.recharge,
                );
              },
              icon: Icon(canAfford ? Icons.download : Icons.add_circle_outline),
              label: Text(canAfford ? 'Download now' : 'Buy coins'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showInsufficientCoinsDialog(
    BuildContext context, {
    required int requiredCoins,
    required int currentBalance,
  }) async {
    final effectiveRequiredCoins = requiredCoins > 0 ? requiredCoins : 10;
    final shortfall =
        (effectiveRequiredCoins - currentBalance).clamp(0, effectiveRequiredCoins);

    final action = await showDialog<_DownloadAction>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Not enough coins'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('This download costs $effectiveRequiredCoins coins.'),
              const SizedBox(height: 6),
              Text('Your balance: $currentBalance coins.'),
              const SizedBox(height: 6),
              Text('You need $shortfall more coins.'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(_DownloadAction.cancel);
              },
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(dialogContext).pop(_DownloadAction.recharge);
              },
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Buy coins'),
            ),
          ],
        );
      },
    );

    if (action == _DownloadAction.recharge && context.mounted) {
      await context.push('/main/coin-recharge');
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
    final payload = _extractApiErrorPayload(error);
    if (payload != null) {
      final message = payload['message']?.toString().trim();
      if (message != null && message.isNotEmpty) {
        return message;
      }
    }

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

  Map<String, dynamic>? _extractApiErrorPayload(Object error) {
    final raw = error.toString();
    final match = RegExp(r'API Error: (\d+) - (\{.*\})').firstMatch(raw);
    if (match == null) {
      return null;
    }

    final body = match.group(2);
    if (body == null) {
      return null;
    }

    try {
      final decoded = json.decode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      // Ignore parse failures and return null.
    }

    return null;
  }

  bool _isInsufficientCoinsError(Object error) {
    final raw = error.toString().toLowerCase();
    final statusMatch = RegExp(r'API Error: (\d+)').firstMatch(error.toString());
    final statusCode = int.tryParse(statusMatch?.group(1) ?? '');
    if (statusCode == 402) {
      return true;
    }
    return raw.contains('not enough coins') || raw.contains('insufficient');
  }

  int? _extractCurrentBalance(Object error) {
    final payload = _extractApiErrorPayload(error);
    if (payload == null) {
      return null;
    }

    final data = payload['data'];
    if (data is Map<String, dynamic>) {
      return _readInt(data['currentBalance']);
    }
    return null;
  }
}

enum _DownloadAction {
  cancel,
  downloadNow,
  recharge,
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
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
