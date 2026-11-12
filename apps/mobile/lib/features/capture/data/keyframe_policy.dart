import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/daos/keyframes_dao.dart';
import '../../../core/database/database_provider.dart';

final keyframesDaoProvider = Provider<KeyframesDao>((ref) {
  final db = ref.watch(databaseProvider);
  return KeyframesDao(db);
});

class KeyframePolicyManager {
  final KeyframesDao _dao;
  String? _lastSavedKeyframePath;
  String? _previousFramePath;
  int _keyframeIndex = 0;

  KeyframePolicyManager(this._dao);

  void reset() {
    _lastSavedKeyframePath = null;
    _previousFramePath = null;
    _keyframeIndex = 0;
  }

  /// Evaluates whether the enhanced frame should be committed as a persistent keyframe.
  /// Policy:
  /// 1. Always save the very first frame.
  /// 2. If ERASE is detected, the board was wiped: save previous frame before erase (if not saved)
  ///    and save current frame to capture fresh state.
  /// 3. If ADD has significant new content (diffRatio >= 4%), save as new keyframe.
  Future<Keyframe?> evaluateFrame({
    required String noteId,
    required String enhancedPath,
    required String eventType,
    required double diffRatio,
    required int timestampMs,
  }) async {
    bool shouldSave = false;
    String finalEvent = eventType;

    if (_lastSavedKeyframePath == null) {
      // Rule 1: First frame is always saved
      shouldSave = true;
      finalEvent = 'INITIAL';
    } else if (eventType == 'ERASE') {
      // Rule 2: Whiteboard erase detected. Save the state before it's gone
      shouldSave = true;
      finalEvent = 'ERASE';
    } else if (eventType == 'ADD' && diffRatio >= 0.04) {
      // Rule 3: Significant newly written content (>= 4% area difference)
      shouldSave = true;
      finalEvent = 'ADD';
    }

    _previousFramePath = enhancedPath;

    if (shouldSave) {
      final keyframe = await _dao.insertKeyframe(
        noteId: noteId,
        index: _keyframeIndex++,
        timestampMs: timestampMs,
        imagePath: enhancedPath,
        eventType: finalEvent,
      );
      _lastSavedKeyframePath = enhancedPath;
      return keyframe;
    }

    return null;
  }

  String? get previousFramePath => _previousFramePath;
}
