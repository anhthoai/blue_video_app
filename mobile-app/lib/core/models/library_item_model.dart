class LibraryItemModel {
  final String id;
  final String title;
  final String? description;
  final String contentType;
  final String section;
  final bool isFolder;
  final String? fileUrl;
  final String? filePath;
  final String? slugPath;
  final String? thumbnailUrl;
  final String? coverUrl;
  final String? mimeType;
  final String? streamUrl;
  final String? source;
  final String? ulozSlug;
  final bool hasChildren;
  final String? extension;
  final int? duration;
  final int? fileSize;
  final Map<String, dynamic> metadata;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  LibraryItemModel({
    required this.id,
    required this.title,
    required this.contentType,
    required this.section,
    required this.isFolder,
    this.description,
    this.fileUrl,
    this.filePath,
    this.slugPath,
    this.thumbnailUrl,
    this.coverUrl,
    this.mimeType,
    this.streamUrl,
    this.source,
    this.ulozSlug,
    this.hasChildren = false,
    this.extension,
    this.duration,
    this.fileSize,
    Map<String, dynamic>? metadata,
    this.createdAt,
    this.updatedAt,
  }) : metadata = metadata ?? const {};

  factory LibraryItemModel.fromJson(Map<String, dynamic> json) {
    int? parseFileSize(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value);
      return null;
    }

    Map<String, dynamic> parseMetadata(dynamic value) {
      if (value is Map) {
        return value.cast<String, dynamic>();
      }
      return const <String, dynamic>{};
    }

    return LibraryItemModel(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      description: json['description']?.toString(),
      contentType: (json['contentType'] ?? '').toString(),
      section: (json['section'] ?? '').toString(),
      isFolder: json['isFolder'] == true,
      fileUrl: json['fileUrl']?.toString(),
      streamUrl: json['streamUrl']?.toString(),
      filePath: json['filePath']?.toString(),
      slugPath: json['slugPath']?.toString(),
      thumbnailUrl: json['thumbnailUrl']?.toString(),
      coverUrl: json['coverUrl']?.toString(),
      mimeType: json['mimeType']?.toString(),
      source: json['source']?.toString(),
      ulozSlug: json['ulozSlug']?.toString(),
      hasChildren: json['hasChildren'] == true,
      extension: json['extension']?.toString(),
      duration: json['duration'] is num
          ? (json['duration'] as num).toInt()
          : int.tryParse(json['duration']?.toString() ?? ''),
      fileSize: parseFileSize(json['fileSize'] ?? json['file_size']),
      metadata: parseMetadata(json['metadata']),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
    );
  }

  String get displayTitle {
    if (title.isNotEmpty) return title;
    if (filePath != null && filePath!.isNotEmpty) {
      return filePath!.split('/').last;
    }
    return 'Untitled';
  }

  String? get imageUrl {
    if (thumbnailUrl != null && thumbnailUrl!.isNotEmpty) {
      return thumbnailUrl;
    }
    if (coverUrl != null && coverUrl!.isNotEmpty) {
      return coverUrl;
    }
    return null;
  }

  String get formattedDuration {
    if (duration == null || duration! <= 0) return '';
    final d = Duration(seconds: duration!);
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(d.inHours);
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    if (d.inHours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  String get formattedFileSize {
    if (fileSize == null || fileSize! <= 0) return '';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var s = fileSize!.toDouble();
    var i = 0;
    while (s >= 1024 && i < suffixes.length - 1) {
      s /= 1024;
      i++;
    }
    return '${s.toStringAsFixed(1)} ${suffixes[i]}';
  }

  // For subtitle files, extract language information
  String get languageLabel {
    // Check metadata first
    final metaLang = metadata['language']?.toString();
    if (metaLang != null && metaLang.isNotEmpty) {
      return _languageCodeToLabel(metaLang);
    }

    // Extract from filename
    final name = displayTitle.toLowerCase();
    final path = (filePath ?? '').toLowerCase();
    final combined = '$name $path';

    // Check for language patterns
    if (combined.contains('.eng.') || combined.endsWith('.eng') ||
        combined.contains('_eng.') || combined.endsWith('_eng') ||
        combined.contains('english')) {
      return 'English';
    }
    if (combined.contains('.chi.') || combined.endsWith('.chi') ||
        combined.contains('_chi.') || combined.endsWith('_chi') ||
        combined.contains('chinese')) {
      return 'Chinese';
    }
    if (combined.contains('.spa.') || combined.endsWith('.spa') ||
        combined.contains('_spa.') || combined.endsWith('_spa') ||
        combined.contains('spanish')) {
      return 'Spanish';
    }
    if (combined.contains('.ind.') || combined.endsWith('.ind') ||
        combined.contains('_ind.') || combined.endsWith('_ind') ||
        combined.contains('indonesian')) {
      return 'Indonesian';
    }
    if (combined.contains('.tha.') || combined.endsWith('.tha') ||
        combined.contains('_tha.') || combined.endsWith('_tha') ||
        combined.contains('thai')) {
      return 'Thai';
    }

    // Try to extract from filename parts (skip numeric parts)
    final parts = displayTitle.split('.');
    if (parts.length >= 2) {
      final potentialLang = parts[parts.length - 2];
      if (potentialLang.length >= 2 && potentialLang.length <= 4 &&
          !RegExp(r'^\d+$').hasMatch(potentialLang)) {
        return _languageCodeToLabel(potentialLang);
      }
    }

    return 'English'; // Default
  }

  String get flagEmoji {
    final lang = languageLabel.toLowerCase();
    switch (lang) {
      case 'english': return '🇬🇧';
      case 'chinese': return '🇨🇳';
      case 'spanish': return '🇪🇸';
      case 'indonesian': return '🇮🇩';
      case 'thai': return '🇹🇭';
      case 'vietnamese': return '🇻🇳';
      case 'japanese': return '🇯🇵';
      case 'korean': return '🇰🇷';
      case 'french': return '🇫🇷';
      case 'german': return '🇩🇪';
      case 'italian': return '🇮🇹';
      case 'portuguese': return '🇵🇹';
      case 'russian': return '🇷🇺';
      case 'arabic': return '🇸🇦';
      case 'hindi': return '🇮🇳';
      case 'turkish': return '🇹🇷';
      case 'dutch': return '🇳🇱';
      case 'polish': return '🇵🇱';
      case 'swedish': return '🇸🇪';
      case 'norwegian': return '🇳🇴';
      case 'danish': return '🇩🇰';
      case 'finnish': return '🇫🇮';
      case 'greek': return '🇬🇷';
      case 'hebrew': return '🇮🇱';
      case 'czech': return '🇨🇿';
      case 'hungarian': return '🇭🇺';
      case 'romanian': return '🇷🇴';
      case 'ukrainian': return '🇺🇦';
      default: return '🌐';
    }
  }

  String get languageCode {
    final metaLang = metadata['language']?.toString();
    if (metaLang != null && metaLang.isNotEmpty) {
      return metaLang.toUpperCase();
    }

    final lang = languageLabel.toLowerCase();
    switch (lang) {
      case 'english': return 'ENG';
      case 'chinese': return 'CHI';
      case 'spanish': return 'SPA';
      case 'indonesian': return 'IND';
      case 'thai': return 'THA';
      case 'vietnamese': return 'VIE';
      case 'japanese': return 'JPN';
      case 'korean': return 'KOR';
      case 'french': return 'FRA';
      case 'german': return 'GER';
      case 'italian': return 'ITA';
      case 'portuguese': return 'POR';
      case 'russian': return 'RUS';
      case 'arabic': return 'ARA';
      case 'hindi': return 'HIN';
      case 'turkish': return 'TUR';
      case 'dutch': return 'DUT';
      case 'polish': return 'POL';
      case 'swedish': return 'SWE';
      case 'norwegian': return 'NOR';
      case 'danish': return 'DAN';
      case 'finnish': return 'FIN';
      case 'greek': return 'GRE';
      case 'hebrew': return 'HEB';
      case 'czech': return 'CZE';
      case 'hungarian': return 'HUN';
      case 'romanian': return 'ROM';
      case 'ukrainian': return 'UKR';
      default: return 'SUB';
    }
  }

  static String _languageCodeToLabel(String code) {
    final c = code.toLowerCase();
    switch (c) {
      case 'eng': case 'en': return 'English';
      case 'chi': case 'zh': case 'zho': return 'Chinese';
      case 'spa': case 'es': return 'Spanish';
      case 'ind': case 'id': return 'Indonesian';
      case 'tha': case 'th': return 'Thai';
      case 'vie': case 'vi': return 'Vietnamese';
      case 'jpn': case 'ja': return 'Japanese';
      case 'kor': case 'ko': return 'Korean';
      case 'fra': case 'fre': case 'fr': return 'French';
      case 'ger': case 'deu': case 'de': return 'German';
      case 'ita': case 'it': return 'Italian';
      case 'por': case 'pt': return 'Portuguese';
      case 'rus': case 'ru': return 'Russian';
      case 'ara': case 'ar': return 'Arabic';
      case 'hin': case 'hi': return 'Hindi';
      case 'tur': case 'tr': return 'Turkish';
      case 'dut': case 'nld': case 'nl': return 'Dutch';
      case 'pol': case 'pl': return 'Polish';
      case 'swe': case 'sv': return 'Swedish';
      case 'nor': case 'no': return 'Norwegian';
      case 'dan': case 'da': return 'Danish';
      case 'fin': case 'fi': return 'Finnish';
      case 'gre': case 'ell': case 'el': return 'Greek';
      case 'heb': case 'he': return 'Hebrew';
      case 'cze': case 'ces': case 'cs': return 'Czech';
      case 'hun': case 'hu': return 'Hungarian';
      case 'rom': case 'ron': case 'ro': return 'Romanian';
      case 'ukr': case 'uk': return 'Ukrainian';
      default:
        // If it's a short code we don't recognize, just capitalize it
        if (c.length <= 4) return c.toUpperCase();
        return code;
    }
  }
}

