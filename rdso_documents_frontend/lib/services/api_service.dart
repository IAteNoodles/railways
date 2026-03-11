import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class ApiService {
  static final ApiService _instance = ApiService._();
  factory ApiService() => _instance;
  ApiService._();

  final _storage = const FlutterSecureStorage();

  Future<String?> _getAccessToken() async {
    return await _storage.read(key: 'access_token');
  }

  Future<String?> _getRefreshToken() async {
    return await _storage.read(key: 'refresh_token');
  }

  Future<bool> refreshToken() async {
    final refreshToken = await _getRefreshToken();
    if (refreshToken == null) return false;

    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/refresh/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refresh': refreshToken}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
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

  Future<http.Response> get(String path, {Map<String, String>? queryParams}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$path').replace(queryParameters: queryParams);
    var response = await http.get(uri, headers: await authHeaders());

    if (response.statusCode == 401) {
      final refreshed = await refreshToken();
      if (refreshed) {
        response = await http.get(uri, headers: await authHeaders());
      }
    }
    return response;
  }

  Future<http.Response> post(String path, {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$path');
    var response = await http.post(uri, headers: await authHeaders(), body: jsonEncode(body));

    if (response.statusCode == 401) {
      final refreshed = await refreshToken();
      if (refreshed) {
        response = await http.post(uri, headers: await authHeaders(), body: jsonEncode(body));
      }
    }
    return response;
  }
}
