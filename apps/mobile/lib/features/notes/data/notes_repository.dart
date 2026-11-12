import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/daos/notes_dao.dart';
import '../../../core/database/database_provider.dart';

final notesRepositoryProvider = Provider<NotesRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return NotesRepository(NotesDao(db));
});

class NotesRepository {
  final NotesDao _dao;

  NotesRepository(this._dao);

  Stream<List<Note>> watchNotes(String userId) => _dao.watchAllNotes(userId);

  Future<List<Note>> searchNotes(String userId, String query) =>
      _dao.searchNotes(userId, query);

  Future<Note> createNote(String userId, String title) =>
      _dao.createNote(userId: userId, title: title);

  Future<void> updateTitle(String noteId, String newTitle) =>
      _dao.updateNote(noteId, title: newTitle);

  Future<void> updateStatus(String noteId, String status, {int? durationMs}) =>
      _dao.updateNote(noteId, status: status, durationMs: durationMs);

  Future<void> deleteNote(String noteId) => _dao.softDeleteNote(noteId);

  Future<void> restoreNote(String noteId) => _dao.restoreNote(noteId);

  Future<Note?> getNote(String noteId) => _dao.getNoteById(noteId);
}
