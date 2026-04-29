import 'community_post.dart';

enum CommunityRequestStatus { open, ended }

enum CommunityRequestSubmissionType { fileUpload, linkedVideo }

enum CommunityLinkedMediaPreviewKind { image, video, audio, file, external }

enum CreatorMetricTab { likes, uploads, earnings }

enum CreatorLeaderboardWindow { daily, weekly, monthly }

class CommunityForum {
  final String id;
  final String slug;
  final String title;
  final String subtitle;
  final String description;
  final int postCount;
  final int followerCount;
  final List<String> memberNames;
  final List<String> keywords;
  final String accentStart;
  final String accentEnd;
  final bool isFollowing;
  final bool isHot;

  const CommunityForum({
    required this.id,
    this.slug = '',
    required this.title,
    required this.subtitle,
    this.description = '',
    required this.postCount,
    this.followerCount = 0,
    this.memberNames = const <String>[],
    this.keywords = const <String>[],
    this.accentStart = '#4F7DFF',
    this.accentEnd = '#5FD4FF',
    this.isFollowing = false,
    this.isHot = false,
  });

  factory CommunityForum.fromJson(Map<String, dynamic> json) {
    return CommunityForum(
      id: (json['id'] ?? '').toString(),
      slug: (json['slug'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      subtitle: (json['subtitle'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      postCount: _toInt(json['postCount']),
      followerCount: _toInt(json['followerCount']),
      memberNames: _toStringList(json['memberNames']),
      keywords: _toStringList(json['keywords']),
      accentStart: (json['accentStart'] ?? '#4F7DFF').toString(),
      accentEnd: (json['accentEnd'] ?? '#5FD4FF').toString(),
      isFollowing: json['isFollowing'] == true,
      isHot: json['isHot'] == true,
    );
  }

  CommunityForum copyWith({
    String? id,
    String? slug,
    String? title,
    String? subtitle,
    String? description,
    int? postCount,
    int? followerCount,
    List<String>? memberNames,
    List<String>? keywords,
    String? accentStart,
    String? accentEnd,
    bool? isFollowing,
    bool? isHot,
  }) {
    return CommunityForum(
      id: id ?? this.id,
      slug: slug ?? this.slug,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      description: description ?? this.description,
      postCount: postCount ?? this.postCount,
      followerCount: followerCount ?? this.followerCount,
      memberNames: memberNames ?? this.memberNames,
      keywords: keywords ?? this.keywords,
      accentStart: accentStart ?? this.accentStart,
      accentEnd: accentEnd ?? this.accentEnd,
      isFollowing: isFollowing ?? this.isFollowing,
      isHot: isHot ?? this.isHot,
    );
  }
}

class CommunityCreatorStats {
  final int likes;
  final int uploads;
  final int earnings;

  const CommunityCreatorStats({
    required this.likes,
    required this.uploads,
    required this.earnings,
  });

  factory CommunityCreatorStats.fromJson(Map<String, dynamic> json) {
    return CommunityCreatorStats(
      likes: _toInt(json['likes']),
      uploads: _toInt(json['uploads']),
      earnings: _toInt(json['earnings']),
    );
  }

  int metricValue(CreatorMetricTab metricTab) {
    switch (metricTab) {
      case CreatorMetricTab.likes:
        return likes;
      case CreatorMetricTab.uploads:
        return uploads;
      case CreatorMetricTab.earnings:
        return earnings;
    }
  }
}

class CommunityCreator {
  final String id;
  final String displayName;
  final String handle;
  final String? avatarUrl;
  final int followers;
  final bool isFollowing;
  final String highlight;
  final Map<CreatorLeaderboardWindow, CommunityCreatorStats> stats;

  const CommunityCreator({
    required this.id,
    required this.displayName,
    required this.handle,
    this.avatarUrl,
    required this.followers,
    this.isFollowing = false,
    required this.highlight,
    required this.stats,
  });

  factory CommunityCreator.fromJson(Map<String, dynamic> json) {
    final statsJson = json['stats'] is Map<String, dynamic>
        ? json['stats'] as Map<String, dynamic>
        : <String, dynamic>{};

    return CommunityCreator(
      id: (json['id'] ?? '').toString(),
      displayName: (json['displayName'] ?? '').toString(),
      handle: (json['handle'] ?? '').toString(),
      avatarUrl: json['avatarUrl'] as String?,
      followers: _toInt(json['followers']),
      isFollowing: json['isFollowing'] == true,
      highlight: (json['highlight'] ?? '').toString(),
      stats: <CreatorLeaderboardWindow, CommunityCreatorStats>{
        CreatorLeaderboardWindow.daily: CommunityCreatorStats.fromJson(
          _asMap(statsJson['daily']),
        ),
        CreatorLeaderboardWindow.weekly: CommunityCreatorStats.fromJson(
          _asMap(statsJson['weekly']),
        ),
        CreatorLeaderboardWindow.monthly: CommunityCreatorStats.fromJson(
          _asMap(statsJson['monthly']),
        ),
      },
    );
  }

  CommunityCreatorStats statsFor(CreatorLeaderboardWindow window) {
    return stats[window] ??
        const CommunityCreatorStats(likes: 0, uploads: 0, earnings: 0);
  }

  int metricValue(
    CreatorLeaderboardWindow window,
    CreatorMetricTab metricTab,
  ) {
    return statsFor(window).metricValue(metricTab);
  }

  CommunityCreator copyWith({
    String? id,
    String? displayName,
    String? handle,
    Object? avatarUrl = _communityCreatorAvatarSentinel,
    int? followers,
    bool? isFollowing,
    String? highlight,
    Map<CreatorLeaderboardWindow, CommunityCreatorStats>? stats,
  }) {
    return CommunityCreator(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      handle: handle ?? this.handle,
      avatarUrl: avatarUrl == _communityCreatorAvatarSentinel
          ? this.avatarUrl
          : avatarUrl as String?,
      followers: followers ?? this.followers,
      isFollowing: isFollowing ?? this.isFollowing,
      highlight: highlight ?? this.highlight,
      stats: stats ?? this.stats,
    );
  }
}

const Object _communityCreatorAvatarSentinel = Object();

class CommunityLinkedMedia {
  final String sourceType;
  final CommunityLinkedMediaPreviewKind previewKind;
  final String? itemId;
  final String? section;
  final String? title;
  final String? subtitle;
  final String? contentType;
  final String? thumbnailUrl;
  final String? streamUrl;
  final String? fileUrl;
  final String? externalUrl;
  final String? mimeType;
  final String? extension;

  const CommunityLinkedMedia({
    required this.sourceType,
    required this.previewKind,
    this.itemId,
    this.section,
    this.title,
    this.subtitle,
    this.contentType,
    this.thumbnailUrl,
    this.streamUrl,
    this.fileUrl,
    this.externalUrl,
    this.mimeType,
    this.extension,
  });

  factory CommunityLinkedMedia.fromJson(Map<String, dynamic> json) {
    return CommunityLinkedMedia(
      sourceType: (json['sourceType'] ?? '').toString(),
      previewKind: _parseLinkedMediaPreviewKind(json['previewKind']),
      itemId: _cleanOptionalString(json['itemId']),
      section: _cleanOptionalString(json['section']),
      title: _cleanOptionalString(json['title']),
      subtitle: _cleanOptionalString(json['subtitle']),
      contentType: _cleanOptionalString(json['contentType']),
      thumbnailUrl: _cleanOptionalString(json['thumbnailUrl']),
      streamUrl: _cleanOptionalString(json['streamUrl']),
      fileUrl: _cleanOptionalString(json['fileUrl']),
      externalUrl: _cleanOptionalString(json['externalUrl']),
      mimeType: _cleanOptionalString(json['mimeType']),
      extension: _cleanOptionalString(json['extension']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'sourceType': sourceType,
      'previewKind': _linkedMediaPreviewKindValue(previewKind),
      'itemId': itemId,
      'section': section,
      'title': title,
      'subtitle': subtitle,
      'contentType': contentType,
      'thumbnailUrl': thumbnailUrl,
      'streamUrl': streamUrl,
      'fileUrl': fileUrl,
      'externalUrl': externalUrl,
      'mimeType': mimeType,
      'extension': extension,
    };
  }

  bool get isLibraryItem => sourceType.toLowerCase() == 'libraryitem';

  String get displayTitle {
    final trimmedTitle = title?.trim();
    if (trimmedTitle != null && trimmedTitle.isNotEmpty) {
      return trimmedTitle;
    }
    return 'Linked media';
  }

  String? get primaryUrl {
    final stream = streamUrl?.trim();
    if (stream != null && stream.isNotEmpty) {
      return stream;
    }

    final file = fileUrl?.trim();
    if (file != null && file.isNotEmpty) {
      return file;
    }

    final external = externalUrl?.trim();
    if (external != null && external.isNotEmpty) {
      return external;
    }

    return null;
  }

  String? get previewImageUrl {
    final thumbnail = thumbnailUrl?.trim();
    if (thumbnail != null && thumbnail.isNotEmpty) {
      return thumbnail;
    }

    if (previewKind == CommunityLinkedMediaPreviewKind.image) {
      return primaryUrl;
    }

    return null;
  }
}

class CommunityRequestSubmission {
  final String id;
  final String requestId;
  final String contributorId;
  final String contributorName;
  final String? contributorAvatarUrl;
  final String title;
  final String description;
  final CommunityRequestSubmissionType type;
  final String? linkedVideoUrl;
  final CommunityLinkedMedia? linkedMedia;
  final String? searchKeyword;
  final String? fileName;
  final String? fileUrl;
  final String? mimeType;
  final int likes;
  final int comments;
  final int playCount;
  final bool isApproved;
  final bool isFollowingContributor;
  final DateTime createdAt;

  const CommunityRequestSubmission({
    required this.id,
    required this.requestId,
    required this.contributorId,
    required this.contributorName,
    this.contributorAvatarUrl,
    required this.title,
    required this.description,
    required this.type,
    this.linkedVideoUrl,
    this.linkedMedia,
    this.searchKeyword,
    this.fileName,
    this.fileUrl,
    this.mimeType,
    this.likes = 0,
    this.comments = 0,
    this.playCount = 0,
    this.isApproved = false,
    this.isFollowingContributor = false,
    required this.createdAt,
  });

  factory CommunityRequestSubmission.fromJson(Map<String, dynamic> json) {
    final linkedMediaJson = json['linkedMedia'] ?? json['linkedMediaMetadata'];

    return CommunityRequestSubmission(
      id: (json['id'] ?? '').toString(),
      requestId: (json['requestId'] ?? '').toString(),
      contributorId: (json['contributorId'] ?? '').toString(),
      contributorName: (json['contributorName'] ?? '').toString(),
      contributorAvatarUrl: json['contributorAvatarUrl'] as String?,
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      type: _parseSubmissionType(json['type']),
      linkedVideoUrl: json['linkedVideoUrl'] as String?,
        linkedMedia: linkedMediaJson is Map
          ? CommunityLinkedMedia.fromJson(_asMap(linkedMediaJson))
          : null,
      searchKeyword: json['searchKeyword'] as String?,
      fileName: json['fileName'] as String?,
      fileUrl: json['fileUrl'] as String?,
      mimeType: json['mimeType'] as String?,
      likes: _toInt(json['likes']),
      comments: _toInt(json['comments']),
      playCount: _toInt(json['playCount']),
      isApproved: json['isApproved'] == true,
      isFollowingContributor: json['isFollowingContributor'] == true,
      createdAt: _parseDateTime(json['createdAt']),
    );
  }

  bool get isLinkedSubmission =>
      type == CommunityRequestSubmissionType.linkedVideo;

  CommunityRequestSubmission copyWith({
    String? id,
    String? requestId,
    String? contributorId,
    String? contributorName,
    Object? contributorAvatarUrl = _communityRequestSubmissionAvatarSentinel,
    String? title,
    String? description,
    CommunityRequestSubmissionType? type,
    Object? linkedVideoUrl = _communityRequestSubmissionLinkSentinel,
    Object? linkedMedia = _communityRequestSubmissionLinkedMediaSentinel,
    Object? searchKeyword = _communityRequestSubmissionSearchSentinel,
    Object? fileName = _communityRequestSubmissionFileSentinel,
    Object? fileUrl = _communityRequestSubmissionUrlSentinel,
    Object? mimeType = _communityRequestSubmissionMimeSentinel,
    int? likes,
    int? comments,
    int? playCount,
    bool? isApproved,
    bool? isFollowingContributor,
    DateTime? createdAt,
  }) {
    return CommunityRequestSubmission(
      id: id ?? this.id,
      requestId: requestId ?? this.requestId,
      contributorId: contributorId ?? this.contributorId,
      contributorName: contributorName ?? this.contributorName,
      contributorAvatarUrl:
          contributorAvatarUrl == _communityRequestSubmissionAvatarSentinel
              ? this.contributorAvatarUrl
              : contributorAvatarUrl as String?,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      linkedVideoUrl: linkedVideoUrl == _communityRequestSubmissionLinkSentinel
          ? this.linkedVideoUrl
          : linkedVideoUrl as String?,
        linkedMedia: linkedMedia == _communityRequestSubmissionLinkedMediaSentinel
          ? this.linkedMedia
          : linkedMedia as CommunityLinkedMedia?,
      searchKeyword: searchKeyword == _communityRequestSubmissionSearchSentinel
          ? this.searchKeyword
          : searchKeyword as String?,
      fileName: fileName == _communityRequestSubmissionFileSentinel
          ? this.fileName
          : fileName as String?,
      fileUrl: fileUrl == _communityRequestSubmissionUrlSentinel
          ? this.fileUrl
          : fileUrl as String?,
      mimeType: mimeType == _communityRequestSubmissionMimeSentinel
          ? this.mimeType
          : mimeType as String?,
      likes: likes ?? this.likes,
      comments: comments ?? this.comments,
      playCount: playCount ?? this.playCount,
      isApproved: isApproved ?? this.isApproved,
      isFollowingContributor:
          isFollowingContributor ?? this.isFollowingContributor,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

const Object _communityRequestSubmissionAvatarSentinel = Object();
const Object _communityRequestSubmissionLinkSentinel = Object();
const Object _communityRequestSubmissionLinkedMediaSentinel = Object();
const Object _communityRequestSubmissionSearchSentinel = Object();
const Object _communityRequestSubmissionFileSentinel = Object();
const Object _communityRequestSubmissionUrlSentinel = Object();
const Object _communityRequestSubmissionMimeSentinel = Object();

class CommunityRequest {
  final String id;
  final String authorId;
  final String authorName;
  final String? authorAvatarUrl;
  final String title;
  final String description;
  final String boardLabel;
  final List<String> keywords;
  final List<String> previewHints;
  final List<String> referenceImageUrls;
  final int baseCoins;
  final int bonusCoins;
  final int wantCount;
  final int replyCount;
  final int supporterCount;
  final bool isFeatured;
  final bool isWantedByCurrentUser;
  final CommunityRequestStatus status;
  final DateTime createdAt;
  final List<CommunityRequestSubmission> submissions;
  final String? approvedSubmissionId;

  const CommunityRequest({
    required this.id,
    required this.authorId,
    required this.authorName,
    this.authorAvatarUrl,
    required this.title,
    required this.description,
    required this.boardLabel,
    this.keywords = const <String>[],
    this.previewHints = const <String>[],
    this.referenceImageUrls = const <String>[],
    required this.baseCoins,
    this.bonusCoins = 0,
    this.wantCount = 0,
    this.replyCount = 0,
    this.supporterCount = 0,
    this.isFeatured = false,
    this.isWantedByCurrentUser = false,
    this.status = CommunityRequestStatus.open,
    required this.createdAt,
    this.submissions = const <CommunityRequestSubmission>[],
    this.approvedSubmissionId,
  });

  factory CommunityRequest.fromJson(Map<String, dynamic> json) {
    return CommunityRequest(
      id: (json['id'] ?? '').toString(),
      authorId: (json['authorId'] ?? '').toString(),
      authorName: (json['authorName'] ?? '').toString(),
      authorAvatarUrl: json['authorAvatarUrl'] as String?,
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      boardLabel: (json['boardLabel'] ?? 'Latest').toString(),
      keywords: _toStringList(json['keywords']),
      previewHints: _toStringList(json['previewHints']),
      referenceImageUrls: _toStringList(json['referenceImageUrls']),
      baseCoins: _toInt(json['baseCoins']),
      bonusCoins: _toInt(json['bonusCoins']),
      wantCount: _toInt(json['wantCount']),
      replyCount: _toInt(json['replyCount']),
      supporterCount: _toInt(json['supporterCount']),
      isFeatured: json['isFeatured'] == true,
      isWantedByCurrentUser: json['isWantedByCurrentUser'] == true,
      status: _parseRequestStatus(json['status']),
      createdAt: _parseDateTime(json['createdAt']),
      submissions: _toModelList(
        json['submissions'],
        CommunityRequestSubmission.fromJson,
      ),
      approvedSubmissionId: json['approvedSubmissionId'] as String?,
    );
  }

  int get totalCoins => baseCoins + bonusCoins;
  bool get isOpen => status == CommunityRequestStatus.open;

  CommunityRequest copyWith({
    String? id,
    String? authorId,
    String? authorName,
    Object? authorAvatarUrl = _communityRequestAvatarSentinel,
    String? title,
    String? description,
    String? boardLabel,
    List<String>? keywords,
    List<String>? previewHints,
    List<String>? referenceImageUrls,
    int? baseCoins,
    int? bonusCoins,
    int? wantCount,
    int? replyCount,
    int? supporterCount,
    bool? isFeatured,
    bool? isWantedByCurrentUser,
    CommunityRequestStatus? status,
    DateTime? createdAt,
    List<CommunityRequestSubmission>? submissions,
    Object? approvedSubmissionId = _communityRequestApprovedSentinel,
  }) {
    return CommunityRequest(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorAvatarUrl: authorAvatarUrl == _communityRequestAvatarSentinel
          ? this.authorAvatarUrl
          : authorAvatarUrl as String?,
      title: title ?? this.title,
      description: description ?? this.description,
      boardLabel: boardLabel ?? this.boardLabel,
      keywords: keywords ?? this.keywords,
      previewHints: previewHints ?? this.previewHints,
      referenceImageUrls: referenceImageUrls ?? this.referenceImageUrls,
      baseCoins: baseCoins ?? this.baseCoins,
      bonusCoins: bonusCoins ?? this.bonusCoins,
      wantCount: wantCount ?? this.wantCount,
      replyCount: replyCount ?? this.replyCount,
      supporterCount: supporterCount ?? this.supporterCount,
      isFeatured: isFeatured ?? this.isFeatured,
      isWantedByCurrentUser:
          isWantedByCurrentUser ?? this.isWantedByCurrentUser,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      submissions: submissions ?? this.submissions,
      approvedSubmissionId: approvedSubmissionId == _communityRequestApprovedSentinel
          ? this.approvedSubmissionId
          : approvedSubmissionId as String?,
    );
  }
}

const Object _communityRequestAvatarSentinel = Object();
const Object _communityRequestApprovedSentinel = Object();

class CommunityHubOverview {
  final List<CommunityForum> forums;
  final List<CommunityCreator> creators;
  final List<CommunityRequest> requests;

  const CommunityHubOverview({
    required this.forums,
    required this.creators,
    required this.requests,
  });

  factory CommunityHubOverview.fromJson(Map<String, dynamic> json) {
    return CommunityHubOverview(
      forums: _toModelList(json['forums'], CommunityForum.fromJson),
      creators: _toModelList(json['creators'], CommunityCreator.fromJson),
      requests: _toModelList(json['requests'], CommunityRequest.fromJson),
    );
  }
}

class CommunityForumDetail {
  final CommunityForum forum;
  final List<CommunityPost> posts;
  final String feed;

  const CommunityForumDetail({
    required this.forum,
    required this.posts,
    required this.feed,
  });

  factory CommunityForumDetail.fromJson(Map<String, dynamic> json) {
    return CommunityForumDetail(
      forum: CommunityForum.fromJson(_asMap(json['forum'])),
      posts: _toModelList(json['posts'], CommunityPost.fromJson),
      feed: (json['feed'] ?? 'recommended').toString(),
    );
  }
}

CommunityRequestStatus _parseRequestStatus(dynamic raw) {
  final value = raw?.toString().toLowerCase();
  return value == 'ended'
      ? CommunityRequestStatus.ended
      : CommunityRequestStatus.open;
}

CommunityRequestSubmissionType _parseSubmissionType(dynamic raw) {
  final value = raw?.toString().toLowerCase();
  return value == 'fileupload' || value == 'file_upload'
      ? CommunityRequestSubmissionType.fileUpload
      : CommunityRequestSubmissionType.linkedVideo;
}

CommunityLinkedMediaPreviewKind _parseLinkedMediaPreviewKind(dynamic raw) {
  switch (raw?.toString().toLowerCase()) {
    case 'image':
      return CommunityLinkedMediaPreviewKind.image;
    case 'video':
      return CommunityLinkedMediaPreviewKind.video;
    case 'audio':
      return CommunityLinkedMediaPreviewKind.audio;
    case 'file':
      return CommunityLinkedMediaPreviewKind.file;
    default:
      return CommunityLinkedMediaPreviewKind.external;
  }
}

String _linkedMediaPreviewKindValue(CommunityLinkedMediaPreviewKind kind) {
  switch (kind) {
    case CommunityLinkedMediaPreviewKind.image:
      return 'image';
    case CommunityLinkedMediaPreviewKind.video:
      return 'video';
    case CommunityLinkedMediaPreviewKind.audio:
      return 'audio';
    case CommunityLinkedMediaPreviewKind.file:
      return 'file';
    case CommunityLinkedMediaPreviewKind.external:
      return 'external';
  }
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return <String, dynamic>{};
}

List<String> _toStringList(dynamic value) {
  if (value is List) {
    return value.map((item) => item.toString()).toList();
  }
  return const <String>[];
}

List<T> _toModelList<T>(
  dynamic value,
  T Function(Map<String, dynamic>) fromJson,
) {
  if (value is List) {
    return value
        .map((item) => fromJson(_asMap(item)))
        .toList(growable: false);
  }
  return List<T>.empty(growable: false);
}

int _toInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime _parseDateTime(dynamic value) {
  return DateTime.tryParse(value?.toString() ?? '') ?? DateTime.now();
}

String? _cleanOptionalString(dynamic value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) {
    return null;
  }
  return text;
}
