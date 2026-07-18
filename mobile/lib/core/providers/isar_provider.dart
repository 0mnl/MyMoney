import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

/// Isar database instance.
///
/// The initial schema list is empty in the skeleton; entities (see Bible § 25.5)
/// are added in Step 1 of the roadmap together with build_runner-generated
/// `*_entity.g.dart` files. Until then this provider returns an Isar instance
/// with no collections — enough to exercise the DI wiring and confirm the DB
/// file is created on disk.
final isarProvider = FutureProvider<Isar>((ref) async {
  final dir = await getApplicationDocumentsDirectory();
  final isar = await Isar.open(
    <CollectionSchema<Object>>[],
    directory: dir.path,
    name: 'mymoney',
    inspector: true,
  );
  ref.onDispose(() async {
    await isar.close();
  });
  return isar;
});
