/// Utility class for language code mapping
class LanguageUtils {
  /// Map of language codes (2 or 3 characters) to display names
  static const Map<String, String> languageNames = {
    // English
    'en': 'English',
    'eng': 'English',

    // Chinese
    'zh': 'Chinese',
    'chi': 'Chinese',
    'zho': 'Chinese',
    'cmn': 'Mandarin Chinese',

    // Spanish
    'es': 'Spanish',
    'spa': 'Spanish',

    // French
    'fr': 'French',
    'fre': 'French',
    'fra': 'French',

    // German
    'de': 'German',
    'ger': 'German',
    'deu': 'German',

    // Japanese
    'ja': 'Japanese',
    'jpn': 'Japanese',

    // Korean
    'ko': 'Korean',
    'kor': 'Korean',

    // Thai
    'th': 'Thai',
    'tha': 'Thai',

    // Vietnamese
    'vi': 'Vietnamese',
    'vie': 'Vietnamese',

    // Arabic
    'ar': 'Arabic',
    'ara': 'Arabic',

    // Portuguese
    'pt': 'Portuguese',
    'por': 'Portuguese',

    // Russian
    'ru': 'Russian',
    'rus': 'Russian',

    // Italian
    'it': 'Italian',
    'ita': 'Italian',

    // Dutch
    'nl': 'Dutch',
    'dut': 'Dutch',
    'nld': 'Dutch',

    // Polish
    'pl': 'Polish',
    'pol': 'Polish',

    // Turkish
    'tr': 'Turkish',
    'tur': 'Turkish',

    // Swedish
    'sv': 'Swedish',
    'swe': 'Swedish',

    // Danish
    'da': 'Danish',
    'dan': 'Danish',

    // Finnish
    'fi': 'Finnish',
    'fin': 'Finnish',

    // Norwegian
    'no': 'Norwegian',
    'nor': 'Norwegian',

    // Greek
    'el': 'Greek',
    'gre': 'Greek',
    'ell': 'Greek',

    // Czech
    'cs': 'Czech',
    'cze': 'Czech',
    'ces': 'Czech',

    // Hungarian
    'hu': 'Hungarian',
    'hun': 'Hungarian',

    // Romanian
    'ro': 'Romanian',
    'rum': 'Romanian',
    'ron': 'Romanian',

    // Hindi
    'hi': 'Hindi',
    'hin': 'Hindi',

    // Indonesian
    'id': 'Indonesian',
    'ind': 'Indonesian',

    // Malay
    'ms': 'Malay',
    'may': 'Malay',
    'msa': 'Malay',

    // Filipino/Tagalog
    'tl': 'Filipino',
    'fil': 'Filipino',
    'tgl': 'Tagalog',

    // Hebrew
    'he': 'Hebrew',
    'heb': 'Hebrew',

    // Ukrainian
    'uk': 'Ukrainian',
    'ukr': 'Ukrainian',

    // Bengali
    'bn': 'Bengali',
    'ben': 'Bengali',

    // Burmese
    'my': 'Burmese',
    'bur': 'Burmese',
    'mya': 'Burmese',

    // Lao
    'lo': 'Lao',
    'lao': 'Lao',

    // Khmer
    'km': 'Khmer',
    'khm': 'Khmer',
  };

  /// Get display name for a language code
  /// Returns the language code itself if not found in the map
  static String getLanguageName(String code) {
    final lowerCode = code.toLowerCase();
    return languageNames[lowerCode] ?? code.toUpperCase();
  }

  /// Normalize language code (convert to 3-letter ISO 639-2 code when possible)
  /// For English, returns null to use default (no language code in filename)
  static String? normalizeLanguageCode(String code) {
    final lowerCode = code.toLowerCase();

    // English is default, no need for language code
    if (lowerCode == 'en' || lowerCode == 'eng') {
      return null; // null means default English
    }

    // Map 2-letter codes to 3-letter codes
    const Map<String, String> twoToThree = {
      'zh': 'chi',
      'es': 'spa',
      'fr': 'fra',
      'de': 'deu',
      'ja': 'jpn',
      'ko': 'kor',
      'th': 'tha',
      'vi': 'vie',
      'ar': 'ara',
      'pt': 'por',
      'ru': 'rus',
      'it': 'ita',
      'nl': 'nld',
      'pl': 'pol',
      'tr': 'tur',
      'sv': 'swe',
      'da': 'dan',
      'fi': 'fin',
      'no': 'nor',
      'el': 'ell',
      'cs': 'ces',
      'hu': 'hun',
      'ro': 'ron',
      'hi': 'hin',
      'id': 'ind',
      'ms': 'msa',
      'tl': 'fil',
      'he': 'heb',
      'uk': 'ukr',
      'bn': 'ben',
      'my': 'mya',
      'lo': 'lao',
      'km': 'khm',
    };

    // If it's a 2-letter code, convert to 3-letter
    if (lowerCode.length == 2 && twoToThree.containsKey(lowerCode)) {
      return twoToThree[lowerCode];
    }

    // Return as-is if already 3 letters or unknown
    return lowerCode;
  }

  /// Build subtitle filename: videoFileName.langCode.srt
  /// For English (default), returns: videoFileName.srt
  /// For others, returns: videoFileName.tha.srt, videoFileName.chi.srt, etc.
  static String buildSubtitleFileName(
      String videoFileName, String? languageCode) {
    // Remove video extension
    final baseFileName = videoFileName.replaceAll(RegExp(r'\.[^.]+$'), '');

    // If language code is null or empty (English), no language suffix
    if (languageCode == null || languageCode.isEmpty) {
      return '$baseFileName.srt';
    }

    // Otherwise, add language code before .srt
    return '$baseFileName.$languageCode.srt';
  }

  /// Parse subtitle filename to extract language code
  /// e.g., "video.tha.srt" -> "tha", "video.srt" -> null (default English)
  static String? parseLanguageFromFilename(String filename) {
    final parts = filename.split('.');

    // Need at least 2 parts: name.srt
    if (parts.length < 2) return null;

    // If only 2 parts (name.srt), it's default English
    if (parts.length == 2) return null;

    // If 3+ parts, second-to-last is the language code
    // e.g., video.tha.srt -> parts = ['video', 'tha', 'srt']
    final langCode = parts[parts.length - 2];

    // Validate it looks like a language code (2-3 letters)
    if (langCode.length >= 2 && langCode.length <= 3) {
      return langCode;
    }

    return null;
  }
}
