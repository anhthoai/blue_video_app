import 'dart:convert';

enum LikeType {
  video,
  comment,
  user, // For following
}

class LikeModel {
  final String id;
  final String userId;
  final String targetId; // videoId, commentId, or userId
  final LikeType type;
  final DateTime timestamp;
  final bool isActive;

  const LikeModel({
    required this.id,
    required this.userId,
    required this.targetId,
    required this.type,
    required this.timestamp,
    this.isActive = true,
  });

  LikeModel copyWith({
    String? id,
    String? userId,
    String? targetId,
    LikeType? type,
    DateTime? timestamp,
    bool? isActive,
  }) {
    return LikeModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      targetId: targetId ?? this.targetId,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'targetId': targetId,
      'type': type.name,
      'timestamp': timestamp.toIso8601String(),
      'isActive': isActive,
    };
  }

  factory LikeModel.fromJson(Map<String, dynamic> json) {
    return LikeModel(
      id: json['id'] as String,
      userId: json['userId'] as String,
      targetId: json['targetId'] as String,
      type: LikeType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => LikeType.video,
      ),
      timestamp: DateTime.parse(json['timestamp'] as String),
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  String toJsonString() {
    return jsonEncode(toJson());
  }

  factory LikeModel.fromJsonString(String jsonString) {
    return LikeModel.fromJson(jsonDecode(jsonString));
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LikeModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'LikeModel(id: $id, userId: $userId, targetId: $targetId, type: $type)';
  }
}
