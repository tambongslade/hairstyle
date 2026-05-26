import 'package:cross_file/cross_file.dart';
import 'api_client.dart';

class AdminService {
  static final AdminService _instance = AdminService._();
  static AdminService get instance => _instance;

  AdminService._();

  final _api = ApiClient.instance;

  // ── Dashboard ──
  Future<Map<String, dynamic>> getDashboard() =>
      _api.get('/admin/dashboard');

  // ── Salon ──
  Future<Map<String, dynamic>> getSalon() =>
      _api.get('/admin/salon');

  Future<Map<String, dynamic>> createSalon(Map<String, dynamic> data) =>
      _api.post('/admin/salon', body: data);

  Future<Map<String, dynamic>> updateSalon(Map<String, dynamic> data) =>
      _api.put('/admin/salon', body: data);

  /// Update the salon profile including an optional logo image. Sends a
  /// multipart/form-data PUT when [logo] is provided, falling back to the
  /// JSON [updateSalon] otherwise.
  Future<Map<String, dynamic>> updateSalonWithLogo({
    XFile? logo,
    required Map<String, String> fields,
  }) async {
    if (logo == null) {
      final body = <String, dynamic>{};
      fields.forEach((k, v) => body[k] = v);
      return _api.put('/admin/salon', body: body);
    }
    final bytes = await logo.readAsBytes();
    return _api.uploadMultipartPut(
      '/admin/salon',
      bytes: bytes,
      filename: logo.name,
      fieldName: 'logo',
      fields: fields,
    );
  }

  Future<Map<String, dynamic>> getSubscription() =>
      _api.get('/admin/salon/subscription');

  // ── Stylists ──
  Future<Map<String, dynamic>> getStylists() =>
      _api.get('/admin/salon/stylists');

  Future<Map<String, dynamic>> addStylist(Map<String, dynamic> data) =>
      _api.post('/admin/salon/stylists', body: data);

  Future<Map<String, dynamic>> updateStylist(String id, Map<String, dynamic> data) =>
      _api.put('/admin/salon/stylists/$id', body: data);

  Future<Map<String, dynamic>> deleteStylist(String id) =>
      _api.delete('/admin/salon/stylists/$id');

  Future<Map<String, dynamic>> getStylistSchedule() =>
      _api.get('/admin/stylists/schedule');

  // ── Services ──
  Future<Map<String, dynamic>> getServices() =>
      _api.get('/admin/services');

  Future<Map<String, dynamic>> getService(String id) =>
      _api.get('/admin/services/$id');

  Future<Map<String, dynamic>> createService(Map<String, dynamic> data) =>
      _api.post('/admin/services', body: data);

  Future<Map<String, dynamic>> updateService(String id, Map<String, dynamic> data) =>
      _api.put('/admin/services/$id', body: data);

  Future<Map<String, dynamic>> deleteService(String id) =>
      _api.delete('/admin/services/$id');

  // ── Catalog ──
  Future<Map<String, dynamic>> getCatalogStats() =>
      _api.get('/admin/catalog/stats');

  Future<Map<String, dynamic>> getCatalogStyles({Map<String, String>? query}) =>
      _api.get('/admin/catalog/styles', queryParams: query);

  Future<Map<String, dynamic>> createStyle(Map<String, dynamic> data) =>
      _api.post('/admin/catalog/styles', body: data);

  // Create style with image file
  Future<Map<String, dynamic>> createStyleWithImage({
    required XFile imageFile,
    required Map<String, String> fields,
  }) async {
    final bytes = await imageFile.readAsBytes();
    return _api.uploadMultipart('/admin/catalog/styles',
        bytes: bytes, filename: imageFile.name, fieldName: 'image', fields: fields);
  }

  Future<Map<String, dynamic>> updateStyle(String id, Map<String, dynamic> data) =>
      _api.put('/admin/catalog/styles/$id', body: data);

  // Update style with optional image
  Future<Map<String, dynamic>> updateStyleWithImage(String id, {
    XFile? imageFile,
    required Map<String, String> fields,
  }) async {
    if (imageFile != null) {
      final bytes = await imageFile.readAsBytes();
      return _api.uploadMultipartPut('/admin/catalog/styles/$id',
          bytes: bytes, filename: imageFile.name, fieldName: 'image', fields: fields);
    }
    final body = <String, dynamic>{};
    fields.forEach((k, v) => body[k] = v);
    return _api.put('/admin/catalog/styles/$id', body: body);
  }

  Future<Map<String, dynamic>> deleteStyle(String id) =>
      _api.delete('/admin/catalog/styles/$id');

  // ── Time Slots ──
  Future<Map<String, dynamic>> getTimeSlots({Map<String, String>? query}) =>
      _api.get('/admin/time-slots', queryParams: query);

  Future<Map<String, dynamic>> createTimeSlotsBulk({
    required List<int> days,
    required String startTime,
    required String endTime,
    required int maxBookings,
    int slotInterval = 30,
  }) =>
      _api.post('/admin/time-slots/bulk', body: {
        'days': days,
        'startTime': startTime,
        'endTime': endTime,
        'maxBookings': maxBookings,
        'slotInterval': slotInterval,
      });

  Future<Map<String, dynamic>> updateTimeSlot(String id, Map<String, dynamic> data) =>
      _api.put('/admin/time-slots/$id', body: data);

  Future<Map<String, dynamic>> deleteTimeSlot(String id) =>
      _api.delete('/admin/time-slots/$id');

  // ── Bookings ──
  Future<Map<String, dynamic>> getBookings({Map<String, String>? query}) =>
      _api.get('/admin/bookings', queryParams: query);

  Future<Map<String, dynamic>> getBooking(String id) =>
      _api.get('/admin/bookings/$id');

  Future<Map<String, dynamic>> updateBookingStatus(String id, String status) =>
      _api.put('/admin/bookings/$id/status', body: {'status': status});

  Future<Map<String, dynamic>> checkInBooking(String id) =>
      _api.post('/admin/bookings/$id/check-in');

  // ── Analytics ──
  Future<Map<String, dynamic>> getAnalyticsOverview({Map<String, String>? query}) =>
      _api.get('/admin/analytics/overview', queryParams: query);

  Future<Map<String, dynamic>> getRevenueChart({Map<String, String>? query}) =>
      _api.get('/admin/analytics/revenue-chart', queryParams: query);

  Future<Map<String, dynamic>> getLoyaltyAnalytics() =>
      _api.get('/admin/analytics/loyalty');

  // ── Settings ──
  Future<Map<String, dynamic>> getLoyaltyConfig() =>
      _api.get('/admin/settings/loyalty-config');

  Future<Map<String, dynamic>> updateLoyaltyConfig(Map<String, dynamic> data) =>
      _api.put('/admin/settings/loyalty-config', body: data);

  // ── Admin Try-On ──
  Future<Map<String, dynamic>> adminGenerateTryOn({
    required XFile photo,
    required Map<String, String> fields,
  }) async {
    final bytes = await photo.readAsBytes();
    return _api.uploadMultipart('/admin/try-on/generate',
        bytes: bytes, filename: photo.name, fieldName: 'photo', fields: fields);
  }

  Future<Map<String, dynamic>> getAdminTryOnHistory({Map<String, String>? query}) =>
      _api.get('/admin/try-on/history', queryParams: query);
}
