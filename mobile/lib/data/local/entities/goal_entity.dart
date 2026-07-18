import 'package:isar/isar.dart';

import '../../../domain/model/goal.dart';

part 'goal_entity.g.dart';

@collection
class GoalEntity {
  Id isarId = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String id;

  @Index()
  late String familyId;

  late String name;
  late int targetAmountKopecks;
  late int currentAmountKopecks;
  DateTime? targetDate;

  late DateTime createdAt;
  late DateTime updatedAt;
  late bool isDeleted;

  Goal toDomain() => Goal(
        id: id,
        familyId: familyId,
        name: name,
        targetAmountKopecks: targetAmountKopecks,
        currentAmountKopecks: currentAmountKopecks,
        targetDate: targetDate,
        createdAt: createdAt,
        updatedAt: updatedAt,
        isDeleted: isDeleted,
      );

  static GoalEntity fromDomain(Goal g) => GoalEntity()
    ..id = g.id
    ..familyId = g.familyId
    ..name = g.name
    ..targetAmountKopecks = g.targetAmountKopecks
    ..currentAmountKopecks = g.currentAmountKopecks
    ..targetDate = g.targetDate
    ..createdAt = g.createdAt
    ..updatedAt = g.updatedAt
    ..isDeleted = g.isDeleted;
}
