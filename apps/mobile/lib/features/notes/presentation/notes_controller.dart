import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/notes_repository.dart';

class NotesState {
  final List<Note> notes;
  final bool isLoading;
  final String? searchQuery;
  final String? errorMessage;

  const NotesState({
    this.notes = const [],
    this.isLoading = true,
    this.searchQuery,
    this.errorMessage,
  });

  NotesState copyWith({
    List<Note>? notes,
    bool? isLoading,
    String? searchQuery,
    String? errorMessage,
  }) {
    return NotesState(
      notes: notes ?? this.notes,
      isLoading: isLoading ?? this.isLoading,
      searchQuery: searchQuery,
      errorMessage: errorMessage,
    );
  }
}

class NotesNotifier extends Notifier<NotesState> {
  StreamSubscription<List<Note>>? _subscription;

  @override
  NotesState build() {
    final userId = ref.watch(authNotifierProvider).user?.id;
    if (userId == null) return const NotesState(isLoading: false);

    final repo = ref.watch(notesRepositoryProvider);

    _subscription?.cancel();
    _subscription = repo.watchNotes(userId).listen(
      (notes) => state = state.copyWith(notes: notes, isLoading: false),
      onError: (e) => state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      ),
    );

    ref.onDispose(() => _subscription?.cancel());

    return const NotesState();
  }

  Future<Note?> createNote(String title) async {
    final userId = ref.read(authNotifierProvider).user?.id;
    if (userId == null) return null;
    try {
      final repo = ref.read(notesRepositoryProvider);
      return await repo.createNote(userId, title);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return null;
    }
  }

  Future<void> deleteNote(String noteId) async {
    try {
      final repo = ref.read(notesRepositoryProvider);
      await repo.deleteNote(noteId);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  Future<void> restoreNote(String noteId) async {
    try {
      final repo = ref.read(notesRepositoryProvider);
      await repo.restoreNote(noteId);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  Future<void> updateNoteTitle(String noteId, String title) async {
    try {
      final repo = ref.read(notesRepositoryProvider);
      await repo.updateTitle(noteId, title);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  Future<void> search(String query) async {
    final userId = ref.read(authNotifierProvider).user?.id;
    if (userId == null) return;

    if (query.isEmpty) {
      state = state.copyWith(searchQuery: null);
      return;
    }

    state = state.copyWith(searchQuery: query, isLoading: true);
    try {
      final repo = ref.read(notesRepositoryProvider);
      final results = await repo.searchNotes(userId, query);
      state = state.copyWith(notes: results, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  void clearSearch() {
    state = state.copyWith(searchQuery: null);
  }
}

final notesNotifierProvider =
    NotifierProvider<NotesNotifier, NotesState>(() => NotesNotifier());
