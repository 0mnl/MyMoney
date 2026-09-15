import 'enums.dart';

class Category {
  final String id;
  final String familyId;
  final String? parentCategoryId;
  final String name;
  final CategoryType type;
  final bool isMandatory;
  final bool isSystem;
  final String? icon;
  final String? color;
  final bool isArchived;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Category({
    required this.id,
    required this.familyId,
    this.parentCategoryId,
    required this.name,
    required this.type,
    this.isMandatory = false,
    this.isSystem = false,
    this.icon,
    this.color,
    this.isArchived = false,
    this.isDeleted = false,
    required this.createdAt,
    required this.updatedAt,
  });

  /// `true`, если у категории есть родитель — то есть она подкатегория.
  bool get isSubcategory => parentCategoryId != null;

  Category copyWith({
    String? name,
    String? parentCategoryId,
    // Отдельный флаг, потому что `null` в parentCategoryId означает
    // «не менять», а не «сделать категорию корневой».
    bool clearParent = false,
    bool? isMandatory,
    String? icon,
    String? color,
    bool? isArchived,
    bool? isDeleted,
    DateTime? updatedAt,
  }) =>
      Category(
        id: id,
        familyId: familyId,
        parentCategoryId:
            clearParent ? null : (parentCategoryId ?? this.parentCategoryId),
        name: name ?? this.name,
        type: type,
        isMandatory: isMandatory ?? this.isMandatory,
        isSystem: isSystem,
        icon: icon ?? this.icon,
        color: color ?? this.color,
        isArchived: isArchived ?? this.isArchived,
        isDeleted: isDeleted ?? this.isDeleted,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
