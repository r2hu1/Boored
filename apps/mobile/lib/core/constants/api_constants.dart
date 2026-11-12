class ApiConstants {
  // Configurable base URL:
  // - On Android Emulator: http://10.0.2.2:3000/v1
  // - On Physical Android via USB reverse: http://127.0.0.1:3000/v1 (run `adb reverse tcp:3000 tcp:3000`)
  // - On Local Wi-Fi: http://<mac-ip>:3000/v1
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000/v1',
  );

  // Fallback / configurable web client ID matching backend GOOGLE_CLIENT_ID
  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_CLIENT_ID',
    defaultValue:
        '474507943902-cgkkvl0u89mdg4rvoob6r5vaobrsgqlv.apps.googleusercontent.com',
  );
}
