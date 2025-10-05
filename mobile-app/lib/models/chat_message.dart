import 'dart:convert';

enum MessageType {
  text,
  image,
  video,
  audio,
  file,
  location,
  sticker,
  system,
}

class ChatMessage {
  final String id;
  final String roomId;
  final String userId;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final MessageType messageType;
  final String? fileUrl;
  final String username;
  final String? userAvatar;
  final bool isEdited;
  final bool isDeleted;
  final bool isRead;
  final String? replyToMessageId;
  final List<String>? attachments;
  final Map<String, dynamic>? metadata;

  const ChatMessage({
    required this.id,
    required this.roomId,
    required this.userId,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    required this.messageType,
    this.fileUrl,
    required this.username,
    this.userAvatar,
    this.isEdited = false,
    this.isDeleted = false,
    this.isRead = false,
    this.replyToMessageId,
    this.attachments,
    this.metadata,
  });

  ChatMessage copyWith({
    String? id,
    String? roomId,
    String? userId,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
    MessageType? messageType,
    String? fileUrl,
    String? username,
    String? userAvatar,
    bool? isEdited,
    bool? isDeleted,
    bool? isRead,
    String? replyToMessageId,
    List<String>? attachments,
    Map<String, dynamic>? metadata,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      userId: userId ?? this.userId,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      messageType: messageType ?? this.messageType,
      fileUrl: fileUrl ?? this.fileUrl,
      username: username ?? this.username,
      userAvatar: userAvatar ?? this.userAvatar,
      isEdited: isEdited ?? this.isEdited,
      isDeleted: isDeleted ?? this.isDeleted,
      isRead: isRead ?? this.isRead,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      attachments: attachments ?? this.attachments,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'roomId': roomId,
      'userId': userId,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'messageType': messageType.name,
      'fileUrl': fileUrl,
      'username': username,
      'userAvatar': userAvatar,
      'isEdited': isEdited,
      'isDeleted': isDeleted,
      'isRead': isRead,
      'replyToMessageId': replyToMessageId,
      'attachments': attachments,
      'metadata': metadata,
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String? ?? '',
      roomId: json['roomId'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      content: json['content'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
      messageType: MessageType.values.firstWhere(
        (e) =>
            e.name.toLowerCase() ==
            (((json['type'] ?? json['messageType']) as String?) ?? 'text')
                .toLowerCase(),
        orElse: () => MessageType.text,
      ),
      fileUrl: json['fileUrl'] as String?,
      username: json['username'] as String? ?? '',
      userAvatar: json['userAvatar'] as String?,
      isEdited: json['isEdited'] as bool? ?? false,
      isDeleted: json['isDeleted'] as bool? ?? false,
      isRead: json['isRead'] as bool? ?? false,
      replyToMessageId: json['replyToMessageId'] as String?,
      attachments: (json['attachments'] as List<dynamic>?)?.cast<String>(),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  String toJsonString() {
    return jsonEncode(toJson());
  }

  factory ChatMessage.fromJsonString(String jsonString) {
    return ChatMessage.fromJson(jsonDecode(jsonString));
  }

  // Helper methods
  String get senderId => userId; // Alias for compatibility
  DateTime get timestamp => createdAt; // Alias for compatibility

  bool get isText => messageType == MessageType.text;
  bool get isImage => messageType == MessageType.image;
  bool get isVideo => messageType == MessageType.video;
  bool get isAudio => messageType == MessageType.audio;
  bool get isFile => messageType == MessageType.file;
  bool get isLocation => messageType == MessageType.location;
  bool get isSticker => messageType == MessageType.sticker;
  bool get isSystem => messageType == MessageType.system;

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

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChatMessage && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'ChatMessage(id: $id, roomId: $roomId, userId: $userId, content: $content, createdAt: $createdAt, messageType: $messageType)';
  }
}
