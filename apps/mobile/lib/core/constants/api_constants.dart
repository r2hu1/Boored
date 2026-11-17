import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConstants {
  // Directly prioritized from --dart-define (injected at build time), then .env if loaded
  static String get baseUrl {
    const dartDefine = String.fromEnvironment('API_BASE_URL');
    if (dartDefine.isNotEmpty) {
      return dartDefine.trim();
    }
    if (dotenv.isInitialized) {
      final envUrl = dotenv.env['API_BASE_URL'];
      if (envUrl != null && envUrl.trim().isNotEmpty) {
        return envUrl.trim();
      }
    }
    return 'https://boored-api.vercel.app/v1';
  }

  static String get googleServerClientId {
    const dartDefine = String.fromEnvironment('GOOGLE_CLIENT_ID');
    if (dartDefine.isNotEmpty) {
      return dartDefine.trim();
    }
    if (dotenv.isInitialized) {
      final envClientId = dotenv.env['GOOGLE_CLIENT_ID'];
      if (envClientId != null && envClientId.trim().isNotEmpty) {
        return envClientId.trim();
      }
    }
    return '474507943902-cgkkvl0u89mdg4rvoob6r5vaobrsgqlv.apps.googleusercontent.com';
  }
}
