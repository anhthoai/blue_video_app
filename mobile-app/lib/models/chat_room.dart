import 'dart:convert';

import 'chat_message.dart';
import 'chat_participant.dart';

class ChatRoom {
  final String id;
  final String name;
  final String? description;
  final String? avatarUrl;
  final bool isGroup;
  final List<ChatParticipant> participants;
  final ChatMessage? lastMessage;
  final int unreadCount;
  final bool isOnline;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic>? settings;
  final bool isMuted;
  final bool isPinned;
  final String? createdBy;

  const ChatRoom({
    required this.id,
    required this.name,
    this.description,
    this.avatarUrl,
    required this.isGroup,
    required this.participants,
    this.lastMessage,
    this.unreadCount = 0,
    this.isOnline = false,
    required this.createdAt,
    this.updatedAt,
    this.settings,
    this.isMuted = false,
    this.isPinned = false,
    this.createdBy,
  });

  ChatRoom copyWith({
    String? id,
    String? name,
    String? description,
    String? avatarUrl,
    bool? isGroup,
    List<ChatParticipant>? participants,
    ChatMessage? lastMessage,
    int? unreadCount,
    bool? isOnline,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? settings,
    bool? isMuted,
    bool? isPinned,
    String? createdBy,
  }) {
    return ChatRoom(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isGroup: isGroup ?? this.isGroup,
      participants: participants ?? this.participants,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
      isOnline: isOnline ?? this.isOnline,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      settings: settings ?? this.settings,
      isMuted: isMuted ?? this.isMuted,
      isPinned: isPinned ?? this.isPinned,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'avatarUrl': avatarUrl,
      'isGroup': isGroup,
      'participants': participants.map((p) => p.toJson()).toList(),
      'lastMessage': lastMessage?.toJson(),
      'unreadCount': unreadCount,
      'isOnline': isOnline,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'settings': settings,
      'isMuted': isMuted,
      'isPinned': isPinned,
      'createdBy': createdBy,
    };
  }

  factory ChatRoom.fromJson(Map<String, dynamic> json) {
    return ChatRoom(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      isGroup: json['isGroup'] as bool? ?? json['type'] == 'GROUP',
      participants: (json['participants'] as List<dynamic>?)
              ?.map((p) => ChatParticipant.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [],
      lastMessage: json['lastMessage'] != null
          ? ChatMessage.fromJson(json['lastMessage'] as Map<String, dynamic>)
          : null,
      unreadCount: json['unreadCount'] as int? ?? 0,
      isOnline: json['isOnline'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
      settings: json['settings'] as Map<String, dynamic>?,
      isMuted: json['isMuted'] as bool? ?? false,
      isPinned: json['isPinned'] as bool? ?? false,
      createdBy: json['createdBy'] != null
          ? (json['createdBy'] as Map<String, dynamic>)['id'] as String?
          : null,
    );
  }

  String toJsonString() {
    return jsonEncode(toJson());
  }

  factory ChatRoom.fromJsonString(String jsonString) {
    return ChatRoom.fromJson(jsonDecode(jsonString));
  }

  // Helper methods
  String get displayName {
    if (isGroup) {
      return name;
    } else if (participants.isNotEmpty) {
      return participants.first.displayName;
    }
    return name;
  }

  String get displayAvatar {
    if (avatarUrl != null) return avatarUrl!;
    if (isGroup && participants.length > 1) {
      return participants.first.avatarUrl ?? '';
    }
    return participants.isNotEmpty ? participants.first.avatarUrl ?? '' : '';
  }

  String get lastMessagePreview {
    if (lastMessage == null) return 'No messages yet';

    switch (lastMessage!.messageType) {
      case MessageType.text:
        return lastMessage!.content;
      case MessageType.image:
        return '📷 Photo';
      case MessageType.video:
        return '🎥 Video';
      case MessageType.audio:
        return '🎵 Audio';
      case MessageType.file:
        return '📄 File';
      case MessageType.location:
        return '📍 Location';
      case MessageType.sticker:
        return '😀 Sticker';
      case MessageType.system:
        return lastMessage!.content;
    }
  }

  String get lastMessageTime {
    if (lastMessage == null) return '';

    final now = DateTime.now();
    final difference = now.difference(lastMessage!.createdAt);

    if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'now';
    }
  }

  bool get hasUnreadMessages => unreadCount > 0;

  List<ChatParticipant> get otherParticipants {
    // Return participants excluding the current user
    // In a real app, you would filter out the current user
    return participants;
  }

  // Methods that consider current user
  String getDisplayName(String? currentUserId) {
    if (isGroup) {
      return name;
    } else {
      // For individual chats, show the OTHER participant's name (not current user)
      final otherParticipants =
          participants.where((p) => p.id != currentUserId).toList();
      if (otherParticipants.isNotEmpty) {
        return otherParticipants.first.displayName;
      }
      return participants.isNotEmpty ? participants.first.displayName : name;
    }
  }

  String getDisplayAvatar(String? currentUserId) {
    if (avatarUrl != null) return avatarUrl!;
    if (isGroup) {
      // For group chats, we'll handle this in the widget with multiple avatars
      return participants.isNotEmpty ? participants.first.avatarUrl ?? '' : '';
    } else {
      // For individual chats, show the OTHER participant's avatar
      final otherParticipants =
          participants.where((p) => p.id != currentUserId).toList();
      if (otherParticipants.isNotEmpty) {
        return otherParticipants.first.avatarUrl ?? '';
      }
      return participants.isNotEmpty ? participants.first.avatarUrl ?? '' : '';
    }
  }

  // Get other participants (excluding current user)
  List<ChatParticipant> getOtherParticipants(String? currentUserId) {
    return participants.where((p) => p.id != currentUserId).toList();
  }

  // Get first two participants for group avatar display
  List<ChatParticipant> getFirstTwoParticipants(String? currentUserId) {
    if (isGroup) {
      // For groups, show current user + first other participant
      final otherParticipants = getOtherParticipants(currentUserId);
      final currentUserParticipant =
          participants.where((p) => p.id == currentUserId).firstOrNull;

      if (currentUserParticipant != null && otherParticipants.isNotEmpty) {
        return [currentUserParticipant, otherParticipants.first];
      } else if (otherParticipants.isNotEmpty) {
        return otherParticipants.take(2).toList();
      }
    }
    return participants.take(2).toList();
  }

  int get participantCount => participants.length;

  bool get isDirectMessage => !isGroup && participants.length == 2;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChatRoom && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'ChatRoom(id: $id, name: $name, isGroup: $isGroup, participants: ${participants.length}, unreadCount: $unreadCount)';
  }
}
