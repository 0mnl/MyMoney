import '../model/category.dart';
import '../model/enums.dart';

abstract class CategoryRepository {
  Future<void> create(Category category);
  Future<Category?> findById(String id);
  Future<List<Category>> listByFamily(
    String familyId, {
    CategoryType? type,
    bool includeArchived = false,
  });
  Future<void> update(Category category);
  Future<void> softDelete(String id);
  Stream<List<Category>> watchByFamily(String familyId);
}
