class MovieModel {
  final String id;
  final String? imdbId;
  final String? tmdbId;
  final String? tvdbId;

  // Basic Info
  final String title;
  final List<AlternativeTitle>? alternativeTitles;
  final String slug;
  final String? overview;
  final String? tagline;

  // Media
  final String? posterUrl;
  final String? backdropUrl;
  final List<String>? photos;
  final String? trailerUrl;

  // Classification
  final String contentType; // 'MOVIE', 'TV_SERIES', 'SHORT'
  final DateTime? releaseDate;
  final DateTime? endDate;
  final int? runtime; // In minutes

  // Categories
  final List<String>? genres;
  final List<String>? countries;
  final List<String>? languages;
  final bool isAdult;

  // LGBTQ+ Classification
  final List<String>?
      lgbtqTypes; // ['gay', 'lesbian', 'bisexual', 'transgender', 'queer']

  // Credits
  final List<Credit>? directors;
  final List<Credit>? writers;
  final List<Credit>? producers;
  final List<Actor>? actors;

  // Statistics
  final double? voteAverage;
  final int? voteCount;
  final double? popularity;
  final int views;

  // Status
  final String status; // 'RELEASED', 'IN_PRODUCTION', etc.

  // Metadata
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdBy;

  // Relations
  final List<MovieEpisode>? episodes;

  MovieModel({
    required this.id,
    this.imdbId,
    this.tmdbId,
    this.tvdbId,
    required this.title,
    this.alternativeTitles,
    required this.slug,
    this.overview,
    this.tagline,
    this.posterUrl,
    this.backdropUrl,
    this.photos,
    this.trailerUrl,
    required this.contentType,
    this.releaseDate,
    this.endDate,
    this.runtime,
    this.genres,
    this.countries,
    this.languages,
    this.isAdult = false,
    this.lgbtqTypes,
    this.directors,
    this.writers,
    this.producers,
    this.actors,
    this.voteAverage,
    this.voteCount,
    this.popularity,
    this.views = 0,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
    this.episodes,
  });

  factory MovieModel.fromJson(Map<String, dynamic> json) {
    return MovieModel(
      id: json['id'] as String,
      imdbId: json['imdbId'] as String?,
      tmdbId: json['tmdbId'] as String?,
      tvdbId: json['tvdbId'] as String?,
      title: json['title'] as String,
      alternativeTitles: json['alternativeTitles'] != null
          ? (json['alternativeTitles'] as List)
              .map((e) => AlternativeTitle.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
      slug: json['slug'] as String,
      overview: json['overview'] as String?,
      tagline: json['tagline'] as String?,
      posterUrl: json['posterUrl'] as String?,
      backdropUrl: json['backdropUrl'] as String?,
      photos: json['photos'] != null
          ? List<String>.from(json['photos'] as List)
          : null,
      trailerUrl: json['trailerUrl'] as String?,
      contentType: json['contentType'] as String,
      releaseDate: json['releaseDate'] != null
          ? DateTime.parse(json['releaseDate'] as String)
          : null,
      endDate: json['endDate'] != null
          ? DateTime.parse(json['endDate'] as String)
          : null,
      runtime: json['runtime'] as int?,
      genres: json['genres'] != null
          ? List<String>.from(json['genres'] as List)
          : null,
      countries: json['countries'] != null
          ? List<String>.from(json['countries'] as List)
          : null,
      languages: json['languages'] != null
          ? List<String>.from(json['languages'] as List)
          : null,
      isAdult: json['isAdult'] as bool? ?? false,
      lgbtqTypes: json['lgbtqTypes'] != null
          ? List<String>.from(json['lgbtqTypes'] as List)
          : null,
      directors: json['directors'] != null
          ? (json['directors'] as List)
              .map((e) => Credit.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
      writers: json['writers'] != null
          ? (json['writers'] as List)
              .map((e) => Credit.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
      producers: json['producers'] != null
          ? (json['producers'] as List)
              .map((e) => Credit.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
      actors: json['actors'] != null
          ? (json['actors'] as List)
              .map((e) => Actor.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
      voteAverage: json['voteAverage'] != null
          ? (json['voteAverage'] as num).toDouble()
          : null,
      voteCount: json['voteCount'] as int?,
      popularity: json['popularity'] != null
          ? (json['popularity'] as num).toDouble()
          : null,
      views: json['views'] as int? ?? 0,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      createdBy: json['createdBy'] as String?,
      episodes: json['episodes'] != null
          ? (json['episodes'] as List)
              .map((e) => MovieEpisode.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'imdbId': imdbId,
      'tmdbId': tmdbId,
      'tvdbId': tvdbId,
      'title': title,
      'alternativeTitles': alternativeTitles?.map((e) => e.toJson()).toList(),
      'slug': slug,
      'overview': overview,
      'tagline': tagline,
      'posterUrl': posterUrl,
      'backdropUrl': backdropUrl,
      'photos': photos,
      'trailerUrl': trailerUrl,
      'contentType': contentType,
      'releaseDate': releaseDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'runtime': runtime,
      'genres': genres,
      'countries': countries,
      'languages': languages,
      'isAdult': isAdult,
      'lgbtqTypes': lgbtqTypes,
      'directors': directors?.map((e) => e.toJson()).toList(),
      'writers': writers?.map((e) => e.toJson()).toList(),
      'producers': producers?.map((e) => e.toJson()).toList(),
      'actors': actors?.map((e) => e.toJson()).toList(),
      'voteAverage': voteAverage,
      'voteCount': voteCount,
      'popularity': popularity,
      'views': views,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'createdBy': createdBy,
      'episodes': episodes?.map((e) => e.toJson()).toList(),
    };
  }

  // Helper getters
  String get releaseYear =>
      releaseDate != null ? releaseDate!.year.toString() : 'TBA';

  String get formattedRuntime {
    if (runtime == null) return '';
    final hours = runtime! ~/ 60;
    final minutes = runtime! % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  String get displayType {
    switch (contentType) {
      case 'MOVIE':
        return 'Movie';
      case 'TV_SERIES':
        return 'TV Series';
      case 'SHORT':
        return 'Short';
      default:
        return contentType;
    }
  }
}

class AlternativeTitle {
  final String title;
  final String? country;
  final String? language;
  final String? type;

  AlternativeTitle({
    required this.title,
    this.country,
    this.language,
    this.type,
  });

  factory AlternativeTitle.fromJson(Map<String, dynamic> json) {
    return AlternativeTitle(
      title: json['title'] as String,
      country: json['country'] as String?,
      language: json['language'] as String?,
      type: json['type'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'country': country,
      'language': language,
      'type': type,
    };
  }
}

class Credit {
  final String? id;
  final String name;

  Credit({
    this.id,
    required this.name,
  });

  factory Credit.fromJson(Map<String, dynamic> json) {
    return Credit(
      id: json['id'] as String?,
      name: json['name'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
    };
  }
}

class Actor {
  final String? id;
  final String name;
  final String? character;
  final int? order;
  final String? profileUrl;

  Actor({
    this.id,
    required this.name,
    this.character,
    this.order,
    this.profileUrl,
  });

  factory Actor.fromJson(Map<String, dynamic> json) {
    return Actor(
      id: json['id'] as String?,
      name: json['name'] as String,
      character: json['character'] as String?,
      order: json['order'] as int?,
      profileUrl: json['profileUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'character': character,
      'order': order,
      'profileUrl': profileUrl,
    };
  }
}

class Subtitle {
  final String id;
  final String episodeId;
  final String language; // ISO 639-2 code
  final String label; // Display name
  final String slug;
  final String fileUrl;
  final String source;
  final DateTime createdAt;
  final DateTime updatedAt;

  Subtitle({
    required this.id,
    required this.episodeId,
    required this.language,
    required this.label,
    required this.slug,
    required this.fileUrl,
    required this.source,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Subtitle.fromJson(Map<String, dynamic> json) {
    return Subtitle(
      id: json['id'] as String,
      episodeId: json['episodeId'] as String,
      language: json['language'] as String,
      label: json['label'] as String,
      slug: json['slug'] as String,
      fileUrl: json['fileUrl'] as String,
      source: json['source'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'episodeId': episodeId,
      'language': language,
      'label': label,
      'slug': slug,
      'fileUrl': fileUrl,
      'source': source,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  // Helper to get flag emoji for language
  String get flagEmoji {
    final flagMap = {
      'eng': '🇬🇧',
      'tha': '🇹🇭',
      'jpn': '🇯🇵',
      'kor': '🇰🇷',
      'chi': '🇨🇳',
      'zho': '🇹🇼',
      'spa': '🇪🇸',
      'fre': '🇫🇷',
      'fra': '🇫🇷',
      'ger': '🇩🇪',
      'deu': '🇩🇪',
      'ita': '🇮🇹',
      'por': '🇵🇹',
      'rus': '🇷🇺',
      'ara': '🇸🇦',
      'hin': '🇮🇳',
      'vie': '🇻🇳',
      'dut': '🇳🇱',
      'nld': '🇳🇱',
      'pol': '🇵🇱',
      'cze': '🇨🇿',
      'ces': '🇨🇿',
      'hun': '🇭🇺',
      'gre': '🇬🇷',
      'ell': '🇬🇷',
      'rum': '🇷🇴',
      'ron': '🇷🇴',
      'tur': '🇹🇷',
    };
    return flagMap[language.toLowerCase()] ?? '🌐';
  }
}

class MovieEpisode {
  final String id;
  final String movieId;

  // Episode Info
  final int episodeNumber;
  final int seasonNumber;
  final String? title;
  final String? overview;

  // Media
  final String? thumbnailUrl;
  final String? videoPreviewUrl;
  final int? duration; // In seconds

  // File Source
  final String source; // 'UPLOAD', 'ULOZ', 'EXTERNAL'
  final String? slug;
  final String? folderSlug;
  final String? parentFolderSlug;
  final String? fileUrl;
  final String? streamUrl;
  final String? contentType;
  final String? extension;
  final int? fileSize;

  // Dates
  final DateTime? airDate;

  // Statistics
  final int views;

  // Status
  final bool isAvailable;

  // Metadata
  final DateTime createdAt;
  final DateTime updatedAt;

  // Subtitles
  final List<Subtitle>? subtitles;

  MovieEpisode({
    required this.id,
    required this.movieId,
    required this.episodeNumber,
    required this.seasonNumber,
    this.title,
    this.overview,
    this.thumbnailUrl,
    this.videoPreviewUrl,
    this.duration,
    required this.source,
    this.slug,
    this.folderSlug,
    this.parentFolderSlug,
    this.fileUrl,
    this.streamUrl,
    this.contentType,
    this.extension,
    this.fileSize,
    this.airDate,
    this.views = 0,
    this.isAvailable = true,
    required this.createdAt,
    required this.updatedAt,
    this.subtitles,
  });

  factory MovieEpisode.fromJson(Map<String, dynamic> json) {
    return MovieEpisode(
      id: json['id'] as String,
      movieId: json['movieId'] as String,
      episodeNumber: json['episodeNumber'] as int,
      seasonNumber: json['seasonNumber'] as int,
      title: json['title'] as String?,
      overview: json['overview'] as String?,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      videoPreviewUrl: json['videoPreviewUrl'] as String?,
      duration: json['duration'] != null
          ? (json['duration'] is String
              ? int.tryParse(json['duration'])
              : json['duration'] as int?)
          : null,
      source: json['source'] as String,
      slug: json['slug'] as String?,
      folderSlug: json['folderSlug'] as String?,
      parentFolderSlug: json['parentFolderSlug'] as String?,
      fileUrl: json['fileUrl'] as String?,
      streamUrl: json['streamUrl'] as String?,
      contentType: json['contentType'] as String?,
      extension: json['extension'] as String?,
      fileSize: json['fileSize'] != null
          ? (json['fileSize'] is String
              ? int.tryParse(json['fileSize'])
              : json['fileSize'] as int?)
          : null,
      airDate: json['airDate'] != null
          ? DateTime.parse(json['airDate'] as String)
          : null,
      views: json['views'] as int? ?? 0,
      isAvailable: json['isAvailable'] as bool? ?? true,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      subtitles: json['subtitles'] != null
          ? (json['subtitles'] as List)
              .map((e) => Subtitle.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'movieId': movieId,
      'episodeNumber': episodeNumber,
      'seasonNumber': seasonNumber,
      'title': title,
      'overview': overview,
      'thumbnailUrl': thumbnailUrl,
      'videoPreviewUrl': videoPreviewUrl,
      'duration': duration,
      'source': source,
      'slug': slug,
      'folderSlug': folderSlug,
      'parentFolderSlug': parentFolderSlug,
      'fileUrl': fileUrl,
      'streamUrl': streamUrl,
      'contentType': contentType,
      'extension': extension,
      'fileSize': fileSize,
      'airDate': airDate?.toIso8601String(),
      'views': views,
      'isAvailable': isAvailable,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'subtitles': subtitles?.map((e) => e.toJson()).toList(),
    };
  }

  // Helper getters
  String get formattedDuration {
    if (duration == null) return '';
    final hours = duration! ~/ 3600;
    final minutes = (duration! % 3600) ~/ 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  String get formattedDurationFull {
    if (duration == null) return '';
    final hours = duration! ~/ 3600;
    final minutes = (duration! % 3600) ~/ 60;
    final seconds = duration! % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(1, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }

  String get episodeLabel =>
      'S${seasonNumber.toString().padLeft(2, '0')}E${episodeNumber.toString().padLeft(2, '0')}';
}
