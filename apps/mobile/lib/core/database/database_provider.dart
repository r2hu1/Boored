import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_database.dart';
import 'daos/folders_dao.dart';
import 'daos/notes_dao.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

final foldersDaoProvider = Provider<FoldersDao>((ref) {
  final db = ref.watch(databaseProvider);
  return FoldersDao(db);
});

final notesDaoProvider = Provider<NotesDao>((ref) {
  final db = ref.watch(databaseProvider);
  return NotesDao(db);
});
