class CategoryModel {
  final String id;
  final String? parentId;
  final String categoryName;
  final int categoryOrder;
  final String? categoryDesc;
  final String? categoryThumb;
  final bool isDefault;
  final DateTime createdAt;
  final int videoCount;
  final List<CategoryModel> children;

  CategoryModel({
    required this.id,
    this.parentId,
    required this.categoryName,
    required this.categoryOrder,
    this.categoryDesc,
    this.categoryThumb,
    required this.isDefault,
    required this.createdAt,
    this.videoCount = 0,
    this.children = const [],
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] as String,
      parentId: json['parentId'] as String?,
      categoryName: json['categoryName'] as String,
      categoryOrder: json['categoryOrder'] as int,
      categoryDesc: json['categoryDesc'] as String?,
      categoryThumb: json['categoryThumb'] as String?,
      isDefault: json['isDefault'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      videoCount: json['videoCount'] as int? ?? 0,
      children: (json['children'] as List<dynamic>?)
              ?.map((child) =>
                  CategoryModel.fromJson(child as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'parentId': parentId,
      'categoryName': categoryName,
      'categoryOrder': categoryOrder,
      'categoryDesc': categoryDesc,
      'categoryThumb': categoryThumb,
      'isDefault': isDefault,
      'createdAt': createdAt.toIso8601String(),
      'videoCount': videoCount,
      'children': children.map((child) => child.toJson()).toList(),
    };
  }
}
