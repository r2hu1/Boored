class ApiConstants {
  // Configurable base URL:
  // - Defaults to the active ngrok tunnel for seamless testing across physical devices & emulators
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://tadpole-relieved-moderately.ngrok-free.app/v1',
  );

  // Fallback / configurable web client ID matching backend GOOGLE_CLIENT_ID
  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_CLIENT_ID',
    defaultValue:
        '474507943902-cgkkvl0u89mdg4rvoob6r5vaobrsgqlv.apps.googleusercontent.com',
  );
}
