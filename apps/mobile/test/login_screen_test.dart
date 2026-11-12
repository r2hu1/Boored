import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:boored/features/auth/presentation/login_screen.dart';
import 'package:boored/features/auth/presentation/auth_controller.dart';
import 'package:boored/features/auth/data/auth_repository.dart';
import 'package:boored/features/auth/data/auth_user.dart';

class MockAuthRepository extends AuthRepository {
  @override
  Future<AuthUser> signInWithGoogle() async {
    return const AuthUser(
      id: '00000000-0000-0000-0000-000000000001',
      email: 'test@example.com',
      name: 'Test User',
    );
  }

  @override
  Future<AuthUser?> getCurrentUser() async => null;

  @override
  Future<void> signOut() async {}
}

void main() {
  testWidgets('LoginScreen renders brand title and Google sign-in button',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(MockAuthRepository()),
        ],
        child: const MaterialApp(home: LoginScreen()),
      ),
    );

    // Let the initial microtask (checkCurrentUser) complete
    await tester.pumpAndSettle();

    expect(find.text('Boored'), findsOneWidget);
    expect(find.text('Sign in with Google'), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget);
  });
}
