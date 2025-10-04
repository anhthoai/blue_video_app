import 'dart:convert';

class VideoModel {
  final String id;
  final String userId;
  final String title;
  final String? description;
  final String videoUrl;
  final String? thumbnailUrl;
  final int duration; // in seconds
  final int viewCount;
  final int likeCount;
  final int commentCount;
  final int shareCount;
  final int downloadCount;
  final bool isLiked; // Whether current user has liked this video
  final bool isPublic;
  final bool isFeatured;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final List<String>? tags;
  final String? category;
  final int? price; // in coins
  final bool isPaid;
  final String? location;
  final Map<String, dynamic>? metadata;

  // User information
  final String? username;
  final String? firstName;
  final String? lastName;
  final String? userAvatarUrl;
  final bool? isUserVerified;

  // Display name (firstName + lastName or username)
  String get displayName {
    if (firstName != null && firstName!.isNotEmpty) {
      if (lastName != null && lastName!.isNotEmpty) {
        return '$firstName $lastName';
      }
      return firstName!;
    }
    return username ?? 'User $userId';
  }

  const VideoModel({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    required this.videoUrl,
    this.thumbnailUrl,
    this.duration = 0,
    this.viewCount = 0,
    this.likeCount = 0,
    this.commentCount = 0,
    this.shareCount = 0,
    this.downloadCount = 0,
    this.isLiked = false,
    this.isPublic = true,
    this.isFeatured = false,
    required this.createdAt,
    this.updatedAt,
    this.tags,
    this.category,
    this.price,
    this.isPaid = false,
    this.location,
    this.metadata,
    this.username,
    this.firstName,
    this.lastName,
    this.userAvatarUrl,
    this.isUserVerified,
  });

  // Copy with method
  VideoModel copyWith({
    String? id,
    String? userId,
    String? title,
    String? description,
    String? videoUrl,
    String? thumbnailUrl,
    int? duration,
    int? viewCount,
    int? likeCount,
    int? commentCount,
    int? shareCount,
    int? downloadCount,
    bool? isLiked,
    bool? isPublic,
    bool? isFeatured,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? tags,
    String? category,
    int? price,
    bool? isPaid,
    String? location,
    Map<String, dynamic>? metadata,
    String? username,
    String? firstName,
    String? lastName,
    String? userAvatarUrl,
    bool? isUserVerified,
  }) {
    return VideoModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      videoUrl: videoUrl ?? this.videoUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      duration: duration ?? this.duration,
      viewCount: viewCount ?? this.viewCount,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      shareCount: shareCount ?? this.shareCount,
      downloadCount: downloadCount ?? this.downloadCount,
      isLiked: isLiked ?? this.isLiked,
      isPublic: isPublic ?? this.isPublic,
      isFeatured: isFeatured ?? this.isFeatured,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      tags: tags ?? this.tags,
      category: category ?? this.category,
      price: price ?? this.price,
      isPaid: isPaid ?? this.isPaid,
      location: location ?? this.location,
      metadata: metadata ?? this.metadata,
      username: username ?? this.username,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      userAvatarUrl: userAvatarUrl ?? this.userAvatarUrl,
      isUserVerified: isUserVerified ?? this.isUserVerified,
    );
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'description': description,
      'videoUrl': videoUrl,
      'thumbnailUrl': thumbnailUrl,
      'duration': duration,
      'viewCount': viewCount,
      'likeCount': likeCount,
      'commentCount': commentCount,
      'shareCount': shareCount,
      'downloadCount': downloadCount,
      'isLiked': isLiked,
      'isPublic': isPublic,
      'isFeatured': isFeatured,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'tags': tags,
      'category': category,
      'price': price,
      'isPaid': isPaid,
      'location': location,
      'metadata': metadata,
      'username': username,
      'firstName': firstName,
      'lastName': lastName,
      'userAvatarUrl': userAvatarUrl,
      'isUserVerified': isUserVerified,
    };
  }

  // Create from JSON
  factory VideoModel.fromJson(Map<String, dynamic> json) {
    // Parse user data if available
    final userData = json['user'] as Map<String, dynamic>?;

    return VideoModel(
      id: json['id'] as String,
      userId: json['userId'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      videoUrl: json['videoUrl'] as String,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      duration: json['duration'] as int? ?? 0,
      viewCount: json['viewCount'] as int? ?? json['views'] as int? ?? 0,
      likeCount: json['likeCount'] as int? ?? json['likes'] as int? ?? 0,
      commentCount:
          json['commentCount'] as int? ?? json['comments'] as int? ?? 0,
      shareCount: json['shareCount'] as int? ?? json['shares'] as int? ?? 0,
      downloadCount:
          json['downloadCount'] as int? ?? json['downloads'] as int? ?? 0,
      isLiked: json['isLiked'] as bool? ?? false,
      isPublic: json['isPublic'] as bool? ?? true,
      isFeatured: json['isFeatured'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
      tags:
          json['tags'] != null ? List<String>.from(json['tags'] as List) : null,
      category: json['category'] as String?,
      price: json['price'] as int?,
      isPaid: json['isPaid'] as bool? ?? false,
      location: json['location'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
      username: userData?['username'] as String? ?? json['username'] as String?,
      firstName:
          userData?['firstName'] as String? ?? json['firstName'] as String?,
      lastName: userData?['lastName'] as String? ?? json['lastName'] as String?,
      userAvatarUrl:
          userData?['avatarUrl'] as String? ?? json['userAvatarUrl'] as String?,
      isUserVerified:
          userData?['isVerified'] as bool? ?? json['isUserVerified'] as bool?,
    );
  }

  // Create from JSON string
  factory VideoModel.fromJsonString(String jsonString) {
    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    return VideoModel.fromJson(json);
  }

  // Convert to JSON string
  String toJsonString() {
    return jsonEncode(toJson());
  }

  // Format duration
  String get formattedDuration {
    final hours = duration ~/ 3600;
    final minutes = (duration % 3600) ~/ 60;
    final seconds = duration % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }

  // Format view count
  String get formattedViewCount {
    if (viewCount >= 1000000) {
      return '${(viewCount / 1000000).toStringAsFixed(1)}M';
    } else if (viewCount >= 1000) {
      return '${(viewCount / 1000).toStringAsFixed(1)}K';
    } else {
      return viewCount.toString();
    }
  }

  // Format like count
  String get formattedLikeCount {
    if (likeCount >= 1000000) {
      return '${(likeCount / 1000000).toStringAsFixed(1)}M';
    } else if (likeCount >= 1000) {
      return '${(likeCount / 1000).toStringAsFixed(1)}K';
    } else {
      return likeCount.toString();
    }
  }

  // Equality
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VideoModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  // String representation
  @override
  String toString() {
    return 'VideoModel(id: $id, title: $title, userId: $userId)';
  }
}
