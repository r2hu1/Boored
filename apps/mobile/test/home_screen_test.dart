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

    // Verify New Folder card is rendered only when no folder is there,
    // and has folder card width (128) instead of stretching across the screen
    expect(find.text('New Folder'), findsOneWidget);
    final createFolderInkWell = find.ancestor(
      of: find.text('New Folder'),
      matching: find.byType(InkWell),
    );
    final cardSize = tester.getSize(createFolderInkWell.first);
    expect(cardSize.width, equals(128.0));

    await db.close();
  });

  testWidgets('HomeScreen does not show New Folder card when folders exist',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());

    // Insert a sample folder
    await db.into(db.folders).insert(
          FoldersCompanion.insert(
            id: 'test-folder-1',
            userId: 'local',
            name: 'Physics 101',
          ),
        );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Physics 101'), findsOneWidget);
    // When folders exist, New Folder card is not shown in the list
    expect(find.text('New Folder'), findsNothing);

    await db.close();
  });
}
