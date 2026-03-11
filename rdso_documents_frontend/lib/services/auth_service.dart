import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/user.dart';
import 'api_service.dart';

class AuthService extends ChangeNotifier {
  final _storage = const FlutterSecureStorage();
  User? _currentUser;
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _error;

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String? get error => _error;
  bool get isLoggedIn => _currentUser != null;
  bool get isAdmin => _currentUser?.isStaff == true;

  Future<String?> register(String hrmsId, String password, {String? email, String? phone}) async {
    try {
      final body = <String, dynamic>{
        'HRMS_ID': hrmsId,
        'password': password,
      };
      if (email != null && email.isNotEmpty) body['email'] = email;
      if (phone != null && phone.isNotEmpty) body['phone_number'] = phone;

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/register/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 201) {
        return null; // success
      } else {
        final data = jsonDecode(response.body);
        if (data is Map) {
          return data.values.map((v) => v is List ? v.first : v).join('; ');
        }
        return 'Registration failed';
      }
    } catch (e) {
      return 'Connection error. Is the server running?';
    }
  }

  Future<void> init() async {
    final accessToken = await _storage.read(key: 'access_token');
    final refreshToken = await _storage.read(key: 'refresh_token');

    if (accessToken != null) {
      // Try fetching profile with existing access token
      await fetchProfile();

      // If profile fetch failed (expired token), try refreshing
      if (_currentUser == null && refreshToken != null) {
        final refreshed = await ApiService().refreshToken();
        if (refreshed) {
          await fetchProfile();
        }
      }
    }

    _isInitialized = true;
    notifyListeners();
  }

  Future<bool> login(String hrmsId, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/login/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'HRMS_ID': hrmsId, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _storage.write(key: 'access_token', value: data['access']);
        await _storage.write(key: 'refresh_token', value: data['refresh']);
        await fetchProfile();
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        final data = jsonDecode(response.body);
        _error = data['detail'] ?? 'Invalid credentials';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Connection error. Is the server running?';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> fetchProfile() async {
    final token = await _storage.read(key: 'access_token');
    if (token == null) return;

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/hello/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        _currentUser = User.fromJson(jsonDecode(response.body));
      } else {
        _currentUser = null;
      }
    } catch (_) {
      _currentUser = null;
    }
    notifyListeners();
  }

  Future<void> logout() async {
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'refresh_token');
    _currentUser = null;
    notifyListeners();
  }
}
