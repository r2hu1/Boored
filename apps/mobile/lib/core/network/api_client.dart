import 'package:dio/dio.dart';
import '../storage/token_storage.dart';
import '../constants/api_constants.dart';
import 'auth_interceptor.dart';

class ApiClient {
  late final Dio dio;
  final TokenStorage tokenStorage;

  ApiClient({TokenStorage? tokenStorage, String? baseUrl})
      : tokenStorage = tokenStorage ?? TokenStorage() {
    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl ?? ApiConstants.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    dio.interceptors.add(
      AuthInterceptor(tokenStorage: this.tokenStorage, dio: dio),
    );
  }
}
