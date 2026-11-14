import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'core/constants/api_constants.dart';
import 'app/router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables from .env
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // If .env is missing in dev/test, defaults from ApiConstants are used
  }
  
  // Explicitly initialize GoogleSignIn before UI runs
  await GoogleSignIn.instance.initialize(
    serverClientId: ApiConstants.googleServerClientId.isNotEmpty
        ? ApiConstants.googleServerClientId
        : null,
  );

  runApp(const ProviderScope(child: BooredApp()));
}

class BooredApp extends ConsumerWidget {
  const BooredApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Boored',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A1A2E),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A1A2E),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}
