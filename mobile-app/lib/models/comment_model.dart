import 'dart:convert';

class CommentModel {
  final String id;
  final String videoId;
  final String userId;
  final String username;
  final String userAvatar;
  final String content;
  final DateTime timestamp;
  final int likes;
  final bool isLiked;
  final String? parentCommentId; // For replies
  final List<CommentModel> replies;
  final bool isEdited;
  final DateTime? editedAt;
  final bool isDeleted;
  final DateTime? deletedAt;

  const CommentModel({
    required this.id,
    required this.videoId,
    required this.userId,
    required this.username,
    required this.userAvatar,
    required this.content,
    required this.timestamp,
    this.likes = 0,
    this.isLiked = false,
    this.parentCommentId,
    this.replies = const [],
    this.isEdited = false,
    this.editedAt,
    this.isDeleted = false,
    this.deletedAt,
  });

  CommentModel copyWith({
    String? id,
    String? videoId,
    String? userId,
    String? username,
    String? userAvatar,
    String? content,
    DateTime? timestamp,
    int? likes,
    bool? isLiked,
    String? parentCommentId,
    List<CommentModel>? replies,
    bool? isEdited,
    DateTime? editedAt,
    bool? isDeleted,
    DateTime? deletedAt,
  }) {
    return CommentModel(
      id: id ?? this.id,
      videoId: videoId ?? this.videoId,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      userAvatar: userAvatar ?? this.userAvatar,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      likes: likes ?? this.likes,
      isLiked: isLiked ?? this.isLiked,
      parentCommentId: parentCommentId ?? this.parentCommentId,
      replies: replies ?? this.replies,
      isEdited: isEdited ?? this.isEdited,
      editedAt: editedAt ?? this.editedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'videoId': videoId,
      'userId': userId,
      'username': username,
      'userAvatar': userAvatar,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'likes': likes,
      'isLiked': isLiked,
      'parentCommentId': parentCommentId,
      'replies': replies.map((r) => r.toJson()).toList(),
      'isEdited': isEdited,
      'editedAt': editedAt?.toIso8601String(),
      'isDeleted': isDeleted,
      'deletedAt': deletedAt?.toIso8601String(),
    };
  }

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    return CommentModel(
      id: json['id'] as String,
      videoId: json['videoId'] as String,
      userId: json['userId'] as String,
      username: json['username'] as String,
      userAvatar: json['userAvatar'] as String,
      content: json['content'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      likes: json['likes'] as int? ?? 0,
      isLiked: json['isLiked'] as bool? ?? false,
      parentCommentId: json['parentCommentId'] as String?,
      replies: (json['replies'] as List<dynamic>?)
              ?.map((r) => CommentModel.fromJson(r as Map<String, dynamic>))
              .toList() ??
          [],
      isEdited: json['isEdited'] as bool? ?? false,
      editedAt: json['editedAt'] != null
          ? DateTime.parse(json['editedAt'] as String)
          : null,
      isDeleted: json['isDeleted'] as bool? ?? false,
      deletedAt: json['deletedAt'] != null
          ? DateTime.parse(json['deletedAt'] as String)
          : null,
    );
  }

  String toJsonString() {
    return jsonEncode(toJson());
  }

  factory CommentModel.fromJsonString(String jsonString) {
    return CommentModel.fromJson(jsonDecode(jsonString));
  }

  // Helper methods
  bool get isReply => parentCommentId != null;
  bool get hasReplies => replies.isNotEmpty;
  int get totalReplies => replies.length;

  String get formattedTime {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

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
    final hour = timestamp.hour.toString().padLeft(2, '0');
    final minute = timestamp.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CommentModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'CommentModel(id: $id, videoId: $videoId, userId: $userId, content: $content, likes: $likes)';
  }
}
