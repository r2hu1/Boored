import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../data/auth_repository.dart';
import '../data/auth_user.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

class AuthState {
  final bool isLoading;
  final AuthUser? user;
  final String? errorMessage;

  const AuthState({
    this.isLoading = false,
    this.user,
    this.errorMessage,
  });

  AuthState copyWith({
    bool? isLoading,
    AuthUser? user,
    String? errorMessage,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      user: user ?? this.user,
      errorMessage: errorMessage,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  late final AuthRepository _repository;

  @override
  AuthState build() {
    _repository = ref.watch(authRepositoryProvider);
    // Background auth check for backups - does not block initial app content rendering
    Future.microtask(() => checkCurrentUser());
    return const AuthState(isLoading: false);
  }

  Future<void> checkCurrentUser() async {
    // Run silently in background without setting isLoading=true so UI is never blocked
    try {
      final user = await _repository.getCurrentUser();
      if (user != null) {
        state = state.copyWith(user: user, isLoading: false);
        await _migrateLocalData(user.id);
      }
    } catch (_) {
      // Background check failure should not disrupt local note-taking
    }
  }

  Future<void> _migrateLocalData(String userId) async {
    try {
      final db = ref.read(databaseProvider);
      await (db.update(db.notes)..where((n) => n.userId.equals('local'))).write(
        NotesCompanion(userId: Value(userId)),
      );
      await (db.update(db.folders)..where((f) => f.userId.equals('local'))).write(
        FoldersCompanion(userId: Value(userId)),
      );
    } catch (_) {}
  }

  Future<void> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final user = await _repository.signInWithGoogle();
      state = state.copyWith(isLoading: false, user: user);
      await _migrateLocalData(user.id);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> signOut() async {
    state = state.copyWith(isLoading: true);
    await _repository.signOut();
    state = const AuthState(isLoading: false, user: null);
  }
}

final authNotifierProvider =
    NotifierProvider<AuthNotifier, AuthState>(() => AuthNotifier());
