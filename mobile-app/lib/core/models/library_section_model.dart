class LibrarySectionModel {
  final String section;
  final int totalItems;

  LibrarySectionModel({
    required this.section,
    required this.totalItems,
  });

  factory LibrarySectionModel.fromJson(Map<String, dynamic> json) {
    return LibrarySectionModel(
      section: (json['section'] ?? '').toString(),
      totalItems: (json['_count']?['section'] ??
              json['totalItems'] ??
              json['total_items'] ??
              json['count'] ??
              0) as int,
    );
  }

  String get displayName {
    if (section.isEmpty) return 'Unknown';
    return section
        .split(RegExp(r'[-_]+'))
        .where((part) => part.isNotEmpty)
        .map((part) =>
            part.substring(0, 1).toUpperCase() + part.substring(1).toLowerCase())
        .join(' ');
  }

  String get displayLabel {
    if (totalItems <= 0) return displayName;
    return '$displayName ($totalItems)';
  }
}

