import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'storage_service.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  final Map<String, dynamic>? errors;

  ApiException(this.statusCode, this.message, {this.errors});

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiClient {
  static const String baseUrl = 'https://api.lisbeauty.evols.online/api/v1';
  static const String serverUrl = 'https://api.lisbeauty.evols.online';

  /// Public origin of the customer-facing web app. Used to build the
  /// salon-catalogue share link the salon sends to its clients.
  static const String webBaseUrl = 'https://beauty.mylisapp.online';

  /// Returns the public share link for [salonId] — what a salon owner sends
  /// to a client so they can browse, book, and run AI try-ons as a guest.
  static String catalogueShareUrl(String salonId) =>
      '$webBaseUrl/c/$salonId';

  /// Global navigator key — set from MaterialApp so we can redirect on auth failure
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// Convert a relative image path to a full URL.
  /// e.g. "/uploads/style-123.png" → "https://api.lisbeauty.evols.online/uploads/style-123.png"
  static String getImageUrl(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) return '';
    if (imageUrl.startsWith('http')) return imageUrl;
    return '$serverUrl$imageUrl';
  }

  static final ApiClient _instance = ApiClient._();
  static ApiClient get instance => _instance;

  ApiClient._();

  final http.Client _http = http.Client();

  Map<String, String> _headers({bool auth = true, bool isJson = true}) {
    final headers = <String, String>{
      'Accept': 'application/json',
    };
    if (isJson) {
      headers['Content-Type'] = 'application/json';
    }
    if (auth) {
      final token = StorageService.instance.accessToken;
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  Map<String, dynamic> _parseBody(http.Response response) {
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is List) return {'data': decoded};
    return {'data': decoded};
  }

  Future<Map<String, dynamic>> _handleResponse(
    http.Response response, {
    Future<http.Response> Function()? retry,
  }) async {
    final body = _parseBody(response);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }

    // If 401, try to refresh token and retry the request
    if (response.statusCode == 401) {
      final refreshed = await _tryRefreshToken();
      if (refreshed && retry != null) {
        final retryResponse = await retry();
        final retryBody = _parseBody(retryResponse);
        if (retryResponse.statusCode >= 200 && retryResponse.statusCode < 300) {
          return retryBody;
        }
      }
      // Refresh failed or retry still 401 — redirect to login
      await StorageService.instance.clearTokens();
      _redirectToLogin();
    }

    throw ApiException(
      response.statusCode,
      _normalizeMessage(body['message']),
      errors: body['errors'] as Map<String, dynamic>?,
    );
  }

  /// NestJS returns `message` as a plain string for thrown exceptions
  /// (e.g. 409 Conflict → "Email already registered") but as an array of
  /// strings for validation failures (400 → one entry per failed rule).
  /// Flatten both shapes into a single human-readable string.
  String _normalizeMessage(dynamic message) {
    if (message == null) return 'Unknown error';
    if (message is List) {
      final lines = message
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty);
      final joined = lines.join('\n');
      return joined.isEmpty ? 'Unknown error' : joined;
    }
    return message.toString();
  }

  void _redirectToLogin() {
    final ctx = navigatorKey.currentContext;
    if (ctx == null) return;
    try {
      GoRouter.of(ctx).go('/admin');
    } catch (_) {
      // Fall back to the legacy named-route path if go_router isn't mounted.
      Navigator.of(ctx).pushNamedAndRemoveUntil('/login', (_) => false);
    }
  }

  Future<bool> _tryRefreshToken() async {
    final refreshToken = StorageService.instance.refreshToken;
    if (refreshToken == null) return false;

    try {
      final response = await _http.post(
        Uri.parse('$baseUrl/auth/refresh'),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({'refreshToken': refreshToken}),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final data = body['data'] ?? body;
        await StorageService.instance.saveTokens(
          accessToken: data['accessToken'] ?? data['token'],
          refreshToken: data['refreshToken'] ?? refreshToken,
        );
        return true;
      }
    } catch (_) {}
    return false;
  }

  // ── GET ──
  Future<Map<String, dynamic>> get(String path, {
    Map<String, String>? queryParams,
    bool auth = true,
  }) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: queryParams);
    final response = await _http.get(uri, headers: _headers(auth: auth));
    return _handleResponse(response, retry: () => _http.get(uri, headers: _headers(auth: auth)));
  }

  // ── POST ──
  Future<Map<String, dynamic>> post(String path, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final encoded = body != null ? jsonEncode(body) : null;
    final response = await _http.post(uri, headers: _headers(auth: auth), body: encoded);
    return _handleResponse(response, retry: () => _http.post(uri, headers: _headers(auth: auth), body: encoded));
  }

  // ── PUT ──
  Future<Map<String, dynamic>> put(String path, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final encoded = body != null ? jsonEncode(body) : null;
    final response = await _http.put(uri, headers: _headers(auth: auth), body: encoded);
    return _handleResponse(response, retry: () => _http.put(uri, headers: _headers(auth: auth), body: encoded));
  }

  // ── DELETE ──
  Future<Map<String, dynamic>> delete(String path, {bool auth = true}) async {
    final uri = Uri.parse('$baseUrl$path');
    final response = await _http.delete(uri, headers: _headers(auth: auth));
    return _handleResponse(response, retry: () => _http.delete(uri, headers: _headers(auth: auth)));
  }

  // ── Multipart (for image uploads) ──
  // Web-compatible: takes bytes + filename instead of a dart:io File so the
  // same code path works on web, mobile, and desktop.
  Future<Map<String, dynamic>> uploadMultipart(String path, {
    required Uint8List bytes,
    required String filename,
    required String fieldName,
    Map<String, String>? fields,
    bool auth = true,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(_headers(auth: auth, isJson: false));
    request.files.add(http.MultipartFile.fromBytes(fieldName, bytes, filename: filename));
    if (fields != null) request.fields.addAll(fields);

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    return _handleResponse(response);
  }

  // ── Multipart PUT (for image updates) ──
  Future<Map<String, dynamic>> uploadMultipartPut(String path, {
    required Uint8List bytes,
    required String filename,
    required String fieldName,
    Map<String, String>? fields,
    bool auth = true,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final request = http.MultipartRequest('PUT', uri);
    request.headers.addAll(_headers(auth: auth, isJson: false));
    request.files.add(http.MultipartFile.fromBytes(fieldName, bytes, filename: filename));
    if (fields != null) request.fields.addAll(fields);

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    return _handleResponse(response);
  }
}
