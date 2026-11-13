import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:boored/features/home/presentation/home_screen.dart';
import 'package:boored/core/database/app_database.dart';
import 'package:boored/core/database/database_provider.dart';

void main() {
  testWidgets('HomeScreen shows title and empty state', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Boored'), findsOneWidget);
    expect(find.text('No notes yet'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);

    await db.close();
  });
}
