import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/network/api_client.dart';
import '../auth/presentation/auth_controller.dart';

enum SyncStatus { idle, syncing, success, failed }

class SyncState {
  final SyncStatus status;
  final String? lastSyncTime;
  final String? errorMessage;
  final int pendingCount;

  const SyncState({
    this.status = SyncStatus.idle,
    this.lastSyncTime,
    this.errorMessage,
    this.pendingCount = 0,
  });

  SyncState copyWith({
    SyncStatus? status,
    String? lastSyncTime,
    String? errorMessage,
    int? pendingCount,
  }) {
    return SyncState(
      status: status ?? this.status,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      errorMessage: errorMessage,
      pendingCount: pendingCount ?? this.pendingCount,
    );
  }
}

class SyncNotifier extends Notifier<SyncState> {
  late final ApiClient _apiClient;
  late final AppDatabase _db;

  @override
  SyncState build() {
    _apiClient = ApiClient();
    _db = ref.watch(databaseProvider);
    Future.microtask(() => _checkPendingCount());
    return const SyncState();
  }

  Future<void> _checkPendingCount() async {
    final user = ref.read(authNotifierProvider).user;
    if (user == null) {
      state = state.copyWith(pendingCount: 0);
      return;
    }
    final pendingNotes = await (_db.select(_db.notes)
          ..where((n) => n.syncStatus.equals('pending') & n.userId.equals(user.id)))
        .get();
    final pendingKeyframes = await (_db.select(_db.keyframes)
          ..where((k) => k.syncStatus.equals('pending')))
        .get();
    state = state.copyWith(pendingCount: pendingNotes.length + pendingKeyframes.length);
  }

  Future<void> syncNow() async {
    final user = ref.read(authNotifierProvider).user;
    if (user == null) return;

    state = state.copyWith(status: SyncStatus.syncing, errorMessage: null);

    try {
      // 1. Collect pending notes and keyframes
      final pendingNotes = await (_db.select(_db.notes)
            ..where((n) => n.syncStatus.equals('pending') & n.userId.equals(user.id)))
          .get();

      final pendingKeyframes = await (_db.select(_db.keyframes)
            ..where((k) => k.syncStatus.equals('pending')))
          .get();

      // 2. Push local pending changes to backend
      if (pendingNotes.isNotEmpty || pendingKeyframes.isNotEmpty) {
        final pushBody = {
          'notes': pendingNotes.map((n) => {
                'id': n.id,
                'title': n.title,
                'status': n.status,
                'duration_ms': n.durationMs,
                'version': n.version,
                'deleted_at': n.deletedAt?.toIso8601String(),
              }).toList(),
          'keyframes': pendingKeyframes.map((k) => {
                'id': k.id,
                'note_id': k.noteId,
                'index': k.index,
                'timestamp_ms': k.timestampMs,
                'event_type': k.eventType,
                'image_key': k.imagePath,
              }).toList(),
        };

        final response = await _apiClient.dio.post('/sync/push', data: pushBody);
        if (response.statusCode == 200) {
          for (final n in pendingNotes) {
            await (_db.update(_db.notes)..where((tbl) => tbl.id.equals(n.id))).write(
              const NotesCompanion(syncStatus: Value('synced')),
            );
          }
          for (final k in pendingKeyframes) {
            await (_db.update(_db.keyframes)..where((tbl) => tbl.id.equals(k.id))).write(
              const KeyframesCompanion(syncStatus: Value('synced')),
            );
          }
        }
      }

      // 3. Pull remote changes
      final pullResponse = await _apiClient.dio.get('/sync/pull');
      if (pullResponse.statusCode == 200) {
        final remoteNotes = pullResponse.data['notes'] as List<dynamic>;

        for (final r in remoteNotes) {
          final noteId = r['id'] as String;
          final title = r['title'] as String;
          final status = r['status'] as String;
          final version = r['version'] as int;
          final deletedAtStr = r['deleted_at'] as String?;
          final deletedAt = deletedAtStr != null ? DateTime.parse(deletedAtStr) : null;

          final localExistingList = await (_db.select(_db.notes)
                ..where((tbl) => tbl.id.equals(noteId)))
              .get();

          if (localExistingList.isNotEmpty) {
            final localExisting = localExistingList.first;
            if (version >= localExisting.version) {
              await (_db.update(_db.notes)..where((tbl) => tbl.id.equals(noteId))).write(
                NotesCompanion(
                  title: Value(title),
                  status: Value(status),
                  version: Value(version),
                  deletedAt: Value(deletedAt),
                  syncStatus: const Value('synced'),
                ),
              );
            }
          } else {
            // Only insert non-deleted notes from remote
            if (deletedAt == null) {
              await _db.into(_db.notes).insert(
                    NotesCompanion.insert(
                      id: noteId,
                      userId: user.id,
                      title: title,
                      status: Value(status),
                      version: Value(version),
                      deletedAt: const Value(null),
                      syncStatus: const Value('synced'),
                    ),
                  );
            }
          }
        }
      }

      await _checkPendingCount();
      state = state.copyWith(
        status: SyncStatus.success,
        lastSyncTime: DateTime.now().toIso8601String(),
      );
    } catch (e) {
      state = state.copyWith(
        status: SyncStatus.failed,
        errorMessage: e.toString(),
      );
    }
  }
}

final syncNotifierProvider =
    NotifierProvider<SyncNotifier, SyncState>(() => SyncNotifier());
