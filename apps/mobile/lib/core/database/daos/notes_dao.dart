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
  }) async {
    final now = DateTime.now();
    final id = generateId();
    final companion = NotesCompanion.insert(
      id: id,
      userId: userId,
      title: title,
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
    int? durationMs,
    DateTime? startedAt,
  }) {
    return (update(notes)..where((n) => n.id.equals(noteId))).write(
      NotesCompanion(
        title: title != null ? Value(title) : const Value.absent(),
        status: status != null ? Value(status) : const Value.absent(),
        durationMs:
            durationMs != null ? Value(durationMs) : const Value.absent(),
        startedAt:
            startedAt != null ? Value(startedAt) : const Value.absent(),
        updatedAt: Value(DateTime.now()),
        version: const Value.absent(),
      ),
    );
  }

  Future<void> softDeleteNote(String noteId) {
    return (update(notes)..where((n) => n.id.equals(noteId))).write(
      NotesCompanion(
        deletedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> restoreNote(String noteId) {
    return (update(notes)..where((n) => n.id.equals(noteId))).write(
      const NotesCompanion(
        deletedAt: Value(null),
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
