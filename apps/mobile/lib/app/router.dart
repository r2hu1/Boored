import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/notes/presentation/note_detail_screen.dart';
import '../../features/capture/presentation/capture_screen.dart';
import '../../features/capture/presentation/video_import_screen.dart';
import '../../features/folders/presentation/folder_detail_screen.dart';
import '../../features/settings/settings_screen.dart';

// Bridges Riverpod auth state changes to GoRouter's redirect re-evaluation
// without recreating the router instance.
class _AuthChangeNotifier extends ChangeNotifier {
  _AuthChangeNotifier(Ref ref) {
    ref.listen(authNotifierProvider, (prev, next) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = _AuthChangeNotifier(ref);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final authState = ref.read(authNotifierProvider);
      final isLoggedIn = authState.user != null;
      final isLoggingIn = state.matchedLocation == '/login';

      // Auth is only used for cloud backups: never block unauthenticated users from app content.
      // If a logged-in user is on /login, redirect them back to the main app.
      if (isLoggedIn && isLoggingIn) return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/notes/:id',
        builder: (context, state) => NoteDetailScreen(
          noteId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/capture/:id',
        builder: (context, state) {
          final noteId = state.pathParameters['id']!;
          final title = state.uri.queryParameters['title'] ?? 'Capture';
          return CaptureScreen(noteId: noteId, noteTitle: title);
        },
      ),
      GoRoute(
        path: '/import/:id',
        builder: (context, state) {
          final noteId = state.pathParameters['id']!;
          final title = state.uri.queryParameters['title'] ?? 'Import';
          final videoPath = state.uri.queryParameters['video'] ?? '';
          return VideoImportScreen(
            noteId: noteId,
            noteTitle: title,
            videoPath: videoPath,
          );
        },
      ),
      GoRoute(
        path: '/folders/:id',
        builder: (context, state) => FolderDetailScreen(
          folderId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
});
