import 'package:isar/isar.dart';

import '../../domain/model/category.dart';
import '../../domain/model/enums.dart';
import '../../domain/repository/category_repository.dart';
import '../local/entities/category_entity.dart';

class LocalCategoryRepository implements CategoryRepository {
  LocalCategoryRepository(this._isar);
  final Isar _isar;

  @override
  Future<void> create(Category category) => _isar.writeTxn(() async {
        await _isar.categoryEntitys.put(CategoryEntity.fromDomain(category));
      });

  @override
  Future<Category?> findById(String id) async {
    final e = await _isar.categoryEntitys.filter().idEqualTo(id).findFirst();
    return e?.toDomain();
  }

  @override
  Future<List<Category>> listByFamily(
    String familyId, {
    CategoryType? type,
    bool includeArchived = false,
  }) async {
    var q = _isar.categoryEntitys
        .filter()
        .familyIdEqualTo(familyId)
        .isDeletedEqualTo(false);
    if (!includeArchived) q = q.isArchivedEqualTo(false);
    if (type != null) {
      final isarType = type == CategoryType.income
          ? IsarCategoryType.income
          : IsarCategoryType.expense;
      q = q.typeEqualTo(isarType);
    }
    final rows = await q.sortByIsSystemDesc().thenByName().findAll();
    return rows.map((e) => e.toDomain()).toList();
  }

  @override
  Future<void> update(Category category) => _isar.writeTxn(() async {
        await _isar.categoryEntitys.put(CategoryEntity.fromDomain(category));
      });

  @override
  Future<void> softDelete(String id) => _isar.writeTxn(() async {
        final e = await _isar.categoryEntitys.filter().idEqualTo(id).findFirst();
        if (e == null) return;
        e.isDeleted = true;
        e.updatedAt = DateTime.now().toUtc();
        await _isar.categoryEntitys.put(e);
      });

  @override
  Stream<List<Category>> watchByFamily(String familyId) => _isar.categoryEntitys
      .filter()
      .familyIdEqualTo(familyId)
      .isDeletedEqualTo(false)
      .isArchivedEqualTo(false)
      .sortByIsSystemDesc()
      .thenByName()
      .watch(fireImmediately: true)
      .map((rows) => rows.map((e) => e.toDomain()).toList());
}
