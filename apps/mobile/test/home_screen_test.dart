import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:boored/features/home/presentation/home_screen.dart';

void main() {
  testWidgets('HomeScreen shows title and empty state', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: HomeScreen()),
      ),
    );

    expect(find.text('Boored'), findsOneWidget);
    expect(find.text('Your Notes'), findsOneWidget);
    expect(find.text('New Note'), findsOneWidget);
  });
}
