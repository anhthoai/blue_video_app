import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;

import '../../core/models/library_item_model.dart';
import '../../core/models/library_navigation.dart';
import '../../core/services/ebook_server.dart';

class LibraryEbookReaderScreen extends StatefulWidget {
  const LibraryEbookReaderScreen({super.key, required this.args});

  final LibraryEbookReaderArgs args;

  @override
  State<LibraryEbookReaderScreen> createState() =>
      _LibraryEbookReaderScreenState();
}

class _LibraryEbookReaderScreenState extends State<LibraryEbookReaderScreen> {
  InAppWebViewController? _controller;
  String? _readerUrl;
  String? _bookEntryId;
  bool _isLoading = true;
  String? _error;
  double _percentage = 0;
  String? _chapterTitle;
  List<_EbookChapter> _chapterTree = const <_EbookChapter>[];
  bool _hasReceivedInitialRelocated = false;
  int _relocatedCount = 0;
  late ContextMenu _contextMenu;

  InAppWebViewSettings get _webViewSettings => InAppWebViewSettings(
        supportZoom: false,
        isInspectable: kDebugMode,
      );

  @override
  void initState() {
    super.initState();
    _contextMenu = ContextMenu(
      settings: ContextMenuSettings(hideDefaultSystemContextMenuItems: true),
      onCreateContextMenu: (hitTestResult) async {
        // Context menu handling can be added later if needed
      },
      onHideContextMenu: () {
        // Handle context menu hide if needed
      },
    );
    _prepareReader();
  }

  @override
  void dispose() {
    _relocatedCount = 0;
    _hasReceivedInitialRelocated = false;
    final entryId = _bookEntryId;
    if (entryId != null) {
      unawaited(EbookServer.instance.unregisterBook(entryId));
    }
    super.dispose();
  }

  Future<void> _prepareReader() async {
    final item = widget.args.item;
    final url = item.streamUrl ?? item.fileUrl;
    if (url == null || url.isEmpty) {
      setState(() {
        _error = 'No file URL available for this book.';
        _isLoading = false;
      });
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final response = await http.get(Uri.parse(url));
      if (response.statusCode >= 400) {
        throw Exception(
            'Failed to download ebook (HTTP ${response.statusCode}).');
      }

      final bytes = response.bodyBytes;
      if (bytes.isEmpty) {
        throw Exception('Downloaded ebook file is empty.');
      }

      final extension = _deriveExtension(item);
      final server = EbookServer.instance;
      final bookId = await server.registerBook(
        bytes: Uint8List.fromList(bytes),
        extension: extension,
      );
      final readerUrl = server.buildReaderUrl(bookId: bookId);

      if (!mounted) return;
      _bookEntryId = bookId;
      _readerUrl = readerUrl;

      final controller = _controller;
      if (controller != null) {
        await controller.loadUrl(
          urlRequest: URLRequest(url: WebUri(readerUrl)),
        );
      }
      setState(() {});
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  void _onConsoleMessage(
      InAppWebViewController controller, ConsoleMessage message) {
    const ignoreMessages = [
      'An iframe which has both allow-scripts and allow-same-origin for its sandbox attribute can escape its sandboxing',
      'JavaScript execution returned a result of an unsupported type',
    ];

    if (ignoreMessages.contains(message.message)) {
      return;
    }

    if (message.messageLevel == ConsoleMessageLevel.ERROR) {
      debugPrint('JS Console [ERROR]: ${message.message}');
    }
  }

  Future<void> _registerHandlers(InAppWebViewController controller) async {
    controller.addJavaScriptHandler(
      handlerName: 'onLoadEnd',
      callback: (args) {
        // Don't navigate here - wait for onRelocated to ensure layout is calculated
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'onRelocated',
      callback: (args) {
        _relocatedCount++;
        debugPrint('onRelocated received (count: $_relocatedCount)');

        if (!_hasReceivedInitialRelocated) {
          _hasReceivedInitialRelocated = true;
          debugPrint('Initial onRelocated received - viewer layout is ready');

          Future.delayed(const Duration(milliseconds: 300), () async {
            if (!mounted || _controller == null) return;

            await _controller!.evaluateJavascript(source: '''
              (function() {
                if (window.globalThis.reader && window.globalThis.reader.toc) {
                  window.flutter_inappwebview.callHandler('onSetToc', window.globalThis.reader.toc);
                }
                if (typeof window.refreshLayout === 'function') {
                  try { window.refreshLayout(); } catch (e) { /* ignore */ }
                }
              })();
            ''');
          });
        }

        try {
          final data = Map<String, dynamic>.from(args.first as Map);
          if (!mounted) return null;
          setState(() {
            _chapterTitle = (data['chapterTitle'] as String?)?.trim();
            final value = data['percentage'];
            if (value is num) {
              _percentage = value.toDouble();
            }
          });
        } catch (error) {
          debugPrint('Failed to parse relocation event: $error');
        }
        return null;
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'onSetToc',
      callback: (args) {
        if (args.isEmpty) return null;
        try {
          final tree = _parseChapterTree(args.first, depth: 0);
          if (mounted) {
            setState(() => _chapterTree = tree);
          }
        } catch (error) {
          debugPrint('Failed to parse TOC: $error');
        }
        return null;
      },
    );

    // Ensure window.flutter_inappwebview exists immediately (before foliate-js loads)
    await controller.evaluateJavascript(source: '''
      (function() {
        if (typeof window.flutter_inappwebview === 'undefined') {
          window.flutter_inappwebview = {
            callHandler: function(name, data) {
              console.log('callHandler called (stub, handlers not ready yet):', name);
              return Promise.resolve();
            }
          };
        }
      })();
    ''');
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.args.item;

    return Scaffold(
      appBar: AppBar(
        title: Text(item.displayTitle),
        actions: [
          IconButton(
            tooltip: 'Reload',
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _prepareReader,
          ),
        ],
      ),
      body: _error != null
          ? _buildErrorView(context)
          : Stack(
              children: [
                Positioned.fill(child: _buildReaderView()),
                if (_readerUrl != null && _error == null)
                  _buildOverlayControls(),
                if (_isLoading)
                  const Center(child: CircularProgressIndicator()),
              ],
            ),
    );
  }

  Widget _buildReaderView() {
    if (_readerUrl == null) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragEnd: _handleHorizontalDrag,
      child: InAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(_readerUrl!)),
        initialSettings: _webViewSettings,
        contextMenu: _contextMenu,
        onWebViewCreated: (controller) {
          _controller = controller;
          _hasReceivedInitialRelocated = false;
          _relocatedCount = 0;
        },
        onLoadStop: (controller, uri) async {
          await _registerHandlers(controller);
          if (mounted) {
            setState(() => _isLoading = false);
          }
        },
        onConsoleMessage: _onConsoleMessage,
        onReceivedError: (controller, request, error) {
          if (mounted) {
            setState(() {
              _error = error.description;
              _isLoading = false;
            });
          }
        },
      ),
    );
  }

  Widget _buildErrorView(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(
              'Unable to open ebook',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? '',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _prepareReader,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverlayControls() {
    final percentLabel =
        '${(_percentage.clamp(0, 1) * 100).toStringAsFixed(1)}%';
    final title = _chapterTitle?.isNotEmpty == true ? _chapterTitle : null;

    return Positioned(
      top: 12,
      right: 12,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (_chapterTree.isNotEmpty)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black87,
                  foregroundColor: Colors.white,
                ),
                onPressed: _showChapterSheet,
                icon: const Icon(Icons.menu_book),
                label: const Text('Chapters'),
              ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.65),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (title != null)
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  Text(
                    percentLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showChapterSheet() {
    if (_chapterTree.isEmpty) return;
    final chapters = _flattenChapters(_chapterTree);

    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView.builder(
          itemCount: chapters.length,
          itemBuilder: (context, index) {
            final chapter = chapters[index];
            final enabled = chapter.href.isNotEmpty;
            return ListTile(
              enabled: enabled,
              contentPadding: EdgeInsets.only(
                left: 16 + chapter.depth * 16,
                right: 16,
              ),
              title: Text(
                chapter.label.isEmpty ? 'Untitled chapter' : chapter.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: enabled
                  ? () {
                      Navigator.of(context).pop();
                      _goToChapter(chapter.href);
                    }
                  : null,
            );
          },
        ),
      ),
    );
  }

  Future<void> _goToChapter(String href) async {
    if (href.isEmpty) return;
    final controller = _controller;
    if (controller == null) return;
    final script = 'window.goToHref(${jsonEncode(href)});';
    await controller.evaluateJavascript(source: script);
  }

  void _handleHorizontalDrag(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity < -120) {
      _controller?.evaluateJavascript(source: 'window.nextPage();');
    } else if (velocity > 120) {
      _controller?.evaluateJavascript(source: 'window.prevPage();');
    }
  }

  String _deriveExtension(LibraryItemModel item) {
    final filename = item.filePath ?? item.fileUrl ?? '';
    final segments = filename.split('.');
    if (segments.length > 1) {
      return segments.last.toLowerCase();
    }
    final mime = item.mimeType ?? '';
    if (mime.contains('epub')) return 'epub';
    if (mime.contains('mobi')) return 'mobi';
    if (mime.contains('azw') || mime.contains('kindle')) return 'azw3';
    if (mime.contains('fb2')) return 'fb2';
    if (mime.contains('pdf')) return 'pdf';
    if (mime.contains('text')) return 'txt';
    return 'epub';
  }

  List<_EbookChapter> _parseChapterTree(
    dynamic data, {
    required int depth,
  }) {
    final result = <_EbookChapter>[];

    if (data is List) {
      for (final entry in data) {
        result.addAll(_parseChapterTree(entry, depth: depth));
      }
      return result;
    }

    if (data is Map) {
      final label = data['label']?.toString() ?? '';
      final href = data['href']?.toString() ?? '';
      final dynamic childrenRaw =
          data['subitems'] ?? data['subItems'] ?? data['children'] ?? [];
      final children = _parseChapterTree(childrenRaw, depth: depth + 1);

      result.add(
        _EbookChapter(
          label: label,
          href: href,
          depth: depth,
          children: children,
        ),
      );
    }

    return result;
  }

  List<_EbookChapter> _flattenChapters(List<_EbookChapter> chapters) {
    final flattened = <_EbookChapter>[];

    void visit(List<_EbookChapter> items) {
      for (final chapter in items) {
        flattened.add(chapter);
        if (chapter.children.isNotEmpty) {
          visit(chapter.children);
        }
      }
    }

    visit(chapters);
    return flattened;
  }
}

class _EbookChapter {
  const _EbookChapter({
    required this.label,
    required this.href,
    required this.depth,
    this.children = const [],
  });

  final String label;
  final String href;
  final int depth;
  final List<_EbookChapter> children;
}
