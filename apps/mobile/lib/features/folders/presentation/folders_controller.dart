import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../notes/data/notes_repository.dart';
import '../data/folders_repository.dart';

class FoldersState {
  final List<Folder> folders;
  final bool isLoading;
  final String? errorMessage;

  const FoldersState({
    this.folders = const [],
    this.isLoading = true,
    this.errorMessage,
  });

  FoldersState copyWith({
    List<Folder>? folders,
    bool? isLoading,
    String? errorMessage,
  }) {
    return FoldersState(
      folders: folders ?? this.folders,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class FoldersNotifier extends Notifier<FoldersState> {
  StreamSubscription<List<Folder>>? _subscription;

  @override
  FoldersState build() {
    final userId = ref.watch(authNotifierProvider).user?.id ?? 'local';
    final repo = ref.watch(foldersRepositoryProvider);

    _subscription?.cancel();
    _subscription = repo.watchFolders(userId).listen(
      (folders) {
        state = state.copyWith(
          folders: folders,
          isLoading: false,
        );
      },
      onError: (e) => state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      ),
    );

    ref.onDispose(() => _subscription?.cancel());

    return const FoldersState();
  }

  Future<Folder?> createFolder({required String name, String icon = '📁'}) async {
    final userId = ref.read(authNotifierProvider).user?.id ?? 'local';
    try {
      final repo = ref.read(foldersRepositoryProvider);
      return await repo.createFolder(
        userId: userId,
        name: name,
        icon: icon,
      );
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return null;
    }
  }

  Future<void> updateFolder(String folderId, {String? name, String? icon}) async {
    try {
      final repo = ref.read(foldersRepositoryProvider);
      await repo.updateFolder(folderId, name: name, icon: icon);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  Future<void> deleteFolder(String folderId) async {
    try {
      final repo = ref.read(foldersRepositoryProvider);
      await repo.deleteFolder(folderId);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }
}

final foldersNotifierProvider =
    NotifierProvider<FoldersNotifier, FoldersState>(() => FoldersNotifier());

final folderNoteCountProvider =
    StreamProvider.autoDispose.family<int, String>((ref, folderId) {
  final repo = ref.watch(foldersRepositoryProvider);
  return repo.watchNoteCount(folderId);
});

final folderByIdProvider =
    StreamProvider.autoDispose.family<Folder?, String>((ref, folderId) {
  final repo = ref.watch(foldersRepositoryProvider);
  return repo.watchFolder(folderId);
});

final notesInFolderProvider =
    StreamProvider.autoDispose.family<List<Note>, String>((ref, folderId) {
  final userId = ref.watch(authNotifierProvider).user?.id ?? 'local';
  final db = ref.watch(foldersRepositoryProvider);
  return db.watchFolders(userId).asyncExpand((_) {
    final notesRepo = ref.watch(notesRepositoryProvider);
    return notesRepo.watchNotesInFolder(userId, folderId);
  });
});
