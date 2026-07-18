import 'package:isar/isar.dart';

import '../../../domain/model/category.dart';
import '../../../domain/model/enums.dart';

part 'category_entity.g.dart';

/// Values of this enum are persisted by name — do not renumber or rename.
enum IsarCategoryType { income, expense }

@collection
class CategoryEntity {
  Id isarId = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String id;

  @Index()
  late String familyId;

  String? parentCategoryId;
  late String name;

  @enumerated
  late IsarCategoryType type;

  late bool isMandatory;
  late bool isSystem;
  String? icon;
  String? color;
  late bool isArchived;
  late bool isDeleted;
  late DateTime createdAt;
  late DateTime updatedAt;

  Category toDomain() => Category(
        id: id,
        familyId: familyId,
        parentCategoryId: parentCategoryId,
        name: name,
        type: type == IsarCategoryType.income ? CategoryType.income : CategoryType.expense,
        isMandatory: isMandatory,
        isSystem: isSystem,
        icon: icon,
        color: color,
        isArchived: isArchived,
        isDeleted: isDeleted,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  static CategoryEntity fromDomain(Category c) => CategoryEntity()
    ..id = c.id
    ..familyId = c.familyId
    ..parentCategoryId = c.parentCategoryId
    ..name = c.name
    ..type = c.type == CategoryType.income ? IsarCategoryType.income : IsarCategoryType.expense
    ..isMandatory = c.isMandatory
    ..isSystem = c.isSystem
    ..icon = c.icon
    ..color = c.color
    ..isArchived = c.isArchived
    ..isDeleted = c.isDeleted
    ..createdAt = c.createdAt
    ..updatedAt = c.updatedAt;
}
