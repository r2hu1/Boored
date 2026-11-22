import 'package:drift/drift.dart';
import '../app_database.dart';

part 'folders_dao.g.dart';

@DriftAccessor(tables: [Folders, Notes])
class FoldersDao extends DatabaseAccessor<AppDatabase> with _$FoldersDaoMixin {
  FoldersDao(super.db);

  Stream<List<Folder>> watchAllFolders(String userId) {
    return (select(folders)
          ..where((f) => f.userId.equals(userId) & f.deletedAt.isNull())
          ..orderBy([(f) => OrderingTerm.asc(f.name)]))
        .watch();
  }

  Future<List<Folder>> getAllFolders(String userId) {
    return (select(folders)
          ..where((f) => f.userId.equals(userId) & f.deletedAt.isNull())
          ..orderBy([(f) => OrderingTerm.asc(f.name)]))
        .get();
  }

  Stream<Folder?> watchFolder(String folderId) {
    return (select(folders)..where((f) => f.id.equals(folderId)))
        .watchSingleOrNull();
  }

  Future<Folder?> getFolderById(String folderId) {
    return (select(folders)..where((f) => f.id.equals(folderId)))
        .getSingleOrNull();
  }

  Future<Folder> createFolder({
    required String userId,
    required String name,
    String icon = '📁',
  }) async {
    final now = DateTime.now();
    final id = generateId();
    final companion = FoldersCompanion.insert(
      id: id,
      userId: userId,
      name: name,
      icon: Value(icon),
      createdAt: Value(now),
      updatedAt: Value(now),
    );
    await into(folders).insert(companion);
    return (select(folders)..where((f) => f.id.equals(id))).getSingle();
  }

  Future<void> updateFolder(
    String folderId, {
    String? name,
    String? icon,
  }) async {
    await (update(folders)..where((f) => f.id.equals(folderId))).write(
      FoldersCompanion(
        name: name != null ? Value(name) : const Value.absent(),
        icon: icon != null ? Value(icon) : const Value.absent(),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> deleteFolder(String folderId) async {
    // Unlink notes from this folder
    await (update(notes)..where((n) => n.folderId.equals(folderId))).write(
      const NotesCompanion(folderId: Value(null)),
    );
    // Soft delete the folder
    await (update(folders)..where((f) => f.id.equals(folderId))).write(
      FoldersCompanion(
        deletedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Stream<int> watchNoteCountForFolder(String folderId) {
    final count = notes.id.count();
    final query = selectOnly(notes)
      ..addColumns([count])
      ..where(notes.folderId.equals(folderId) & notes.deletedAt.isNull());
    return query.map((row) => row.read(count) ?? 0).watchSingle();
  }
}
