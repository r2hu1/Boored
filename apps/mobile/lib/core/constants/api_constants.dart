class ApiConstants {
  // Use 10.0.2.2 for Android Emulator connecting to host machine, localhost otherwise
  static const String baseUrl = 'http://10.0.2.2:3000/v1';

  // Fallback / configurable web client ID matching backend GOOGLE_CLIENT_ID
  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_CLIENT_ID',
    defaultValue:
        '474507943902-cgkkvl0u89mdg4rvoob6r5vaobrsgqlv.apps.googleusercontent.com',
  );
}
