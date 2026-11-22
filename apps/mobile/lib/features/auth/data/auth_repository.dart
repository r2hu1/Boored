import 'package:google_sign_in/google_sign_in.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/api_constants.dart';
import 'auth_user.dart';

class AuthRepository {
  final ApiClient _apiClient;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  bool _isInitialized = false;

  AuthRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  Future<void> _ensureInitialized() async {
    if (_isInitialized) return;
    await _googleSignIn.initialize(
      serverClientId: ApiConstants.googleServerClientId.isNotEmpty
          ? ApiConstants.googleServerClientId
          : null,
    );
    _isInitialized = true;
  }

  /// Interactive sign in via Google Account Picker
  Future<AuthUser> signInWithGoogle() async {
    await _ensureInitialized();

    final account = await _googleSignIn.authenticate();
    final authentication = account.authentication;
    final idToken = authentication.idToken;

    if (idToken == null || idToken.isEmpty) {
      throw Exception('Failed to obtain Google ID Token');
    }

    final response = await _apiClient.dio.post(
      '/auth/google',
      data: {'id_token': idToken},
    );

    final accessToken = response.data['access_token'] as String;
    final refreshToken = response.data['refresh_token'] as String;
    final userData = response.data['user'] as Map<String, dynamic>;

    await _apiClient.tokenStorage.saveTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
    await _apiClient.tokenStorage.saveUserData(userData);

    return AuthUser.fromJson(userData);
  }

  /// Restore user session using stored tokens and cached user data
  Future<AuthUser?> getCurrentUser() async {
    final token = await _apiClient.tokenStorage.getAccessToken();
    if (token == null || token.isEmpty) return null;

    // Fast-path: return cached user data if already available locally
    final cached = await _apiClient.tokenStorage.getUserData();
    if (cached != null) {
      return AuthUser.fromJson(cached);
    }

    try {
      final response = await _apiClient.dio.get('/me');
      final userData = response.data as Map<String, dynamic>;
      await _apiClient.tokenStorage.saveUserData(userData);
      return AuthUser.fromJson(userData);
    } catch (_) {
      return null;
    }
  }

  Future<void> signOut() async {
    final refreshToken = await _apiClient.tokenStorage.getRefreshToken();
    if (refreshToken != null) {
      try {
        await _apiClient.dio.post(
          '/auth/logout',
          data: {'refresh_token': refreshToken},
        );
      } catch (_) {}
    }
    await _googleSignIn.signOut();
    await _apiClient.tokenStorage.clearTokens();
  }
}
