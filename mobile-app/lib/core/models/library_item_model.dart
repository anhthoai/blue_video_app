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
}

