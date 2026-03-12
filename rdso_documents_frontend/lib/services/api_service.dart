import 'dart:convert';
import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

/// Exception thrown when an API call fails with a non-2xx status code.
class ApiException implements Exception {
  final int statusCode;
  final String message;
  final Map<String, dynamic>? body;

  ApiException(this.statusCode, this.message, [this.body]);

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiService {
  static const int _timeoutSeconds = int.fromEnvironment('API_TIMEOUT_SECONDS', defaultValue: 20);
  static final ApiService _instance = ApiService._();
  factory ApiService() => _instance;
  ApiService._();

  final _storage = const FlutterSecureStorage();

  // In-memory token cache to avoid repeated secure-storage reads
  String? _cachedAccessToken;
  String? _cachedRefreshToken;

  Future<String?> _getAccessToken() async {
    return _cachedAccessToken ??= await _storage.read(key: 'access_token');
  }

  Future<String?> _getRefreshToken() async {
    return _cachedRefreshToken ??= await _storage.read(key: 'refresh_token');
  }

  Future<void> setTokens({required String access, required String refresh}) async {
    _cachedAccessToken = access;
    _cachedRefreshToken = refresh;
    await _storage.write(key: 'access_token', value: access);
    await _storage.write(key: 'refresh_token', value: refresh);
  }

  Future<void> clearTokens() async {
    _cachedAccessToken = null;
    _cachedRefreshToken = null;
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'refresh_token');
  }

  Future<bool> refreshToken() async {
    final refreshToken = await _getRefreshToken();
    if (refreshToken == null) return false;

    final response = await post(
      '/refresh/',
      body: {'refresh': refreshToken},
      authenticated: false,
      retryOnUnauthorized: false,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      _cachedAccessToken = data['access'];
      await _storage.write(key: 'access_token', value: data['access']);
      return true;
    }
    return false;
  }

  Future<Map<String, String>> authHeaders() async {
    final token = await _getAccessToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<http.Response> get(
    String path, {
    Map<String, String>? queryParams,
    bool authenticated = true,
    bool retryOnUnauthorized = true,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$path').replace(queryParameters: queryParams);
    return _send(
      () async {
        final headers = authenticated ? await authHeaders() : _defaultHeaders;
        return http.get(uri, headers: headers);
      },
      retryOnUnauthorized: authenticated && retryOnUnauthorized,
    );
  }

  Future<http.Response> post(
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
    bool retryOnUnauthorized = true,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$path');
    return _send(
      () async {
        final headers = authenticated ? await authHeaders() : _defaultHeaders;
        return http.post(uri, headers: headers, body: jsonEncode(body));
      },
      retryOnUnauthorized: authenticated && retryOnUnauthorized,
    );
  }

  Map<String, String> get _defaultHeaders => const {'Content-Type': 'application/json'};

  Future<http.Response> _send(
    Future<http.Response> Function() request, {
    required bool retryOnUnauthorized,
  }) async {
    var response = await _runRequest(request);

    if (response.statusCode == 401 && retryOnUnauthorized) {
      final refreshed = await refreshToken();
      if (refreshed) {
        response = await _runRequest(request);
      }
    }

    return response;
  }

  Future<http.Response> _runRequest(Future<http.Response> Function() request) async {
    try {
      return await request().timeout(const Duration(seconds: _timeoutSeconds));
    } on TimeoutException {
      developer.log('API request timed out', name: 'api');
      return _errorResponse(504, 'Request timed out. Please try again.');
    } catch (error, stackTrace) {
      developer.log('API request failed', name: 'api', error: error, stackTrace: stackTrace);
      return _errorResponse(503, 'Unable to reach the server. Please try again.');
    }
  }

  http.Response _errorResponse(int statusCode, String message) {
    return http.Response(
      jsonEncode({'detail': message}),
      statusCode,
      headers: _defaultHeaders,
    );
  }
}
