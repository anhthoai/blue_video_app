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
    };
  }

  // Create from JSON
  factory VideoModel.fromJson(Map<String, dynamic> json) {
    return VideoModel(
      id: json['id'] as String,
      userId: json['userId'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      videoUrl: json['videoUrl'] as String,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      duration: json['duration'] as int? ?? 0,
      viewCount: json['viewCount'] as int? ?? 0,
      likeCount: json['likeCount'] as int? ?? 0,
      commentCount: json['commentCount'] as int? ?? 0,
      shareCount: json['shareCount'] as int? ?? 0,
      isPublic: json['isPublic'] as bool? ?? true,
      isFeatured: json['isFeatured'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt:
          json['updatedAt'] != null
              ? DateTime.parse(json['updatedAt'] as String)
              : null,
      tags:
          json['tags'] != null ? List<String>.from(json['tags'] as List) : null,
      category: json['category'] as String?,
      price: json['price'] as int?,
      isPaid: json['isPaid'] as bool? ?? false,
      location: json['location'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
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
