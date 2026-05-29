import 'package:cross_file/cross_file.dart';
import 'api_client.dart';

/// Salon-first public API client. All endpoints are unauthenticated and
/// scoped to a single salon via the path :salonId.
class PublicService {
  static final PublicService _instance = PublicService._();
  static PublicService get instance => _instance;

  PublicService._();

  final _api = ApiClient.instance;

  Future<Map<String, dynamic>> getCatalogue(String salonId) =>
      _api.get('/public/salons/$salonId/catalogue', auth: false);

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
