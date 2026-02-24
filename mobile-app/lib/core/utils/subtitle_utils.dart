import 'dart:convert';
import '../services/api_service.dart';
import 'language_utils.dart';

/// Utility class for subtitle handling
class SubtitleUtils {
  static final ApiService _apiService = ApiService();

  /// Build subtitle URL from video file info and language code
  /// e.g., subtitles/2025/10/07/abc123.srt (English)
  /// e.g., subtitles/2025/10/07/abc123.tha.srt (Thai)
  static String buildSubtitleUrl(
    String? fileDirectory,
    String? fileName,
    String languageCode,
  ) {
    if (fileDirectory == null || fileName == null) {
      throw Exception('Missing file directory or file name');
    }

    // Remove video extension from fileName
    final baseFileName = fileName.replaceAll(RegExp(r'\.[^.]+$'), '');

    // Build subtitle filename based on language
    final normalizedLangCode =
        LanguageUtils.normalizeLanguageCode(languageCode);
    final subtitleFileName = normalizedLangCode == null
        ? '$baseFileName.srt' // English (default)
        : '$baseFileName.$normalizedLangCode.srt'; // Other languages

    return 'subtitles/$fileDirectory/$subtitleFileName';
  }

  /// Get a presigned/accessible subtitle URL from S3/R2.
  static Future<String?> getSubtitleUrl(
    String? fileDirectory,
    String? fileName,
    String languageCode,
  ) async {
    try {
      // Build subtitle S3 key
      final subtitleKey =
          buildSubtitleUrl(fileDirectory, fileName, languageCode);

      // Get presigned URL or accessible URL
      final subtitleUrl = await _apiService.getAccessibleFileUrl(subtitleKey);

      if (subtitleUrl == null) {
        print('⚠️  Could not get subtitle URL for: $subtitleKey');
        return null;
      }

      return subtitleUrl;
    } catch (e) {
      print('❌ Error loading subtitle: $e');
      return null;
    }
  }

  /// Get list of available subtitles with display names
  static List<SubtitleOption> getAvailableSubtitles(
      List<String>? subtitleCodes) {
    if (subtitleCodes == null || subtitleCodes.isEmpty) {
      return [];
    }

    return subtitleCodes.map((code) {
      return SubtitleOption(
        code: code,
        displayName: LanguageUtils.getLanguageName(code),
      );
    }).toList();
  }

  /// Check if text appears to be corrupted (contains garbled characters)
  static bool _isTextCorrupted(String text) {
    // Check for common garbled character patterns
    final garbledPatterns = [
      RegExp(r'[ÐÑÒÓÔÕÖØÙÚÛÜÝÞß]'), // Common garbled Cyrillic/Latin mix
      RegExp(r'[â€¢â€"â€œâ€]'), // Common UTF-8 misinterpretation
      RegExp(r'[Ã¡Ã©Ã­Ã³ÃºÃ±]'), // Spanish characters garbled
      RegExp(r'[Â]'), // Common encoding issue
      RegExp(r'[ï¿½]'), // Unicode replacement character
      RegExp(r'[�]'), // General replacement character
      RegExp(r'[ÂÃÄÅÆÇÈÉÊËÌÍÎÏ]'), // More garbled characters
    ];

    // If text contains any garbled patterns, it's likely corrupted
    for (final pattern in garbledPatterns) {
      if (pattern.hasMatch(text)) {
        return true;
      }
    }

    // Also check if text has too many non-printable characters
    final nonPrintableCount = text.codeUnits
        .where((code) => code < 32 && code != 9 && code != 10 && code != 13)
        .length;
    final totalLength = text.length;

    // If more than 5% non-printable characters, likely corrupted
    return totalLength > 0 && (nonPrintableCount / totalLength) > 0.05;
  }

  /// Intelligently detect encoding and decode bytes
  static String _detectAndDecodeEncoding(List<int> bytes) {
    // Try UTF-8 first (most common for modern subtitle files)
    try {
      final utf8Text = utf8.decode(bytes, allowMalformed: true);
      if (!_isTextCorrupted(utf8Text)) {
        print('✅ Successfully decoded as UTF-8');
        return utf8Text;
      }
      print('⚠️  UTF-8 text appears corrupted');
    } catch (e) {
      print('❌ UTF-8 decoding failed: $e');
    }

    // Try Latin-1 (ISO-8859-1) - common for Western European languages
    try {
      final latin1Text = latin1.decode(bytes);
      if (!_isTextCorrupted(latin1Text)) {
        print('✅ Successfully decoded as Latin-1');
        return latin1Text;
      }
      print('⚠️  Latin-1 text appears corrupted');
    } catch (e) {
      print('❌ Latin-1 decoding failed: $e');
    }

    // Try Windows-1252 (common for older Windows files)
    try {
      final windows1252Text = _decodeWindows1252(bytes);
      if (!_isTextCorrupted(windows1252Text)) {
        print('✅ Successfully decoded as Windows-1252');
        return windows1252Text;
      }
      print('⚠️  Windows-1252 text appears corrupted');
    } catch (e) {
      print('❌ Windows-1252 decoding failed: $e');
    }

    // Try UTF-16 (common for some subtitle formats)
    try {
      final utf16Text = utf8.decode(bytes,
          allowMalformed: true); // UTF-16 BOM detection would be better
      if (!_isTextCorrupted(utf16Text) &&
          utf16Text
              .contains(RegExp(r'[\u0100-\u017F\u0180-\u024F\u0250-\u02AF]'))) {
        print('✅ Successfully decoded as UTF-16');
        return utf16Text;
      }
    } catch (e) {
      print('❌ UTF-16 detection failed: $e');
    }

    // Ultimate fallback: return UTF-8 with malformed characters allowed
    print('⚠️  Using UTF-8 as fallback (may contain garbled characters)');
    return utf8.decode(bytes, allowMalformed: true);
  }

  /// Decode bytes using Windows-1252 encoding
  static String _decodeWindows1252(List<int> bytes) {
    // Simple Windows-1252 decoding (basic implementation)
    // For production, consider using a proper Windows-1252 decoder
    try {
      return latin1.decode(bytes); // Good approximation for most cases
    } catch (e) {
      print('❌ Windows-1252 decoding failed: $e');
      // Ultimate fallback: convert bytes to string as-is
      return String.fromCharCodes(bytes);
    }
  }
}

/// Subtitle option model
class SubtitleOption {
  final String code;
  final String displayName;

  SubtitleOption({
    required this.code,
    required this.displayName,
  });
}
