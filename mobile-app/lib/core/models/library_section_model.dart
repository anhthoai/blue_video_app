class LibrarySectionModel {
  final String section;
  final int totalItems;
  final String syncStatus;
  final DateTime? lastSyncAt;
  final bool isSyncing;

  LibrarySectionModel({
    required this.section,
    required this.totalItems,
    this.syncStatus = 'idle',
    this.lastSyncAt,
    this.isSyncing = false,
  });

  factory LibrarySectionModel.fromJson(Map<String, dynamic> json) {
    DateTime? parsedLastSync;
    final rawLastSync = json['lastSyncAt'] ?? json['last_sync_at'];
    if (rawLastSync != null) {
      parsedLastSync = DateTime.tryParse(rawLastSync.toString());
    }
    return LibrarySectionModel(
      section: (json['section'] ?? '').toString(),
      totalItems: (json['_count']?['section'] ??
              json['totalItems'] ??
              json['total_items'] ??
              json['count'] ??
              0) as int,
      syncStatus: (json['syncStatus'] ?? json['sync_status'] ?? 'idle').toString(),
      lastSyncAt: parsedLastSync,
      isSyncing: json['isSyncing'] == true || json['is_syncing'] == true,
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
    if (isSyncing && totalItems <= 0) return '$displayName (syncing…)';
    if (totalItems <= 0) return displayName;
    return '$displayName ($totalItems)';
  }

  /// Human-readable relative time since last sync, or null if never synced.
  String? get lastSyncRelative {
    if (lastSyncAt == null) return null;
    final diff = DateTime.now().difference(lastSyncAt!);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

