import 'package:flutter/foundation.dart';
import 'api_client.dart';
import 'storage_service.dart';

class AuthService {
  static final AuthService _instance = AuthService._();
  static AuthService get instance => _instance;

  AuthService._();

  final _api = ApiClient.instance;
  final _storage = StorageService.instance;

  /// Register a customer account
  Future<Map<String, dynamic>> registerCustomer({
    required String name,
    required String email,
    required String password,
    required String phone,
  }) async {
    final result = await _api.post('/auth/register', auth: false, body: {
      'name': name,
      'email': email,
      'password': password,
      'phone': phone,
    });
    await _handleAuthResponse(result, 'customer');
    return result;
  }

  /// Register an admin + salon
  Future<Map<String, dynamic>> registerAdmin({
    required String name,
    required String email,
    required String password,
    required String phone,
    required String salonName,
    String? salonAddress,
  }) async {
    final result = await _api.post('/auth/register-admin', auth: false, body: {
      'name': name,
      'email': email,
      'password': password,
      'phone': phone,
      'salonName': salonName,
      if (salonAddress != null) 'salonAddress': salonAddress,
    });
    await _handleAuthResponse(result, 'admin');
    return result;
  }

  /// Login (customer or admin)
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
    required String userType, // 'customer' or 'admin'
  }) async {
    final result = await _api.post('/auth/login', auth: false, body: {
      'email': email,
      'password': password,
      'userType': userType,
    });
    await _handleAuthResponse(result, userType);
    return result;
  }

  /// Social login (Google, Apple, Facebook)
  Future<Map<String, dynamic>> socialLogin({
    required String provider,
    required String token,
  }) async {
    final result = await _api.post('/auth/social-login', auth: false, body: {
      'provider': provider,
      'token': token,
    });
    await _handleAuthResponse(result, 'customer');
    return result;
  }

  /// Forgot password
  Future<Map<String, dynamic>> forgotPassword({required String email}) async {
    return await _api.post('/auth/forgot-password', auth: false, body: {
      'email': email,
    });
  }

  /// Reset password
  Future<Map<String, dynamic>> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    return await _api.post('/auth/reset-password', auth: false, body: {
      'token': token,
      'password': newPassword,
    });
  }

  /// Logout
  Future<void> logout() async {
    try {
      await _api.post('/auth/logout');
    } catch (_) {}
    await _storage.clearTokens();
  }

  /// Check if user is logged in with valid token
  bool get isLoggedIn => _storage.isLoggedIn;
  bool get isAdmin => _storage.isAdmin;
  String? get userType => _storage.userType;

  Future<void> _handleAuthResponse(Map<String, dynamic> result, String userType) async {
    debugPrint('[Auth] Raw login response: $result');

    // Search for token at any level of the response
    final token = _findValue(result, ['accessToken', 'access_token', 'token']);
    final refresh = _findValue(result, ['refreshToken', 'refresh_token']);
    final userId = _findValue(result, ['userId', 'id', '_id'])?.toString() ?? '';

    debugPrint('[Auth] Extracted token: ${token != null ? "${token.toString().substring(0, 20)}..." : "NULL"}');
    debugPrint('[Auth] Extracted userId: $userId');

    if (token != null) {
      await _storage.saveTokens(
        accessToken: token.toString(),
        refreshToken: refresh?.toString(),
      );
      await _storage.saveUserInfo(
        userType: userType,
        userId: userId,
      );
      debugPrint('[Auth] Token saved successfully. isLoggedIn: ${_storage.isLoggedIn}');

      // Auto-select a default salon for customers if none selected
      if (userType == 'customer' && !_storage.hasSalonSelected) {
        await _autoSelectSalon();
      }
    } else {
      debugPrint('[Auth] WARNING: No token found in response! Keys: ${result.keys.toList()}');
      if (result['data'] != null) {
        debugPrint('[Auth] data keys: ${(result['data'] as Map?)?.keys.toList()}');
      }
    }
  }

  /// Recursively search for a value by trying multiple key names,
  /// checking both root level and nested 'data' object.
  dynamic _findValue(Map<String, dynamic> map, List<String> keys) {
    // Check root level
    for (final key in keys) {
      if (map[key] != null) return map[key];
    }
    // Check nested 'data'
    final data = map['data'];
    if (data is Map<String, dynamic>) {
      for (final key in keys) {
        if (data[key] != null) return data[key];
      }
      // Check data.user for userId
      final user = data['user'];
      if (user is Map<String, dynamic>) {
        for (final key in keys) {
          if (user[key] != null) return user[key];
        }
      }
    }
    return null;
  }

  /// Try to auto-select a salon: first check server-side selected salon,
  /// then fall back to first followed salon, then first available salon.
  Future<void> _autoSelectSalon() async {
    try {
      // 1. Check if the server has a selected salon
      final selected = await _api.get('/salons/selected');
      final data = selected['data'] ?? selected;
      final id = data['id']?.toString() ?? data['salonId']?.toString();
      final name = data['name']?.toString() ?? data['salonName']?.toString();
      if (id != null && id.isNotEmpty && name != null) {
        final logoUrl = data['logoUrl']?.toString();
        await _storage.saveSelectedSalon(id: id, name: name, logoUrl: logoUrl);
        debugPrint('[Auth] Auto-selected salon from server: $name');
        return;
      }
    } catch (_) {}

    try {
      // 2. Try first followed salon
      final followed = await _api.get('/salons/following');
      final raw = followed['data'] ?? followed;
      final list = raw is List ? raw : (raw is Map ? (raw['items'] ?? raw['salons'] ?? []) : []);
      if (list is List && list.isNotEmpty) {
        final s = list.first;
        final id = s['id']?.toString() ?? '';
        final name = s['name']?.toString() ?? '';
        if (id.isNotEmpty && name.isNotEmpty) {
          final logoUrl = s['logoUrl']?.toString();
          await _storage.saveSelectedSalon(id: id, name: name, logoUrl: logoUrl);
          await _api.put('/salons/$id/select');
          debugPrint('[Auth] Auto-selected first followed salon: $name');
          return;
        }
      }
    } catch (_) {}

    try {
      // 3. Fall back to first available salon
      final salons = await _api.get('/salons', queryParams: {'limit': '1'});
      final raw = salons['data'] ?? salons;
      final list = raw is List ? raw : (raw is Map ? (raw['items'] ?? raw['salons'] ?? []) : []);
      if (list is List && list.isNotEmpty) {
        final s = list.first;
        final id = s['id']?.toString() ?? '';
        final name = s['name']?.toString() ?? '';
        if (id.isNotEmpty && name.isNotEmpty) {
          final logoUrl = s['logoUrl']?.toString();
          await _storage.saveSelectedSalon(id: id, name: name, logoUrl: logoUrl);
          await _api.put('/salons/$id/select');
          debugPrint('[Auth] Auto-selected first available salon: $name');
        }
      }
    } catch (_) {}
  }
}
