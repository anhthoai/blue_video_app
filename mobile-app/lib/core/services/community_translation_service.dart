import 'dart:convert';

import 'package:http/http.dart' as http;

class CommunityTranslationResult {
  final String translatedText;
  final String sourceLanguageCode;
  final String targetLanguageCode;

  const CommunityTranslationResult({
    required this.translatedText,
    required this.sourceLanguageCode,
    required this.targetLanguageCode,
  });
}

class CommunityTranslationService {
  static final Map<String, CommunityTranslationResult> _cache =
      <String, CommunityTranslationResult>{};
  static final Map<String, Future<CommunityTranslationResult>> _inFlight =
      <String, Future<CommunityTranslationResult>>{};

  static Future<CommunityTranslationResult> translate({
    required String text,
    required String targetLanguageCode,
  }) {
    final normalizedText = text.trim();
    final target = _normalizeTargetLanguage(targetLanguageCode);

    if (normalizedText.isEmpty) {
      return Future.value(
        CommunityTranslationResult(
          translatedText: text,
          sourceLanguageCode: target,
          targetLanguageCode: target,
        ),
      );
    }

    final cacheKey = '$target::$normalizedText';
    final cached = _cache[cacheKey];
    if (cached != null) {
      return Future.value(cached);
    }

    final pending = _inFlight[cacheKey];
    if (pending != null) {
      return pending;
    }

    final future = _translateInternal(
      text: normalizedText,
      targetLanguageCode: target,
    ).then((result) {
      _cache[cacheKey] = result;
      _inFlight.remove(cacheKey);
      return result;
    }).catchError((error) {
      _inFlight.remove(cacheKey);
      throw error;
    });

    _inFlight[cacheKey] = future;
    return future;
  }

  static Future<CommunityTranslationResult> _translateInternal({
    required String text,
    required String targetLanguageCode,
  }) async {
    final uri = Uri.parse('https://translate.googleapis.com/translate_a/single')
        .replace(
      queryParameters: <String, String>{
        'client': 'gtx',
        'sl': 'auto',
        'tl': targetLanguageCode,
        'dt': 't',
        'q': text,
      },
    );

    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Translation failed: ${response.statusCode}');
    }

    final dynamic decoded = jsonDecode(response.body);
    if (decoded is! List || decoded.isEmpty) {
      throw Exception('Unexpected translation response format');
    }

    final String translatedText = _extractTranslatedText(decoded) ?? text;
    final String sourceLanguageCode = _extractSourceLanguageCode(decoded) ?? 'auto';

    return CommunityTranslationResult(
      translatedText: translatedText,
      sourceLanguageCode: sourceLanguageCode,
      targetLanguageCode: targetLanguageCode,
    );
  }

  static String _normalizeTargetLanguage(String languageCode) {
    final normalized = languageCode.trim().toLowerCase();
    if (normalized == 'zh') {
      return 'zh-CN';
    }
    return normalized;
  }

  static String? _extractTranslatedText(List<dynamic> decoded) {
    final payload = decoded.first;
    if (payload is! List || payload.isEmpty) {
      return null;
    }

    final segments = <String>[];
    for (final entry in payload) {
      if (entry is List && entry.isNotEmpty && entry.first is String) {
        segments.add((entry.first as String).trimRight());
      }
    }

    if (segments.isEmpty) {
      return null;
    }

    return segments.join();
  }

  static String? _extractSourceLanguageCode(List<dynamic> decoded) {
    if (decoded.length > 2 && decoded[2] is String) {
      return (decoded[2] as String).toLowerCase();
    }

    return null;
  }
}
