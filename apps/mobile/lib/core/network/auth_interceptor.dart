import 'package:dio/dio.dart';
import '../storage/token_storage.dart';
import '../constants/api_constants.dart';

class AuthInterceptor extends QueuedInterceptor {
  final TokenStorage tokenStorage;
  final Dio dio;

  AuthInterceptor({
    required this.tokenStorage,
    required this.dio,
  });

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await tokenStorage.getAccessToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode == 401 &&
        !err.requestOptions.path.contains('/auth/')) {
      final refreshToken = await tokenStorage.getRefreshToken();
      if (refreshToken != null && refreshToken.isNotEmpty) {
        try {
          final refreshDio = Dio(BaseOptions(baseUrl: ApiConstants.baseUrl));
          final response = await refreshDio.post(
            '/auth/refresh',
            data: {'refresh_token': refreshToken},
          );

          if (response.statusCode == 200) {
            final newAccessToken = response.data['access_token'] as String;
            final newRefreshToken = response.data['refresh_token'] as String;

            await tokenStorage.saveTokens(
              accessToken: newAccessToken,
              refreshToken: newRefreshToken,
            );

            final originalOptions = err.requestOptions;
            originalOptions.headers['Authorization'] = 'Bearer $newAccessToken';

            final retryResponse = await dio.fetch(originalOptions);
            return handler.resolve(retryResponse);
          }
        } catch (_) {
          await tokenStorage.clearTokens();
        }
      }
    }
    handler.next(err);
  }
}
