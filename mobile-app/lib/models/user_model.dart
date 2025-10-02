import 'dart:convert';

class UserModel {
  final String id;
  final String email;
  final String username;
  final String? phoneNumber;
  final String? firstName;
  final String? lastName;
  final String? avatarUrl;
  final String? bannerUrl;
  final String? bio;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isVerified;
  final bool isVip;
  final int vipLevel;
  final int coinBalance;
  final int followerCount;
  final int followingCount;
  final int videoCount;
  final int likeCount;
  final String? location;
  final String? website;
  final List<String>? interests;
  final Map<String, dynamic>? preferences;

  const UserModel({
    required this.id,
    required this.email,
    required this.username,
    this.phoneNumber,
    this.firstName,
    this.lastName,
    this.avatarUrl,
    this.bannerUrl,
    this.bio,
    required this.createdAt,
    this.updatedAt,
    this.isVerified = false,
    this.isVip = false,
    this.vipLevel = 0,
    this.coinBalance = 0,
    this.followerCount = 0,
    this.followingCount = 0,
    this.videoCount = 0,
    this.likeCount = 0,
    this.location,
    this.website,
    this.interests,
    this.preferences,
  });

  // Copy with method
  UserModel copyWith({
    String? id,
    String? email,
    String? username,
    String? phoneNumber,
    String? firstName,
    String? lastName,
    String? avatarUrl,
    String? bannerUrl,
    String? bio,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isVerified,
    bool? isVip,
    int? vipLevel,
    int? coinBalance,
    int? followerCount,
    int? followingCount,
    int? videoCount,
    int? likeCount,
    String? location,
    String? website,
    List<String>? interests,
    Map<String, dynamic>? preferences,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      username: username ?? this.username,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      bio: bio ?? this.bio,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isVerified: isVerified ?? this.isVerified,
      isVip: isVip ?? this.isVip,
      vipLevel: vipLevel ?? this.vipLevel,
      coinBalance: coinBalance ?? this.coinBalance,
      followerCount: followerCount ?? this.followerCount,
      followingCount: followingCount ?? this.followingCount,
      videoCount: videoCount ?? this.videoCount,
      likeCount: likeCount ?? this.likeCount,
      location: location ?? this.location,
      website: website ?? this.website,
      interests: interests ?? this.interests,
      preferences: preferences ?? this.preferences,
    );
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'username': username,
      'phoneNumber': phoneNumber,
      'firstName': firstName,
      'lastName': lastName,
      'avatarUrl': avatarUrl,
      'bannerUrl': bannerUrl,
      'bio': bio,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'isVerified': isVerified,
      'isVip': isVip,
      'vipLevel': vipLevel,
      'coinBalance': coinBalance,
      'followerCount': followerCount,
      'followingCount': followingCount,
      'videoCount': videoCount,
      'likeCount': likeCount,
      'location': location,
      'website': website,
      'interests': interests,
      'preferences': preferences,
    };
  }

  // Create from JSON
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      username: json['username'] as String,
      phoneNumber: json['phoneNumber'] as String?,
      firstName: json['firstName'] as String?,
      lastName: json['lastName'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      bannerUrl: json['bannerUrl'] as String?,
      bio: json['bio'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
      isVerified: json['isVerified'] as bool? ?? false,
      isVip: json['isVip'] as bool? ?? false,
      vipLevel: json['vipLevel'] as int? ?? 0,
      coinBalance: json['coinBalance'] as int? ?? 0,
      followerCount: json['followerCount'] as int? ?? 0,
      followingCount: json['followingCount'] as int? ?? 0,
      videoCount: json['videoCount'] as int? ?? 0,
      likeCount: json['likeCount'] as int? ?? 0,
      location: json['location'] as String?,
      website: json['website'] as String?,
      interests: json['interests'] != null
          ? List<String>.from(json['interests'] as List)
          : null,
      preferences: json['preferences'] as Map<String, dynamic>?,
    );
  }

  // Create from JSON string
  factory UserModel.fromJsonString(String jsonString) {
    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    return UserModel.fromJson(json);
  }

  // Convert to JSON string
  String toJsonString() {
    return jsonEncode(toJson());
  }

  // Equality
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  // String representation
  @override
  String toString() {
    return 'UserModel(id: $id, username: $username, email: $email)';
  }
}
