import 'package:drift/drift.dart';
import '../app_database.dart';

part 'notes_dao.g.dart';

@DriftAccessor(tables: [Notes])
class NotesDao extends DatabaseAccessor<AppDatabase> with _$NotesDaoMixin {
  NotesDao(super.db);

  Stream<List<Note>> watchAllNotes(String userId) {
    return (select(notes)
          ..where((n) => n.userId.equals(userId) & n.deletedAt.isNull())
          ..orderBy([(n) => OrderingTerm.desc(n.updatedAt)]))
        .watch();
  }

  Stream<List<Note>> watchNotesInFolder(String userId, String folderId) {
    return (select(notes)
          ..where((n) =>
              n.userId.equals(userId) &
              n.folderId.equals(folderId) &
              n.deletedAt.isNull())
          ..orderBy([(n) => OrderingTerm.desc(n.updatedAt)]))
        .watch();
  }

  Stream<List<Note>> watchRootNotes(String userId) {
    return (select(notes)
          ..where((n) =>
              n.userId.equals(userId) &
              n.folderId.isNull() &
              n.deletedAt.isNull())
          ..orderBy([(n) => OrderingTerm.desc(n.updatedAt)]))
        .watch();
  }

  Stream<Note?> watchNote(String noteId) {
    return (select(notes)..where((n) => n.id.equals(noteId)))
        .watchSingleOrNull();
  }

  Future<List<Note>> searchNotes(String userId, String query) {
    final pattern = '%$query%';
    return (select(notes)
          ..where((n) =>
              n.userId.equals(userId) &
              n.deletedAt.isNull() &
              n.title.like(pattern))
          ..orderBy([(n) => OrderingTerm.desc(n.updatedAt)]))
        .get();
  }

  Future<Note> createNote({
    required String userId,
    required String title,
    String? folderId,
  }) async {
    final now = DateTime.now();
    final id = generateId();
    final companion = NotesCompanion.insert(
      id: id,
      userId: userId,
      title: title,
      folderId: Value(folderId),
      createdAt: Value(now),
      updatedAt: Value(now),
    );
    await into(notes).insert(companion);
    return (select(notes)..where((n) => n.id.equals(id))).getSingle();
  }

  Future<void> updateNote(
    String noteId, {
    String? title,
    String? status,
    String? folderId,
    int? durationMs,
    DateTime? startedAt,
  }) async {
    final existing = await getNoteById(noteId);
    final nextVersion = (existing?.version ?? 1) + 1;
    await (update(notes)..where((n) => n.id.equals(noteId))).write(
      NotesCompanion(
        title: title != null ? Value(title) : const Value.absent(),
        status: status != null ? Value(status) : const Value.absent(),
        folderId: folderId != null ? Value(folderId) : const Value.absent(),
        durationMs:
            durationMs != null ? Value(durationMs) : const Value.absent(),
        startedAt:
            startedAt != null ? Value(startedAt) : const Value.absent(),
        updatedAt: Value(DateTime.now()),
        version: Value(nextVersion),
        syncStatus: const Value('pending'),
      ),
    );
  }

  Future<void> softDeleteNote(String noteId) async {
    final existing = await getNoteById(noteId);
    final nextVersion = (existing?.version ?? 1) + 1;
    await (update(notes)..where((n) => n.id.equals(noteId))).write(
      NotesCompanion(
        deletedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
        version: Value(nextVersion),
        syncStatus: const Value('pending'),
      ),
    );
  }

  Future<void> restoreNote(String noteId) async {
    final existing = await getNoteById(noteId);
    final nextVersion = (existing?.version ?? 1) + 1;
    await (update(notes)..where((n) => n.id.equals(noteId))).write(
      NotesCompanion(
        deletedAt: const Value(null),
        updatedAt: Value(DateTime.now()),
        version: Value(nextVersion),
        syncStatus: const Value('pending'),
      ),
    );
  }

  Future<void> permanentlyDeleteNote(String noteId) {
    return (delete(notes)..where((n) => n.id.equals(noteId))).go();
  }

  Future<Note?> getNoteById(String noteId) {
    return (select(notes)..where((n) => n.id.equals(noteId)))
        .getSingleOrNull();
  }
}
