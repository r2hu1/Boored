import 'package:drift/drift.dart';
import '../app_database.dart';

part 'keyframes_dao.g.dart';

@DriftAccessor(tables: [Keyframes])
class KeyframesDao extends DatabaseAccessor<AppDatabase> with _$KeyframesDaoMixin {
  KeyframesDao(super.db);

  Stream<List<Keyframe>> watchKeyframesForNote(String noteId) {
    return (select(keyframes)
          ..where((k) => k.noteId.equals(noteId))
          ..orderBy([(k) => OrderingTerm.asc(k.index)]))
        .watch();
  }

  Future<List<Keyframe>> getKeyframesForNote(String noteId) {
    return (select(keyframes)
          ..where((k) => k.noteId.equals(noteId))
          ..orderBy([(k) => OrderingTerm.asc(k.index)]))
        .get();
  }

  Future<Keyframe> insertKeyframe({
    required String noteId,
    required int index,
    required int timestampMs,
    required String imagePath,
    String? thumbnailPath,
    String eventType = 'NONE',
  }) async {
    // Check if a keyframe for this imagePath already exists for this note
    final existing = await (select(keyframes)
          ..where((k) => k.noteId.equals(noteId) & k.imagePath.equals(imagePath)))
        .getSingleOrNull();
    if (existing != null) {
      return existing;
    }

    final id = generateId();
    final companion = KeyframesCompanion.insert(
      id: id,
      noteId: noteId,
      index: index,
      timestampMs: timestampMs,
      imagePath: imagePath,
      thumbnailPath: Value(thumbnailPath),
      eventType: Value(eventType),
    );
    await into(keyframes).insert(companion);
    return (select(keyframes)..where((k) => k.id.equals(id))).getSingle();
  }

  Future<void> updateKeyframeImageAndText(String id, String imagePath, String text) {
    return (update(keyframes)..where((k) => k.id.equals(id))).write(
      KeyframesCompanion(
        imagePath: Value(imagePath),
        extractedText: Value(text),
      ),
    );
  }

  Future<void> updateKeyframeText(String id, String text) {
    return (update(keyframes)..where((k) => k.id.equals(id))).write(
      KeyframesCompanion(
        extractedText: Value(text),
      ),
    );
  }

  Future<void> deleteKeyframe(String id) {
    return (delete(keyframes)..where((k) => k.id.equals(id))).go();
  }

  Future<void> deleteKeyframes(List<String> ids) {
    return (delete(keyframes)..where((k) => k.id.isIn(ids))).go();
  }

  Future<void> reindexKeyframes(String noteId) async {
    final remaining = await getKeyframesForNote(noteId);
    for (int i = 0; i < remaining.length; i++) {
      if (remaining[i].index != i) {
        await (update(keyframes)..where((k) => k.id.equals(remaining[i].id))).write(
          KeyframesCompanion(index: Value(i)),
        );
      }
    }
  }
}
