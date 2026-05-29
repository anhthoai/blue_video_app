// ignore_for_file: constant_identifier_names

class DatingProfile {
  final String userId;
  final String? username;
  final String? firstName;
  final String? lastName;
  final String? bio;
  final String? avatarUrl;
  final DateTime? updatedAt;
  final int? age;

  // Personal info
  final DateTime? dateOfBirth;
  final String? role;
  final int? heightCm;
  final int? weightKg;
  final String? bodyType;
  final String? bodyHair;
  final List<String> languages;
  final String? whereILive;
  final String? nationality;
  final String? ethnicity;
  final String? relationshipStatus;

  // Location
  final double? latitude;
  final double? longitude;
  final int? distanceKm;
  final bool? isOnline;
  final bool showDistance;
  final bool showOnline;
  final int maxDistanceKm;

  // Expectations
  final List<String> lookingFor;
  final List<String> whereToMeet;
  final List<String> preferredTribes;

  // AI matching
  final bool aiMatchingEnabled;

  // Public avatars (main avatar is user.avatarUrl, up to 5 extras here)
  final List<String> publicPhotos;

  // Dating subscription tier
  final String datingTier; // FREE | VIP | UNLIMITED
  final DateTime? datingTierExpiresAt;

  // Private album
  final int privateAlbumPhotoCount;
  final List<String> privateAlbumPhotos;
  final String? privateAlbumAccessStatus; // PENDING, ACCEPTED, DENIED, null

  const DatingProfile({
    required this.userId,
    this.username,
    this.firstName,
    this.lastName,
    this.bio,
    this.avatarUrl,
    this.updatedAt,
    this.age,
    this.dateOfBirth,
    this.role,
    this.heightCm,
    this.weightKg,
    this.bodyType,
    this.bodyHair,
    this.languages = const [],
    this.whereILive,
    this.nationality,
    this.ethnicity,
    this.relationshipStatus,
    this.latitude,
    this.longitude,
    this.distanceKm,
    this.isOnline,
    this.showDistance = true,
    this.showOnline = true,
    this.maxDistanceKm = 3,
    this.lookingFor = const [],
    this.whereToMeet = const [],
    this.preferredTribes = const [],
    this.aiMatchingEnabled = false,
    this.publicPhotos = const [],
    this.datingTier = 'FREE',
    this.datingTierExpiresAt,
    this.privateAlbumPhotoCount = 0,
    this.privateAlbumPhotos = const [],
    this.privateAlbumAccessStatus,
  });

  String get displayName {
    if (firstName != null && firstName!.isNotEmpty) return firstName!;
    return username ?? '';
  }

  factory DatingProfile.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;
    return DatingProfile(
      userId: (json['userId'] ?? user?['id'] ?? '') as String,
      username: (user?['username'] ?? json['username']) as String?,
      firstName: (user?['firstName'] ?? json['firstName']) as String?,
      lastName: (user?['lastName'] ?? json['lastName']) as String?,
      bio: (user?['bio'] ?? json['bio']) as String?,
      avatarUrl: (user?['avatarUrl'] ?? json['avatarUrl']) as String?,
        updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : (user != null && user['updatedAt'] != null
            ? DateTime.tryParse(user['updatedAt'].toString())
            : null),
      age: json['age'] as int?,
      dateOfBirth: json['dateOfBirth'] != null
          ? DateTime.tryParse(json['dateOfBirth'] as String)
          : null,
      role: json['role'] as String?,
      heightCm: json['heightCm'] as int?,
      weightKg: json['weightKg'] as int?,
      bodyType: json['bodyType'] as String?,
      bodyHair: json['bodyHair'] as String?,
      languages: _toStringList(json['languages']),
      whereILive: json['whereILive'] as String?,
      nationality: json['nationality'] as String?,
      ethnicity: json['ethnicity'] as String?,
      relationshipStatus: json['relationshipStatus'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      distanceKm: json['distanceKm'] as int?,
      isOnline: json['isOnline'] as bool?,
      showDistance: json['showDistance'] as bool? ?? true,
      showOnline: json['showOnline'] as bool? ?? true,
      maxDistanceKm: json['maxDistanceKm'] as int? ?? 3,
      lookingFor: _toStringList(json['lookingFor']),
      whereToMeet: _toStringList(json['whereToMeet']),
      preferredTribes: _toStringList(json['preferredTribes']),
      aiMatchingEnabled: json['aiMatchingEnabled'] as bool? ?? false,
        publicPhotos: _toStringList(json['publicPhotos']),
        datingTier: json['datingTier'] as String? ?? 'FREE',
        datingTierExpiresAt: json['datingTierExpiresAt'] != null
          ? DateTime.tryParse(json['datingTierExpiresAt'] as String)
          : null,
      privateAlbumPhotoCount: json['privateAlbumPhotoCount'] as int? ?? 0,
      privateAlbumPhotos: _toStringList(json['privateAlbumPhotos']),
      privateAlbumAccessStatus: json['privateAlbumAccessStatus'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'dateOfBirth': dateOfBirth?.toIso8601String(),
        'role': role,
        'heightCm': heightCm,
        'weightKg': weightKg,
        'bodyType': bodyType,
        'bodyHair': bodyHair,
        'languages': languages,
        'whereILive': whereILive,
        'nationality': nationality,
        'ethnicity': ethnicity,
        'relationshipStatus': relationshipStatus,
        'latitude': latitude,
        'longitude': longitude,
        'showDistance': showDistance,
        'showOnline': showOnline,
        'maxDistanceKm': maxDistanceKm,
        'lookingFor': lookingFor,
        'whereToMeet': whereToMeet,
        'preferredTribes': preferredTribes,
        'aiMatchingEnabled': aiMatchingEnabled,
        'publicPhotos': publicPhotos,
        'datingTier': datingTier,
        'datingTierExpiresAt': datingTierExpiresAt?.toIso8601String(),
      };

  DatingProfile copyWith({
    String? role,
    int? heightCm,
    int? weightKg,
    String? bodyType,
    String? bodyHair,
    List<String>? languages,
    String? whereILive,
    String? nationality,
    String? ethnicity,
    String? relationshipStatus,
    double? latitude,
    double? longitude,
    bool? showDistance,
    bool? showOnline,
    int? maxDistanceKm,
    List<String>? lookingFor,
    List<String>? whereToMeet,
    List<String>? preferredTribes,
    bool? aiMatchingEnabled,
    List<String>? publicPhotos,
    String? datingTier,
    DateTime? datingTierExpiresAt,
    DateTime? dateOfBirth,
  }) {
    return DatingProfile(
      userId: userId,
      username: username,
      firstName: firstName,
      lastName: lastName,
      bio: bio,
      avatarUrl: avatarUrl,
      updatedAt: updatedAt,
      age: age,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      role: role ?? this.role,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      bodyType: bodyType ?? this.bodyType,
      bodyHair: bodyHair ?? this.bodyHair,
      languages: languages ?? this.languages,
      whereILive: whereILive ?? this.whereILive,
      nationality: nationality ?? this.nationality,
      ethnicity: ethnicity ?? this.ethnicity,
      relationshipStatus: relationshipStatus ?? this.relationshipStatus,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      distanceKm: distanceKm,
      isOnline: isOnline,
      showDistance: showDistance ?? this.showDistance,
      showOnline: showOnline ?? this.showOnline,
      maxDistanceKm: maxDistanceKm ?? this.maxDistanceKm,
      lookingFor: lookingFor ?? this.lookingFor,
      whereToMeet: whereToMeet ?? this.whereToMeet,
      preferredTribes: preferredTribes ?? this.preferredTribes,
      aiMatchingEnabled: aiMatchingEnabled ?? this.aiMatchingEnabled,
      publicPhotos: publicPhotos ?? this.publicPhotos,
      datingTier: datingTier ?? this.datingTier,
      datingTierExpiresAt: datingTierExpiresAt ?? this.datingTierExpiresAt,
      privateAlbumPhotoCount: privateAlbumPhotoCount,
      privateAlbumPhotos: privateAlbumPhotos,
      privateAlbumAccessStatus: privateAlbumAccessStatus,
    );
  }

  static List<String> _toStringList(dynamic value) {
    if (value == null) return [];
    if (value is List) return value.cast<String>();
    return [];
  }
}

class DatingExploreUser {
  final String userId;
  final String? username;
  final String? firstName;
  final String? lastName;
  final String? avatarUrl;
  final DateTime? updatedAt;
  final int? age;
  final int? distanceKm;
  final bool? isOnline;
  final bool isSelf;
  final String? role;
  final String? bodyType;
  final List<String> lookingFor;
  final List<String> preferredTribes;

  const DatingExploreUser({
    required this.userId,
    this.username,
    this.firstName,
    this.lastName,
    this.avatarUrl,
    this.updatedAt,
    this.age,
    this.distanceKm,
    this.isOnline,
    this.isSelf = false,
    this.role,
    this.bodyType,
    this.lookingFor = const [],
    this.preferredTribes = const [],
  });

  String get displayName {
    if (firstName != null && firstName!.isNotEmpty) return firstName!;
    return username ?? '';
  }

  factory DatingExploreUser.fromJson(Map<String, dynamic> json) {
    return DatingExploreUser(
      userId: (json['userId'] ?? json['id'] ?? '') as String,
      username: json['username'] as String?,
      firstName: json['firstName'] as String?,
      lastName: json['lastName'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
      age: json['age'] as int?,
      distanceKm: json['distanceKm'] as int?,
      isOnline: json['isOnline'] as bool?,
      isSelf: json['isSelf'] == true,
      role: json['role'] as String?,
      bodyType: json['bodyType'] as String?,
      lookingFor: DatingProfile._toStringList(json['lookingFor']),
      preferredTribes: DatingProfile._toStringList(json['preferredTribes']),
    );
  }
}

class DatingMatchUser {
  final String matchId;
  final DateTime matchedAt;
  final DatingExploreUser user;

  const DatingMatchUser({
    required this.matchId,
    required this.matchedAt,
    required this.user,
  });

  factory DatingMatchUser.fromJson(Map<String, dynamic> json) {
    return DatingMatchUser(
      matchId: json['matchId'] as String,
      matchedAt: DateTime.tryParse(json['matchedAt']?.toString() ?? '') ?? DateTime.now(),
      user: DatingExploreUser.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}

class DatingSuggestedMatch {
  final DatingExploreUser user;
  final int score;
  final List<String> reasons;

  const DatingSuggestedMatch({
    required this.user,
    required this.score,
    this.reasons = const [],
  });

  factory DatingSuggestedMatch.fromJson(Map<String, dynamic> json) {
    return DatingSuggestedMatch(
      user: DatingExploreUser.fromJson(json),
      score: json['score'] as int? ?? 0,
      reasons: DatingProfile._toStringList(json['reasons']),
    );
  }
}

class DatingSuggestionMeta {
  final int maxPerDay;
  final int remainingToday;
  final bool aiEnabled;
  final String tier;

  const DatingSuggestionMeta({
    required this.maxPerDay,
    required this.remainingToday,
    required this.aiEnabled,
    required this.tier,
  });

  factory DatingSuggestionMeta.fromJson(Map<String, dynamic> json) {
    return DatingSuggestionMeta(
      maxPerDay: json['maxPerDay'] as int? ?? 3,
      remainingToday: json['remainingToday'] as int? ?? 0,
      aiEnabled: json['aiEnabled'] == true,
      tier: json['tier'] as String? ?? 'FREE',
    );
  }
}

class DatingSuggestionResult {
  final List<DatingSuggestedMatch> suggestions;
  final DatingSuggestionMeta meta;

  const DatingSuggestionResult({
    required this.suggestions,
    required this.meta,
  });

  factory DatingSuggestionResult.fromJson(Map<String, dynamic> json) {
    final rawList = (json['data'] as List<dynamic>? ?? const []);
    final rawMeta = json['meta'] as Map<String, dynamic>? ?? const {};

    return DatingSuggestionResult(
      suggestions: rawList
          .map((item) => DatingSuggestedMatch.fromJson(item as Map<String, dynamic>))
          .toList(),
      meta: DatingSuggestionMeta.fromJson(rawMeta),
    );
  }
}

class PrivateAlbumAccessRequest {
  final String id;
  final String albumId;
  final String requesterId;
  final String ownerId;
  final String status; // PENDING, ACCEPTED, DENIED
  final String? message;
  final DateTime createdAt;
  final Map<String, dynamic>? requester;

  const PrivateAlbumAccessRequest({
    required this.id,
    required this.albumId,
    required this.requesterId,
    required this.ownerId,
    required this.status,
    this.message,
    required this.createdAt,
    this.requester,
  });

  factory PrivateAlbumAccessRequest.fromJson(Map<String, dynamic> json) {
    return PrivateAlbumAccessRequest(
      id: json['id'] as String,
      albumId: json['albumId'] as String,
      requesterId: json['requesterId'] as String,
      ownerId: json['ownerId'] as String,
      status: json['status'] as String,
      message: json['message'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      requester: json['requester'] as Map<String, dynamic>?,
    );
  }
}

class DatingUpgradeDuration {
  final String key; // 1W | 1M | 3M | 12M
  final String label;
  final int coins;

  const DatingUpgradeDuration({
    required this.key,
    required this.label,
    required this.coins,
  });

  factory DatingUpgradeDuration.fromJson(Map<String, dynamic> json) {
    return DatingUpgradeDuration(
      key: json['key'] as String,
      label: json['label'] as String,
      coins: json['coins'] as int? ?? 0,
    );
  }
}

class DatingUpgradePlan {
  final String tier; // VIP | UNLIMITED
  final int? maxProfiles;
  final List<DatingUpgradeDuration> durations;

  const DatingUpgradePlan({
    required this.tier,
    required this.maxProfiles,
    required this.durations,
  });

  factory DatingUpgradePlan.fromJson(Map<String, dynamic> json) {
    final rawDurations = (json['durations'] as List<dynamic>? ?? const []);
    return DatingUpgradePlan(
      tier: json['tier'] as String,
      maxProfiles: json['maxProfiles'] as int?,
      durations: rawDurations
          .map((item) => DatingUpgradeDuration.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class DatingUpgradeStatus {
  final String tier; // FREE | VIP | UNLIMITED
  final DateTime? expiresAt;
  final int? viewLimit;
  final int coinBalance;

  const DatingUpgradeStatus({
    required this.tier,
    this.expiresAt,
    this.viewLimit,
    this.coinBalance = 0,
  });

  factory DatingUpgradeStatus.fromJson(Map<String, dynamic> json) {
    return DatingUpgradeStatus(
      tier: json['tier'] as String? ?? 'FREE',
      expiresAt: json['expiresAt'] != null
          ? DateTime.tryParse(json['expiresAt'] as String)
          : null,
      viewLimit: json['viewLimit'] as int?,
      coinBalance: json['coinBalance'] as int? ?? 0,
    );
  }
}

// ─── Constants ────────────────────────────────────────────────────────────────

class DatingConstants {
  static const List<String> roles = [
    'TOP',
    'BOTTOM',
    'VERSATILE',
    'VERSATILE_TOP',
    'VERSATILE_BOTTOM',
    'SIDE',
    'UNDISCLOSED',
  ];

  static const Map<String, String> roleLabels = {
    'TOP': 'Top',
    'BOTTOM': 'Bottom',
    'VERSATILE': 'Versatile',
    'VERSATILE_TOP': 'Versatile Top',
    'VERSATILE_BOTTOM': 'Versatile Bottom',
    'SIDE': 'Side',
    'UNDISCLOSED': 'Undisclosed',
  };

  static const List<String> bodyTypes = [
    'SLIM',
    'AVERAGE',
    'FIT',
    'TONED',
    'MUSCULAR',
    'STOCKY',
    'LARGE',
    'CHUBBY',
    'UNDISCLOSED',
    'OTHER',
  ];

  static const Map<String, String> bodyTypeLabels = {
    'SLIM': 'Slim',
    'AVERAGE': 'Average',
    'FIT': 'Fit',
    'TONED': 'Toned',
    'MUSCULAR': 'Muscular',
    'STOCKY': 'Stocky',
    'LARGE': 'Large',
    'CHUBBY': 'Chubby',
    'UNDISCLOSED': 'Undisclosed',
    'OTHER': 'Other',
  };

  static const List<String> bodyHairs = [
    'SMOOTH',
    'SHAVED',
    'SOME_HAIR',
    'HAIRY',
    'OTHER',
  ];

  static const Map<String, String> bodyHairLabels = {
    'SMOOTH': 'Smooth',
    'SHAVED': 'Shaved',
    'SOME_HAIR': 'Some Hair',
    'HAIRY': 'Hairy',
    'OTHER': 'Other',
  };

  static const List<String> ethnicities = [
    'ASIAN',
    'BLACK',
    'LATINO',
    'MIDDLE_EASTERN',
    'WHITE',
    'SOUTH_ASIAN',
    'MIXED',
    'UNDISCLOSED',
    'OTHER',
  ];

  static const Map<String, String> ethnicityLabels = {
    'ASIAN': 'Asian',
    'BLACK': 'Black',
    'LATINO': 'Latino',
    'MIDDLE_EASTERN': 'Middle Eastern',
    'WHITE': 'White',
    'SOUTH_ASIAN': 'South Asian',
    'MIXED': 'Mixed',
    'UNDISCLOSED': 'Undisclosed',
    'OTHER': 'Other',
  };

  static const List<String> relationshipStatuses = [
    'EXCLUSIVE',
    'DATING',
    'SINGLE',
    'MARRIED',
    'OPEN_RELATIONSHIP',
    'PARTNERED',
    'UNDISCLOSED',
  ];

  static const Map<String, String> relationshipStatusLabels = {
    'EXCLUSIVE': 'Exclusive',
    'DATING': 'Dating',
    'SINGLE': 'Single',
    'MARRIED': 'Married',
    'OPEN_RELATIONSHIP': 'Open Relationship',
    'PARTNERED': 'Partnered',
    'UNDISCLOSED': 'Undisclosed',
  };

  static const List<String> lookingForOptions = [
    'chat',
    'date',
    'friends',
    'romantic',
    'relationship',
    'right_now',
  ];

  static const Map<String, String> lookingForLabels = {
    'chat': 'Chat',
    'date': 'Date',
    'friends': 'Friends',
    'romantic': 'Romantic',
    'relationship': 'Relationship',
    'right_now': 'Right Now',
  };

  static const List<String> whereToMeetOptions = [
    'my_location',
    'his_location',
    'bar',
    'coffee_shop',
    'restaurant',
    'self_drive',
    'private_cinema',
  ];

  static const Map<String, String> whereToMeetLabels = {
    'my_location': 'My Location',
    'his_location': 'His Location',
    'bar': 'Bar',
    'coffee_shop': 'Coffee Shop',
    'restaurant': 'Restaurant',
    'self_drive': 'Self-drive Date',
    'private_cinema': 'Private Cinema',
  };

  static const List<String> tribes = [
    'daddy',
    'discreet',
    'twink',
    'bear',
    'cub',
    'jock',
    'trans',
    'bisexual',
    'clean_cut',
    'leather',
    'rugger',
    'drag_queens',
    'queer',
    'wolf',
    'other',
  ];

  static const Map<String, String> tribeLabels = {
    'daddy': 'Daddy',
    'discreet': 'Discreet',
    'twink': 'Twink',
    'bear': 'Bear',
    'cub': 'Cub',
    'jock': 'Jock',
    'trans': 'Trans',
    'bisexual': 'Bisexual',
    'clean_cut': 'Clean-cut',
    'leather': 'Leather',
    'rugger': 'Rugger',
    'drag_queens': 'Drag Queens',
    'queer': 'Queer',
    'wolf': 'Wolf',
    'other': 'Other',
  };

  static const List<String> languages = [
    'English',
    'Spanish',
    'French',
    'German',
    'Portuguese',
    'Italian',
    'Japanese',
    'Korean',
    'Chinese',
    'Thai',
    'Vietnamese',
    'Arabic',
    'Russian',
    'Indonesian',
    'Malay',
    'Hindi',
    'Dutch',
    'Turkish',
    'Polish',
    'Swedish',
  ];
}
