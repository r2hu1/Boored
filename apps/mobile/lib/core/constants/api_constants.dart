import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConstants {
  // Reads from .env file first, then --dart-define, and defaults to local if not set
  static String get baseUrl {
    if (dotenv.isInitialized) {
      final envUrl = dotenv.env['API_BASE_URL'];
      if (envUrl != null && envUrl.isNotEmpty) return envUrl;
    }
    return const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'https://boored-api.vercel.app/v1',
    );
  }

  static String get googleServerClientId {
    if (dotenv.isInitialized) {
      final envClientId = dotenv.env['GOOGLE_CLIENT_ID'];
      if (envClientId != null && envClientId.isNotEmpty) return envClientId;
    }
    return const String.fromEnvironment(
      'GOOGLE_CLIENT_ID',
      defaultValue:
          '474507943902-cgkkvl0u89mdg4rvoob6r5vaobrsgqlv.apps.googleusercontent.com',
    );
  }
}
