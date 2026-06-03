import 'package:flutter/foundation.dart';
import 'package:cross_file/cross_file.dart';
import 'api_client.dart';
import 'storage_service.dart';

/// Salon-first public API client. Most endpoints are unauthenticated and
/// scoped to a single salon via the path :salonId. The auth endpoints below
/// let a customer create/sign into an account *under a salon* so they earn
/// that salon's fidelity points.
class PublicService {
  static final PublicService _instance = PublicService._();
  static PublicService get instance => _instance;

  PublicService._();

  final _api = ApiClient.instance;

  Future<Map<String, dynamic>> getCatalogue(String salonId) =>
      _api.get('/public/salons/$salonId/catalogue', auth: false);

  /// A salon's custom style categories (active only), sorted by sortOrder.
  /// Used to render category filter chips in the guest catalogue.
  Future<Map<String, dynamic>> getSalonCategories(String salonId) =>
      _api.get('/styles/salon-categories',
          auth: false, queryParams: {'salonId': salonId});

  Future<Map<String, dynamic>> getAvailableDates(String salonId, {int days = 14}) =>
      _api.get('/public/salons/$salonId/available-dates',
          auth: false, queryParams: {'days': days.toString()});

  Future<Map<String, dynamic>> getAvailableTimes(
          String salonId, {required String date}) =>
      _api.get('/public/salons/$salonId/available-times',
          auth: false, queryParams: {'date': date});

  Future<Map<String, dynamic>> createGuestBooking(
    String salonId, {
    required String clientName,
    required String clientPhone,
    required String clientEmail,
    required String date,
    required String time,
    String? styleId,
    String? notes,
  }) =>
      _api.post('/public/salons/$salonId/bookings', auth: false, body: {
        'clientName': clientName,
        'clientPhone': clientPhone,
        'clientEmail': clientEmail,
        'date': date,
        'time': time,
        if (styleId != null && styleId.isNotEmpty) 'styleId': styleId,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      });

  /// Public guest fidelity lookup. Returns 404 if the phone isn't enrolled
  /// at this salon. The `+` in international phone numbers MUST be encoded
  /// as `%2B` — http's queryParameters do this automatically, but if you ever
  /// build the URL by hand, remember.
  Future<Map<String, dynamic>> lookupGuestLoyalty(
    String salonId, {
    required String phone,
  }) =>
      _api.get('/public/salons/$salonId/loyalty/lookup',
          auth: false, queryParams: {'phone': phone});

  // ── Salon-scoped customer auth ──────────────────────────────────────────
  // The salon comes from the path, never the body — one link scopes the whole
  // session. On success we persist tokens + a customer session so the rest of
  // the app treats them as signed in.

  /// Create a customer account under [salonId] (auto-enrolls in fidelity).
  Future<Map<String, dynamic>> registerUnderSalon(
    String salonId, {
    required String name,
    required String email,
    required String password,
    required String phone,
  }) async {
    final res = await _api.post(
      '/public/salons/$salonId/auth/register',
      auth: false,
      body: {
        'name': name,
        'email': email,
        'password': password,
        'phone': phone,
      },
    );
    await _persistCustomerSession(res,
        fallbackName: name, fallbackPhone: phone, fallbackEmail: email);
    return res;
  }

  /// Log a customer into [salonId] (re-attaches them + ensures enrollment).
  Future<Map<String, dynamic>> loginUnderSalon(
    String salonId, {
    required String email,
    required String password,
  }) async {
    final res = await _api.post(
      '/public/salons/$salonId/auth/login',
      auth: false,
      body: {'email': email, 'password': password},
    );
    await _persistCustomerSession(res, fallbackEmail: email);
    return res;
  }

  /// The signed-in customer's fidelity status at [salonId] (Bearer token).
  Future<Map<String, dynamic>> getMyLoyalty(String salonId) =>
      _api.get('/public/salons/$salonId/me/loyalty');

  /// Save tokens + customer info from an auth response. Token/user fields are
  /// searched at the root and inside a nested `data`/`user` object so we don't
  /// depend on the exact envelope.
  Future<void> _persistCustomerSession(
    Map<String, dynamic> res, {
    String? fallbackName,
    String? fallbackPhone,
    String? fallbackEmail,
  }) async {
    final token = _dig(res, const ['accessToken', 'access_token', 'token']);
    final refresh = _dig(res, const ['refreshToken', 'refresh_token']);
    final userId = _dig(res, const ['userId', 'id', '_id'])?.toString() ?? '';

    if (token != null) {
      await StorageService.instance.saveTokens(
        accessToken: token.toString(),
        refreshToken: refresh?.toString(),
      );
      await StorageService.instance
          .saveUserInfo(userType: 'customer', userId: userId);
      debugPrint('[PublicAuth] customer session saved (userId=$userId)');
    } else {
      debugPrint('[PublicAuth] WARNING: no token in response keys=${res.keys.toList()}');
    }

    // Prefill profile so booking / try-on can reuse the details.
    final name = (_dig(res, const ['name', 'clientName'])?.toString() ?? fallbackName) ?? '';
    final phone = (_dig(res, const ['phone', 'clientPhone'])?.toString() ?? fallbackPhone) ?? '';
    final email = (_dig(res, const ['email', 'clientEmail'])?.toString() ?? fallbackEmail) ?? '';
    if (name.isNotEmpty || phone.isNotEmpty || email.isNotEmpty) {
      await StorageService.instance
          .saveGuestProfile(name: name, phone: phone, email: email);
    }
  }

  /// Find the first non-null value for any of [keys], checking the root, a
  /// nested `data` map, and `data.user`.
  static dynamic _dig(Map<String, dynamic> map, List<String> keys) {
    for (final k in keys) {
      if (map[k] != null) return map[k];
    }
    final data = map['data'];
    if (data is Map<String, dynamic>) {
      for (final k in keys) {
        if (data[k] != null) return data[k];
      }
      final user = data['user'];
      if (user is Map<String, dynamic>) {
        for (final k in keys) {
          if (user[k] != null) return user[k];
        }
      }
    }
    final user = map['user'];
    if (user is Map<String, dynamic>) {
      for (final k in keys) {
        if (user[k] != null) return user[k];
      }
    }
    return null;
  }

  Future<Map<String, dynamic>> generateGuestTryOn(
    String salonId, {
    required XFile photo,
    required String sessionId,
    required Map<String, String> fields,
  }) async {
    final bytes = await photo.readAsBytes();
    return _api.uploadMultipart(
      '/public/salons/$salonId/try-on/generate',
      bytes: bytes,
      filename: photo.name,
      fieldName: 'userPhoto',
      fields: {...fields, 'sessionId': sessionId},
      auth: false,
    );
  }
}
