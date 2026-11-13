import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/notes_repository.dart';

class NotesState {
  final List<Note> allNotes;
  final List<Note> notes;
  final bool isLoading;
  final String? searchQuery;
  final String? errorMessage;

  const NotesState({
    this.allNotes = const [],
    this.notes = const [],
    this.isLoading = true,
    this.searchQuery,
    this.errorMessage,
  });

  NotesState copyWith({
    List<Note>? allNotes,
    List<Note>? notes,
    bool? isLoading,
    String? searchQuery,
    bool clearSearchQuery = false,
    String? errorMessage,
  }) {
    return NotesState(
      allNotes: allNotes ?? this.allNotes,
      notes: notes ?? this.notes,
      isLoading: isLoading ?? this.isLoading,
      searchQuery: clearSearchQuery ? null : (searchQuery ?? this.searchQuery),
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
      (allNotes) {
        final query = state.searchQuery?.trim().toLowerCase();
        final filtered = (query == null || query.isEmpty)
            ? allNotes
            : allNotes
                .where((n) => n.title.toLowerCase().contains(query))
                .toList();
        state = state.copyWith(
          allNotes: allNotes,
          notes: filtered,
          isLoading: false,
        );
      },
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

  void search(String query) {
    final trimmed = query.trim().toLowerCase();
    if (trimmed.isEmpty) {
      state = state.copyWith(
        notes: state.allNotes,
        clearSearchQuery: true,
      );
      return;
    }

    final filtered = state.allNotes
        .where((n) => n.title.toLowerCase().contains(trimmed))
        .toList();
    state = state.copyWith(
      searchQuery: query,
      notes: filtered,
    );
  }

  void clearSearch() {
    state = state.copyWith(
      notes: state.allNotes,
      clearSearchQuery: true,
    );
  }
}

final notesNotifierProvider =
    NotifierProvider<NotesNotifier, NotesState>(() => NotesNotifier());
