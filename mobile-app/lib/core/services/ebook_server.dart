import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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
  Map<String, dynamic>? _assetManifest;
  List<String>? _assetKeys;

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
    _assetManifest = null;
    _assetKeys = null;
  }

  Future<void> _ensureAssetManifestLoaded() async {
    if (_assetManifest != null && _assetKeys != null) return;
    final manifestString = await rootBundle.loadString('AssetManifest.json');
    final manifestMap = jsonDecode(manifestString) as Map<String, dynamic>;
    _assetManifest = manifestMap;
    _assetKeys = manifestMap.keys.toList(growable: false);
  }

  Future<Uint8List?> _loadAssetBytes(String logicalPath) async {
    await _ensureAssetManifestLoaded();
    final keys = _assetKeys ?? const [];

    final normalized = logicalPath.startsWith('assets/')
        ? logicalPath
        : 'assets/foliate-js/$logicalPath';

    final packagePath = 'packages/blue_video_app/$normalized';

    final candidates = <String>{normalized, packagePath};
    for (final key in keys) {
      if (key == normalized || key.endsWith('/$logicalPath')) {
        candidates.add(key);
      }
    }

    for (final candidate in candidates) {
      try {
        final byteData = await rootBundle.load(candidate);
        return byteData.buffer.asUint8List();
      } on FlutterError {
        continue;
      }
    }
    debugPrint(
        'EbookServer: asset not found for $logicalPath. Tried: $candidates');
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
      return Response.ok(
        entry.file.openRead(),
        headers: {
          'Content-Type': entry.contentType,
          'Access-Control-Allow-Origin': '*',
        },
      );
    }

    if (path.startsWith('/foliate/')) {
      final assetPath = path.substring('/foliate/'.length);
      final bytes = await _loadAssetBytes(assetPath);
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
    final foliateUrl = Uri(
      scheme: 'http',
      host: InternetAddress.loopbackIPv4.address,
      port: port,
      path: '/foliate/index.html',
      queryParameters: {
        'importing': jsonEncode(importing),
        'url': jsonEncode(_buildBookUrl(bookId)),
        'initialCfi': jsonEncode(initialCfi),
        'style': jsonEncode(style ?? _defaultStyle),
        'readingRules': jsonEncode(readingRules ?? _defaultReadingRules),
      },
    );
    return foliateUrl.toString();
  }

  String _buildBookUrl(String id) {
    return 'http://${InternetAddress.loopbackIPv4.address}:$port/ebook/$id';
  }

  static String _guessContentType(String assetPath) {
    if (assetPath.endsWith('.html')) {
      return 'text/html';
    }
    if (assetPath.endsWith('.js')) {
      return 'application/javascript';
    }
    final mime = lookupMimeType(assetPath);
    return mime ?? 'application/octet-stream';
  }

  static const Map<String, dynamic> _defaultStyle = {
    'fontSize': 18,
    'fontName': 'system',
    'fontPath': '',
    'fontWeight': 400,
    'letterSpacing': 0,
    'spacing': 1.5,
    'paragraphSpacing': 12,
    'textIndent': 0,
    'fontColor': '#333333',
    'backgroundColor': '#FFFFFF',
    'topMargin': 24,
    'bottomMargin': 24,
    'sideMargin': 8,
    'justify': true,
    'hyphenate': false,
    'pageTurnStyle': 'scroll',
    'maxColumnCount': 1,
    'writingMode': 'horizontal-tb',
    'textAlign': 'justify',
    'backgroundImage': '',
    'allowScript': true,
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
