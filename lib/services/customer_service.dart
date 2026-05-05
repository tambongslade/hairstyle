import 'package:cross_file/cross_file.dart';
import 'api_client.dart';

class CustomerService {
  static final CustomerService _instance = CustomerService._();
  static CustomerService get instance => _instance;

  CustomerService._();

  final _api = ApiClient.instance;

  // ── Profile ──
  Future<Map<String, dynamic>> getProfile() =>
      _api.get('/customer/profile');

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) =>
      _api.put('/customer/profile', body: data);

  Future<Map<String, dynamic>> uploadProfilePhoto(XFile photo) async {
    final bytes = await photo.readAsBytes();
    return _api.uploadMultipart('/customer/profile/photo',
        bytes: bytes, filename: photo.name, fieldName: 'file');
  }

  Future<Map<String, dynamic>> deleteAccount() =>
      _api.delete('/customer/profile');

  // ── Preferences (Style Quiz) ──
  Future<Map<String, dynamic>> getPreferences() =>
      _api.get('/customer/preferences');

  Future<Map<String, dynamic>> updatePreferences(Map<String, dynamic> data) =>
      _api.put('/customer/preferences', body: data);

  // ── My Reviews ──
  Future<Map<String, dynamic>> getMyReviews() =>
      _api.get('/customer/reviews');

  // ── Salons ──
  Future<Map<String, dynamic>> getSalons({Map<String, String>? query}) =>
      _api.get('/salons', queryParams: query);

  Future<Map<String, dynamic>> getFollowedSalons({Map<String, String>? query}) =>
      _api.get('/salons/following', queryParams: query);

  Future<Map<String, dynamic>> getSelectedSalon() =>
      _api.get('/salons/selected');

  Future<Map<String, dynamic>> getSalon(String id) =>
      _api.get('/salons/$id');

  Future<Map<String, dynamic>> followSalon(String id) =>
      _api.post('/salons/$id/follow');

  Future<Map<String, dynamic>> unfollowSalon(String id) =>
      _api.delete('/salons/$id/follow');

  Future<Map<String, dynamic>> selectSalon(String id) =>
      _api.put('/salons/$id/select');

  Future<Map<String, dynamic>> clearSelectedSalon() =>
      _api.delete('/salons/selected');

  // ── Styles (public) ──
  Future<Map<String, dynamic>> getStyles({Map<String, String>? query}) =>
      _api.get('/styles', auth: false, queryParams: query);

  Future<Map<String, dynamic>> getStyle(String id) =>
      _api.get('/styles/$id', auth: false);

  Future<Map<String, dynamic>> getTrendingStyles() =>
      _api.get('/styles/trending', auth: false);

  Future<Map<String, dynamic>> getFeaturedStyles() =>
      _api.get('/styles/featured', auth: false);

  Future<Map<String, dynamic>> getStyleCategories() =>
      _api.get('/styles/categories', auth: false);

  Future<Map<String, dynamic>> getStyleLengths() =>
      _api.get('/styles/lengths', auth: false);

  Future<Map<String, dynamic>> getStyleDifficulties() =>
      _api.get('/styles/difficulties', auth: false);

  Future<Map<String, dynamic>> getStyleSubcategories({Map<String, String>? query}) =>
      _api.get('/styles/subcategories', auth: false, queryParams: query);

  Future<Map<String, dynamic>> trackStyleView(String styleId, {String source = 'explore'}) =>
      _api.post('/styles/$styleId/view', auth: false, body: {'source': source});

  // ── Style Reviews (public read, JWT write) ──
  Future<Map<String, dynamic>> getStyleReviews(String styleId, {Map<String, String>? query}) =>
      _api.get('/styles/$styleId/reviews', auth: false, queryParams: query);

  Future<Map<String, dynamic>> submitReview(String styleId, Map<String, dynamic> data) =>
      _api.post('/styles/$styleId/reviews', body: data);

  Future<Map<String, dynamic>> updateReview(String styleId, String reviewId, Map<String, dynamic> data) =>
      _api.put('/styles/$styleId/reviews/$reviewId', body: data);

  Future<Map<String, dynamic>> deleteReview(String styleId, String reviewId) =>
      _api.delete('/styles/$styleId/reviews/$reviewId');

  Future<Map<String, dynamic>> markReviewHelpful(String reviewId) =>
      _api.post('/reviews/$reviewId/helpful');

  Future<Map<String, dynamic>> unmarkReviewHelpful(String reviewId) =>
      _api.delete('/reviews/$reviewId/helpful');

  // ── Services (public) ──
  Future<Map<String, dynamic>> getServices({Map<String, String>? query}) =>
      _api.get('/services', auth: false, queryParams: query);

  Future<Map<String, dynamic>> getService(String id) =>
      _api.get('/services/$id', auth: false);

  // ── Stylists (public) ──
  Future<Map<String, dynamic>> getStylists({Map<String, String>? query}) =>
      _api.get('/stylists', auth: false, queryParams: query);

  Future<Map<String, dynamic>> getStylist(String id) =>
      _api.get('/stylists/$id', auth: false);

  Future<Map<String, dynamic>> getStylistAvailability(String id, {required String date}) =>
      _api.get('/stylists/$id/availability', auth: false, queryParams: {'date': date});

  // ── Bookings ──
  Future<Map<String, dynamic>> getMyBookings({Map<String, String>? query}) =>
      _api.get('/bookings', queryParams: query);

  Future<Map<String, dynamic>> getBooking(String id) =>
      _api.get('/bookings/$id');

  Future<Map<String, dynamic>> createBooking(Map<String, dynamic> data) =>
      _api.post('/bookings', body: data);

  Future<Map<String, dynamic>> updateBooking(String id, Map<String, dynamic> data) =>
      _api.put('/bookings/$id', body: data);

  Future<Map<String, dynamic>> cancelBooking(String id) =>
      _api.put('/bookings/$id/cancel');

  Future<Map<String, dynamic>> getAvailableDates({required String salonId, int days = 14}) =>
      _api.get('/bookings/available-dates', queryParams: {
        'salonId': salonId,
        'days': days.toString(),
      });

  Future<Map<String, dynamic>> getAvailableTimes({required String salonId, required String date}) =>
      _api.get('/bookings/available-times', queryParams: {
        'salonId': salonId,
        'date': date,
      });

  // ── Try-On ──
  Future<Map<String, dynamic>> generateTryOnWithPhoto({
    required XFile photo,
    required Map<String, String> fields,
  }) async {
    final bytes = await photo.readAsBytes();
    return _api.uploadMultipart('/try-on/generate',
        bytes: bytes, filename: photo.name, fieldName: 'userPhoto', fields: fields);
  }

  Future<Map<String, dynamic>> uploadTryOnPhoto(XFile photo) async {
    final bytes = await photo.readAsBytes();
    return _api.uploadMultipart('/try-on/upload',
        bytes: bytes, filename: photo.name, fieldName: 'userPhoto');
  }

  Future<Map<String, dynamic>> getTryOnHistory({Map<String, String>? query}) =>
      _api.get('/try-on/history', queryParams: query);

  Future<Map<String, dynamic>> saveTryOn(String tryOnId) =>
      _api.post('/try-on/save', body: {'tryOnId': tryOnId});

  Future<Map<String, dynamic>> deleteTryOn(String id) =>
      _api.delete('/try-on/$id');

  Future<Map<String, dynamic>> publishTryOn(String id) =>
      _api.put('/try-on/$id/publish');

  // ── Saved Styles ──
  Future<Map<String, dynamic>> getSavedStyles() =>
      _api.get('/customer/saved-styles');

  Future<Map<String, dynamic>> saveStyle(String styleId) =>
      _api.post('/customer/saved-styles/$styleId');

  Future<Map<String, dynamic>> removeSavedStyle(String styleId) =>
      _api.delete('/customer/saved-styles/$styleId');

  // ── Explore Feed (card-based, paginated) ──
  Future<Map<String, dynamic>> getExploreFeed({int page = 1, int limit = 10}) =>
      _api.get('/explore/feed', auth: false, queryParams: {
        'page': page.toString(),
        'limit': limit.toString(),
      });

  Future<Map<String, dynamic>> getStyleOfTheDay() =>
      _api.get('/explore/style-of-the-day', auth: false);

  Future<Map<String, dynamic>> getCollections({Map<String, String>? query}) =>
      _api.get('/explore/collections', auth: false, queryParams: query);

  Future<Map<String, dynamic>> getCollection(String id) =>
      _api.get('/explore/collections/$id', auth: false);

  Future<Map<String, dynamic>> getExploreTrending({String period = 'week', int limit = 10}) =>
      _api.get('/explore/trending', auth: false, queryParams: {
        'period': period,
        'limit': limit.toString(),
      });

  Future<Map<String, dynamic>> getTipDetail(String id) =>
      _api.get('/explore/tips/$id', auth: false);

  Future<Map<String, dynamic>> getInspirationDetail(String id) =>
      _api.get('/explore/inspiration/$id', auth: false);

  // ── Social Sharing ──
  Future<Map<String, dynamic>> trackShare(Map<String, dynamic> data) =>
      _api.post('/shares', body: data);

  Future<Map<String, dynamic>> getShareHistory({Map<String, String>? query}) =>
      _api.get('/shares/history', queryParams: query);

  Future<Map<String, dynamic>> resolveDeepLink(String type, String id) =>
      _api.get('/shares/deeplink/$type/$id', auth: false);

  // ── Style Comparisons ──
  Future<Map<String, dynamic>> createComparison(Map<String, dynamic> data) =>
      _api.post('/comparisons', body: data);

  Future<Map<String, dynamic>> getComparisons({Map<String, String>? query}) =>
      _api.get('/comparisons', queryParams: query);

  Future<Map<String, dynamic>> getComparison(String id) =>
      _api.get('/comparisons/$id');

  Future<Map<String, dynamic>> pickComparisonFavorite(String comparisonId, String itemId) =>
      _api.put('/comparisons/$comparisonId/favorite/$itemId');

  Future<Map<String, dynamic>> deleteComparison(String id) =>
      _api.delete('/comparisons/$id');

  // ── Badges & Achievements ──
  Future<Map<String, dynamic>> getAllBadges() =>
      _api.get('/badges', auth: false);

  Future<Map<String, dynamic>> getMyBadges() =>
      _api.get('/badges/my');

  Future<Map<String, dynamic>> getBadgeProgress() =>
      _api.get('/badges/progress');

  // ── Hair Journey ──
  Future<Map<String, dynamic>> addJournalEntry({
    required XFile photo,
    required Map<String, String> fields,
  }) async {
    final bytes = await photo.readAsBytes();
    return _api.uploadMultipart('/hair-journey',
        bytes: bytes, filename: photo.name, fieldName: 'photo', fields: fields);
  }

  Future<Map<String, dynamic>> getJournalTimeline({Map<String, String>? query}) =>
      _api.get('/hair-journey', queryParams: query);

  Future<Map<String, dynamic>> getJournalSummary() =>
      _api.get('/hair-journey/summary');

  Future<Map<String, dynamic>> compareJournalEntries(String id1, String id2) =>
      _api.get('/hair-journey/compare', queryParams: {'id1': id1, 'id2': id2});

  Future<Map<String, dynamic>> getJournalEntry(String id) =>
      _api.get('/hair-journey/$id');

  Future<Map<String, dynamic>> updateJournalEntry(String id, Map<String, dynamic> data) =>
      _api.put('/hair-journey/$id', body: data);

  Future<Map<String, dynamic>> deleteJournalEntry(String id) =>
      _api.delete('/hair-journey/$id');

  // ── Smart Recommendations ──
  Future<Map<String, dynamic>> getRecommendations({int limit = 10}) =>
      _api.get('/recommendations', queryParams: {'limit': limit.toString()});

  Future<Map<String, dynamic>> getSimilarStyles(String styleId, {int limit = 8}) =>
      _api.get('/recommendations/similar/$styleId', auth: false, queryParams: {'limit': limit.toString()});

  // ── Loyalty ──
  Future<Map<String, dynamic>> getLoyaltyProfile() =>
      _api.get('/loyalty/profile');

  Future<Map<String, dynamic>> getLoyaltyActivities() =>
      _api.get('/loyalty/activities');

  Future<Map<String, dynamic>> getPunchCard() =>
      _api.get('/loyalty/punch-card');

  Future<Map<String, dynamic>> getReferralInfo() =>
      _api.get('/loyalty/referral');

  Future<Map<String, dynamic>> redeemPoints(Map<String, dynamic> data) =>
      _api.post('/loyalty/redeem', body: data);

  Future<Map<String, dynamic>> shareReferral() =>
      _api.post('/loyalty/referral/share');

  // ── Notifications ──
  Future<Map<String, dynamic>> getNotifications() =>
      _api.get('/notifications');

  Future<Map<String, dynamic>> getUnreadCount() =>
      _api.get('/notifications/unread-count');

  Future<Map<String, dynamic>> markAllNotificationsRead() =>
      _api.put('/notifications/read-all');

  Future<Map<String, dynamic>> markNotificationRead(String id) =>
      _api.put('/notifications/$id/read');
}
