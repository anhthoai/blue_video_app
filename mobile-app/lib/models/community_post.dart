import 'dart:convert';

enum PostType {
  text,
  media, // For posts with images and/or videos
  link,
  poll,
}

enum PostStatus {
  published,
  draft,
  archived,
  deleted,
  reported,
}

class CommunityPost {
  final String id;
  final String userId;
  final String username;
  final String? firstName;
  final String? lastName;
  final bool isVerified;
  final String userAvatar;
  final String? title;
  final String content;
  final PostType type;
  final PostStatus status;
  final List<String> images;
  final List<String> videos; // Support multiple videos
  final List<String> imageUrls; // URLs for images
  final List<String> videoUrls; // URLs for videos
  final List<String> videoThumbnailUrls; // URLs for video thumbnails
  final List<String> duration; // Duration for each video in seconds
  final String? videoUrl; // Keep for backward compatibility
  final String? linkUrl;
  final String? linkTitle;
  final String? linkDescription;
  final String? linkThumbnail;
  final Map<String, dynamic>? pollData;
  final List<String> tags;
  final String? category;
  final int likes;
  final int comments;
  final int shares;
  final int views;
  final bool isLiked;
  final bool isBookmarked;
  final bool isPinned;
  final bool isFollowing;
  final bool isFeatured;
  final bool isNsfw;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? publishedAt;
  final Map<String, dynamic>? metadata;

  const CommunityPost({
    required this.id,
    required this.userId,
    required this.username,
    this.firstName,
    this.lastName,
    this.isVerified = false,
    required this.userAvatar,
    this.title,
    required this.content,
    required this.type,
    this.status = PostStatus.published,
    this.images = const [],
    this.videos = const [],
    this.imageUrls = const [],
    this.videoUrls = const [],
    this.videoThumbnailUrls = const [],
    this.duration = const [],
    this.videoUrl,
    this.linkUrl,
    this.linkTitle,
    this.linkDescription,
    this.linkThumbnail,
    this.pollData,
    this.tags = const [],
    this.category,
    this.likes = 0,
    this.comments = 0,
    this.shares = 0,
    this.views = 0,
    this.isLiked = false,
    this.isBookmarked = false,
    this.isPinned = false,
    this.isFollowing = false,
    this.isFeatured = false,
    this.isNsfw = false,
    required this.createdAt,
    this.updatedAt,
    this.publishedAt,
    this.metadata,
  });

  CommunityPost copyWith({
    String? id,
    String? userId,
    String? username,
    String? firstName,
    String? lastName,
    bool? isVerified,
    String? userAvatar,
    String? title,
    String? content,
    PostType? type,
    PostStatus? status,
    List<String>? images,
    List<String>? videos,
    List<String>? imageUrls,
    List<String>? videoUrls,
    List<String>? videoThumbnailUrls,
    String? videoUrl,
    String? linkUrl,
    String? linkTitle,
    String? linkDescription,
    String? linkThumbnail,
    Map<String, dynamic>? pollData,
    List<String>? tags,
    String? category,
    int? likes,
    int? comments,
    int? shares,
    int? views,
    bool? isLiked,
    bool? isBookmarked,
    bool? isPinned,
    bool? isFollowing,
    bool? isFeatured,
    bool? isNsfw,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? publishedAt,
    Map<String, dynamic>? metadata,
  }) {
    return CommunityPost(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      isVerified: isVerified ?? this.isVerified,
      userAvatar: userAvatar ?? this.userAvatar,
      title: title ?? this.title,
      content: content ?? this.content,
      type: type ?? this.type,
      status: status ?? this.status,
      images: images ?? this.images,
      videos: videos ?? this.videos,
      imageUrls: imageUrls ?? this.imageUrls,
      videoUrls: videoUrls ?? this.videoUrls,
      videoThumbnailUrls: videoThumbnailUrls ?? this.videoThumbnailUrls,
      videoUrl: videoUrl ?? this.videoUrl,
      linkUrl: linkUrl ?? this.linkUrl,
      linkTitle: linkTitle ?? this.linkTitle,
      linkDescription: linkDescription ?? this.linkDescription,
      linkThumbnail: linkThumbnail ?? this.linkThumbnail,
      pollData: pollData ?? this.pollData,
      tags: tags ?? this.tags,
      category: category ?? this.category,
      likes: likes ?? this.likes,
      comments: comments ?? this.comments,
      shares: shares ?? this.shares,
      views: views ?? this.views,
      isLiked: isLiked ?? this.isLiked,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      isPinned: isPinned ?? this.isPinned,
      isFollowing: isFollowing ?? this.isFollowing,
      isFeatured: isFeatured ?? this.isFeatured,
      isNsfw: isNsfw ?? this.isNsfw,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      publishedAt: publishedAt ?? this.publishedAt,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'username': username,
      'firstName': firstName,
      'lastName': lastName,
      'isVerified': isVerified,
      'userAvatar': userAvatar,
      'title': title,
      'content': content,
      'type': type.name,
      'status': status.name,
      'images': images,
      'videos': videos,
      'imageUrls': imageUrls,
      'videoUrls': videoUrls,
      'videoThumbnailUrls': videoThumbnailUrls,
      'videoUrl': videoUrl,
      'linkUrl': linkUrl,
      'linkTitle': linkTitle,
      'linkDescription': linkDescription,
      'linkThumbnail': linkThumbnail,
      'pollData': pollData,
      'tags': tags,
      'category': category,
      'likes': likes,
      'comments': comments,
      'shares': shares,
      'views': views,
      'isLiked': isLiked,
      'isBookmarked': isBookmarked,
      'isPinned': isPinned,
      'isFollowing': isFollowing,
      'isFeatured': isFeatured,
      'isNsfw': isNsfw,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'publishedAt': publishedAt?.toIso8601String(),
      'metadata': metadata,
    };
  }

  factory CommunityPost.fromJson(Map<String, dynamic> json) {
    return CommunityPost(
      id: json['id'] as String,
      userId: json['userId'] as String,
      username: json['username'] as String,
      firstName: json['firstName'] as String?,
      lastName: json['lastName'] as String?,
      isVerified: json['isVerified'] as bool? ?? false,
      userAvatar: json['userAvatar'] as String,
      title: json['title'] as String?,
      content: json['content'] as String,
      type: PostType.values.firstWhere(
        (e) => e.name.toLowerCase() == (json['type'] as String?)?.toLowerCase(),
        orElse: () => PostType.text,
      ),
      status: PostStatus.values.firstWhere(
        (e) =>
            e.name.toLowerCase() == (json['status'] as String?)?.toLowerCase(),
        orElse: () => PostStatus.published,
      ),
      images: (json['images'] as List<dynamic>?)?.cast<String>() ?? [],
      videos: (json['videos'] as List<dynamic>?)?.cast<String>() ?? [],
      imageUrls: (json['imageUrls'] as List<dynamic>?)?.cast<String>() ?? [],
      videoUrls: (json['videoUrls'] as List<dynamic>?)?.cast<String>() ?? [],
      videoThumbnailUrls:
          (json['videoThumbnailUrls'] as List<dynamic>?)?.cast<String>() ?? [],
      duration: (json['duration'] as List<dynamic>?)?.cast<String>() ?? [],
      videoUrl: json['videoUrl'] as String?,
      linkUrl: json['linkUrl'] as String?,
      linkTitle: json['linkTitle'] as String?,
      linkDescription: json['linkDescription'] as String?,
      linkThumbnail: json['linkThumbnail'] as String?,
      pollData: json['pollData'] as Map<String, dynamic>?,
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      category: json['category'] as String?,
      likes: json['likes'] as int? ?? 0,
      comments: json['comments'] as int? ?? 0,
      shares: json['shares'] as int? ?? 0,
      views: json['views'] as int? ?? 0,
      isLiked: json['isLiked'] as bool? ?? false,
      isBookmarked: json['isBookmarked'] as bool? ?? false,
      isPinned: json['isPinned'] as bool? ?? false,
      isFollowing: json['isFollowing'] as bool? ?? false,
      isFeatured: json['isFeatured'] as bool? ?? false,
      isNsfw: json['isNsfw'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
      publishedAt: json['publishedAt'] != null
          ? DateTime.parse(json['publishedAt'] as String)
          : null,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  String toJsonString() {
    return jsonEncode(toJson());
  }

  factory CommunityPost.fromJsonString(String jsonString) {
    return CommunityPost.fromJson(jsonDecode(jsonString));
  }

  // Helper methods
  bool get isText => type == PostType.text;
  bool get isMedia => type == PostType.media;
  bool get isLink => type == PostType.link;
  bool get isPoll => type == PostType.poll;

  bool get isPublished => status == PostStatus.published;
  bool get isDraft => status == PostStatus.draft;
  bool get isArchived => status == PostStatus.archived;
  bool get isDeleted => status == PostStatus.deleted;
  bool get isReported => status == PostStatus.reported;

  String get formattedTime {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  String get shortTime {
    final hour = createdAt.hour.toString().padLeft(2, '0');
    final minute = createdAt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String get formattedLikes {
    if (likes >= 1000000) {
      return '${(likes / 1000000).toStringAsFixed(1)}M';
    } else if (likes >= 1000) {
      return '${(likes / 1000).toStringAsFixed(1)}K';
    } else {
      return likes.toString();
    }
  }

  String get formattedComments {
    if (comments >= 1000000) {
      return '${(comments / 1000000).toStringAsFixed(1)}M';
    } else if (comments >= 1000) {
      return '${(comments / 1000).toStringAsFixed(1)}K';
    } else {
      return comments.toString();
    }
  }

  String get formattedShares {
    if (shares >= 1000000) {
      return '${(shares / 1000000).toStringAsFixed(1)}M';
    } else if (shares >= 1000) {
      return '${(shares / 1000).toStringAsFixed(1)}K';
    } else {
      return shares.toString();
    }
  }

  String get formattedViews {
    if (views >= 1000000) {
      return '${(views / 1000000).toStringAsFixed(1)}M';
    } else if (views >= 1000) {
      return '${(views / 1000).toStringAsFixed(1)}K';
    } else {
      return views.toString();
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CommunityPost && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'CommunityPost(id: $id, title: $title, type: $type, likes: $likes, comments: $comments)';
  }
}
