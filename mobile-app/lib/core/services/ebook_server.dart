import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

class EbookServer {
  EbookServer._();

  static final EbookServer instance = EbookServer._();

  HttpServer? _server;
  final Map<String, _EbookEntry> _entries = {};

  Future<void> ensureStarted() async {
    if (_server != null) return;

    final handler = const Pipeline()
        .addMiddleware(logRequests())
        .addHandler(_handleRequest);

    _server = await shelf_io.serve(handler, InternetAddress.loopbackIPv4, 0);
  }

  int get port {
    final server = _server;
    if (server == null) {
      throw StateError('EbookServer has not been started.');
    }
    return server.port;
  }

  Future<void> dispose() async {
    await _server?.close(force: true);
    _server = null;
    _entries.clear();
  }

  Future<Uint8List?> _loadAssetBytes(
    String logicalPath, {
    String baseAssetDir = 'assets/foliate-js',
  }) async {
    final decodedPath = Uri.decodeComponent(logicalPath);
    final normalized = decodedPath.startsWith('assets/')
        ? decodedPath
        : '$baseAssetDir/$decodedPath';
    final packagePath = 'packages/blue_video_app/$normalized';

    final candidates = <String>{normalized, packagePath};

    for (final candidate in candidates) {
      try {
        final byteData = await rootBundle.load(candidate);
        return byteData.buffer.asUint8List();
      } on FlutterError {
        continue;
      }
    }
    debugPrint(
      'EbookServer: asset not found for $decodedPath. Tried: $candidates');
    return null;
  }

  Future<String> registerBook({
    required Uint8List bytes,
    required String extension,
    String? contentType,
  }) async {
    await ensureStarted();

    final tempDir = await getTemporaryDirectory();
    final sanitizedExtension =
        extension.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    final id = 'book_${DateTime.now().microsecondsSinceEpoch}';
    final fileName =
        sanitizedExtension.isEmpty ? id : '$id.$sanitizedExtension';
    final file = File(p.join(tempDir.path, fileName));
    await file.writeAsBytes(bytes, flush: true);

    final mime =
        contentType ?? lookupMimeType(file.path) ?? 'application/octet-stream';
    _entries[id] = _EbookEntry(file: file, contentType: mime);
    return id;
  }

  Future<void> unregisterBook(String id) async {
    final entry = _entries.remove(id);
    if (entry != null) {
      try {
        if (await entry.file.exists()) {
          await entry.file.delete();
        }
      } catch (_) {
        // ignore cleanup errors
      }
    }
  }

  Future<Response> _handleRequest(Request request) async {
    final path = request.requestedUri.path;

    if (path.startsWith('/ebook/')) {
      final id = path.substring('/ebook/'.length);
      final entry = _entries[id];
      if (entry == null || !await entry.file.exists()) {
        return Response.notFound('Book not found');
      }

      final fileLength = await entry.file.length();
      final rangeHeader = request.headers['range'];

      if (rangeHeader != null && rangeHeader.startsWith('bytes=')) {
        final rangeValue = rangeHeader.substring('bytes='.length).trim();
        final parts = rangeValue.split('-');

        if (parts.length == 2) {
          int? start;
          int? end;

          final startRaw = parts[0].trim();
          final endRaw = parts[1].trim();

          if (startRaw.isNotEmpty) {
            start = int.tryParse(startRaw);
          }
          if (endRaw.isNotEmpty) {
            end = int.tryParse(endRaw);
          }

          if (start == null && end != null) {
            final suffixLength = end;
            if (suffixLength > 0) {
              start = fileLength - suffixLength;
              if (start < 0) start = 0;
              end = fileLength - 1;
            }
          } else if (start != null && end == null) {
            end = fileLength - 1;
          }

          if (start != null && end != null && start >= 0 && end >= start) {
            if (start >= fileLength) {
              return Response(
                416,
                headers: {
                  'Content-Range': 'bytes */$fileLength',
                  'Accept-Ranges': 'bytes',
                  'Access-Control-Allow-Origin': '*',
                },
              );
            }

            if (end >= fileLength) {
              end = fileLength - 1;
            }

            final chunkLength = end - start + 1;
            return Response(
              206,
              body: entry.file.openRead(start, end + 1),
              headers: {
                'Content-Type': entry.contentType,
                'Content-Range': 'bytes $start-$end/$fileLength',
                'Content-Length': '$chunkLength',
                'Accept-Ranges': 'bytes',
                'Access-Control-Allow-Origin': '*',
              },
            );
          }
        }
      }

      return Response.ok(
        entry.file.openRead(),
        headers: {
          'Content-Type': entry.contentType,
          'Content-Length': '$fileLength',
          'Accept-Ranges': 'bytes',
          'Access-Control-Allow-Origin': '*',
        },
      );
    }

    if (path.startsWith('/foliate/')) {
      final assetPath = path.substring('/foliate/'.length);
      final bytes = await _loadAssetBytes(
        assetPath,
        baseAssetDir: 'assets/foliate-js',
      );
      if (bytes == null) {
        return Response.notFound('Asset not found: $assetPath');
      }
      final contentType = _guessContentType(assetPath);
      return Response.ok(
        bytes,
        headers: {
          'Content-Type': contentType,
          'Access-Control-Allow-Origin': '*',
        },
      );
    }

    if (path.startsWith('/pdfjs/')) {
      final assetPath = path.substring('/pdfjs/'.length);
      final bytes = await _loadAssetBytes(
        assetPath,
        baseAssetDir: 'assets/pdfjs',
      );
      if (bytes == null) {
        return Response.notFound('Asset not found: $assetPath');
      }
      final contentType = _guessContentType(assetPath);
      return Response.ok(
        bytes,
        headers: {
          'Content-Type': contentType,
          'Access-Control-Allow-Origin': '*',
        },
      );
    }

    if (path == '/' || path.isEmpty) {
      return Response.ok('Ebook server running', headers: {
        'Content-Type': 'text/plain; charset=utf-8',
        'Access-Control-Allow-Origin': '*',
      });
    }

    return Response.notFound('Not Found');
  }

  String buildReaderUrl({
    required String bookId,
    String initialCfi = '',
    Map<String, dynamic>? style,
    Map<String, dynamic>? readingRules,
    bool importing = false,
  }) {
    final styleToUse = style ?? _defaultStyle;
    final readingRulesToUse = readingRules ?? _defaultReadingRules;

    // Build query string exactly like simples3browser (jsonEncode each param, then Uri.encodeComponent)
    String queryString = '';
    final params = {
      'importing': importing,
      'url': _buildBookUrl(bookId),
      'initialCfi': initialCfi,
      'style': styleToUse,
      'readingRules': readingRulesToUse,
    };

    for (var key in params.keys) {
      queryString +=
          '$key=${Uri.encodeComponent(jsonEncode(params[key]))}&';
    }

    // Remove last &
    if (queryString.isNotEmpty) {
      queryString = queryString.substring(0, queryString.length - 1);
    }

    final foliateUrl = Uri(
      scheme: 'http',
      host: InternetAddress.loopbackIPv4.address,
      port: port,
      path: '/foliate/index.html',
      query: queryString,
    );
    return foliateUrl.toString();
  }

  String _buildBookUrl(String id) {
    return 'http://${InternetAddress.loopbackIPv4.address}:$port/ebook/$id';
  }

  String buildPdfReaderUrl({
    required String bookId,
    int initialPage = 1,
  }) {
    final fileUrl = _buildBookUrl(bookId);
    final page = initialPage <= 0 ? 1 : initialPage;

    final url = Uri(
      scheme: 'http',
      host: InternetAddress.loopbackIPv4.address,
      port: port,
      path: '/pdfjs/web/viewer.html',
      queryParameters: {
        'file': fileUrl,
        'page': '$page',
      },
    );
    return url.toString();
  }

  static String _guessContentType(String assetPath) {
    if (assetPath.endsWith('.html')) {
      return 'text/html';
    }
    if (assetPath.endsWith('.js')) {
      return 'application/javascript';
    }
    if (assetPath.endsWith('.mjs')) {
      return 'application/javascript';
    }
    final mime = lookupMimeType(assetPath);
    return mime ?? 'application/octet-stream';
  }

  static const Map<String, dynamic> _defaultStyle = {
    'fontSize': 1.4,
    'fontName': 'book',
    'fontPath': 'book',
    'fontWeight': 400.0,
    'letterSpacing': 0.0,
    'spacing': 1.8,
    'paragraphSpacing': 1.0,
    'textIndent': 0.0,
    'fontColor': '#343434FF',
    'backgroundColor': '#FBFBF3FF',
    'topMargin': 90.0,
    'bottomMargin': 50.0,
    'sideMargin': 6.0,
    'justify': true,
    'hyphenate': false,
    'pageTurnStyle': 'slide',
    'maxColumnCount': 0,
    'writingMode': 'auto',
    'textAlign': 'auto',
    'backgroundImage': 'none',
    'allowScript': false,
    'customCSS': '',
    'customCSSEnabled': false,
  };

  static const Map<String, dynamic> _defaultReadingRules = {
    'convertChineseMode': 'none',
    'bionicReadingMode': false,
  };
}

class _EbookEntry {
  _EbookEntry({required this.file, required this.contentType});

  final File file;
  final String contentType;
}
