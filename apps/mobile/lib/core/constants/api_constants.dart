import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConstants {
  // Reads strictly from .env if present and loaded; otherwise falls back to --dart-define
  static String get baseUrl {
    if (dotenv.isInitialized) {
      final envUrl = dotenv.env['API_BASE_URL'];
      if (envUrl != null && envUrl.trim().isNotEmpty) {
        return envUrl.trim();
      }
    }
    return const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: '',
    );
  }

  static String get googleServerClientId {
    if (dotenv.isInitialized) {
      final envClientId = dotenv.env['GOOGLE_CLIENT_ID'];
      if (envClientId != null && envClientId.trim().isNotEmpty) {
        return envClientId.trim();
      }
    }
    return const String.fromEnvironment(
      'GOOGLE_CLIENT_ID',
      defaultValue: '',
    );
  }
}
