import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/user.dart';
import 'api_service.dart';

class AuthService extends ChangeNotifier {
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

  final ApiService _api = ApiService();

  Future<String?> register(String hrmsId, String password, {String? email, String? phone}) async {
    try {
      final body = <String, dynamic>{
        'HRMS_ID': hrmsId,
        'password': password,
      };
      if (email != null && email.isNotEmpty) body['email'] = email;
      if (phone != null && phone.isNotEmpty) body['phone_number'] = phone;

      final response = await _api.post(
        '/register/',
        body: body,
        authenticated: false,
        retryOnUnauthorized: false,
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
    } catch (_) {
      return 'Connection error. Is the server running?';
    }
  }

  Future<void> init() async {
    // Warm up the ApiService token cache from persistent storage
    final headers = await _api.authHeaders();

    if (headers.containsKey('Authorization')) {
      // Try fetching profile with existing access token
      await fetchProfile();

      // If profile fetch failed (expired token), try refreshing
      if (_currentUser == null) {
        final refreshed = await _api.refreshToken();
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
      final response = await _api.post(
        '/login/',
        body: {'HRMS_ID': hrmsId, 'password': password},
        authenticated: false,
        retryOnUnauthorized: false,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _api.setTokens(access: data['access'], refresh: data['refresh']);
        await fetchProfile();
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        final data = jsonDecode(response.body);
        _error = _extractMessage(data, fallback: 'Invalid credentials');
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (_) {
      _error = 'Connection error. Is the server running?';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> fetchProfile() async {
    final headers = await _api.authHeaders();
    if (headers['Authorization'] == null) return;

    try {
      final response = await _api.get('/hello/');

      if (response.statusCode == 200) {
        _currentUser = User.fromJson(jsonDecode(response.body));
      } else {
        _currentUser = null;
        if (response.statusCode == 401) {
          await _api.clearTokens();
        }
      }
    } catch (_) {
      _currentUser = null;
    }
    notifyListeners();
  }

  Future<void> logout() async {
    await _api.clearTokens();
    _currentUser = null;
    notifyListeners();
  }

  String _extractMessage(dynamic data, {required String fallback}) {
    if (data is Map<String, dynamic>) {
      final detail = data['detail'];
      if (detail is String && detail.isNotEmpty) {
        return detail;
      }
      return data.values.map((value) => value is List ? value.first : value).join('; ');
    }
    return fallback;
  }
}
