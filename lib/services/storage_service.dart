import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static final StorageService _instance = StorageService._();
  static StorageService get instance => _instance;

  StorageService._();

  SharedPreferences? _prefs;

  String? _accessToken;
  String? _refreshToken;
  String? _userType; // 'customer' or 'admin'
  String? _userId;
  String? _selectedSalonId;
  String? _selectedSalonName;
  String? _selectedSalonLogo;

  // Guest profile (salon-first flow, no account)
  String? _guestName;
  String? _guestPhone;
  String? _guestEmail;
  String? _guestSessionId;

  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;
  String? get userType => _userType;
  String? get userId => _userId;
  String? get selectedSalonId => _selectedSalonId;
  String? get selectedSalonName => _selectedSalonName;
  String? get selectedSalonLogo => _selectedSalonLogo;
  String? get guestName => _guestName;
  String? get guestPhone => _guestPhone;
  String? get guestEmail => _guestEmail;
  String? get guestSessionId => _guestSessionId;
  bool get hasGuestProfile =>
      (_guestName?.isNotEmpty ?? false) &&
      (_guestPhone?.isNotEmpty ?? false) &&
      (_guestEmail?.isNotEmpty ?? false);
  bool get isLoggedIn => _accessToken != null;
  bool get isAdmin => _userType == 'admin';
  bool get isCustomer => _userType == 'customer';
  bool get hasSalonSelected => _selectedSalonId != null;
  bool get hasCompletedOnboarding => _prefs?.getBool('onboarding_complete') ?? false;
  String? get savedLanguage => _prefs?.getString('language');

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _accessToken = _prefs?.getString('access_token');
    _refreshToken = _prefs?.getString('refresh_token');
    _userType = _prefs?.getString('user_type');
    _userId = _prefs?.getString('user_id');
    _selectedSalonId = _prefs?.getString('selected_salon_id');
    _selectedSalonName = _prefs?.getString('selected_salon_name');
    _selectedSalonLogo = _prefs?.getString('selected_salon_logo');
    _guestName = _prefs?.getString('guest_name');
    _guestPhone = _prefs?.getString('guest_phone');
    _guestEmail = _prefs?.getString('guest_email');
    _guestSessionId = _prefs?.getString('guest_session_id');
  }

  Future<void> saveGuestProfile({
    required String name,
    required String phone,
    required String email,
  }) async {
    _guestName = name;
    _guestPhone = phone;
    _guestEmail = email;
    await _prefs?.setString('guest_name', name);
    await _prefs?.setString('guest_phone', phone);
    await _prefs?.setString('guest_email', email);
  }

  Future<void> saveGuestSessionId(String sessionId) async {
    _guestSessionId = sessionId;
    await _prefs?.setString('guest_session_id', sessionId);
  }

  Future<void> clearGuestProfile() async {
    _guestName = null;
    _guestPhone = null;
    _guestEmail = null;
    _guestSessionId = null;
    await _prefs?.remove('guest_name');
    await _prefs?.remove('guest_phone');
    await _prefs?.remove('guest_email');
    await _prefs?.remove('guest_session_id');
  }

  Future<void> saveTokens({
    required String? accessToken,
    required String? refreshToken,
  }) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    if (accessToken != null) {
      await _prefs?.setString('access_token', accessToken);
    }
    if (refreshToken != null) {
      await _prefs?.setString('refresh_token', refreshToken);
    }
  }

  Future<void> saveUserInfo({
    required String userType,
    required String userId,
  }) async {
    _userType = userType;
    _userId = userId;
    await _prefs?.setString('user_type', userType);
    await _prefs?.setString('user_id', userId);
  }

  Future<void> setOnboardingComplete() async {
    await _prefs?.setBool('onboarding_complete', true);
  }

  Future<void> saveLanguage(String code) async {
    await _prefs?.setString('language', code);
  }

  Future<void> saveSelectedSalon({required String id, required String name, String? logoUrl}) async {
    _selectedSalonId = id;
    _selectedSalonName = name;
    _selectedSalonLogo = logoUrl;
    await _prefs?.setString('selected_salon_id', id);
    await _prefs?.setString('selected_salon_name', name);
    if (logoUrl != null) {
      await _prefs?.setString('selected_salon_logo', logoUrl);
    }
  }

  Future<void> clearSelectedSalon() async {
    _selectedSalonId = null;
    _selectedSalonName = null;
    _selectedSalonLogo = null;
    await _prefs?.remove('selected_salon_id');
    await _prefs?.remove('selected_salon_name');
    await _prefs?.remove('selected_salon_logo');
  }

  Future<void> clearTokens() async {
    _accessToken = null;
    _refreshToken = null;
    _userType = null;
    _userId = null;
    _selectedSalonId = null;
    _selectedSalonName = null;
    _selectedSalonLogo = null;
    await _prefs?.remove('access_token');
    await _prefs?.remove('refresh_token');
    await _prefs?.remove('user_type');
    await _prefs?.remove('user_id');
    await _prefs?.remove('selected_salon_id');
    await _prefs?.remove('selected_salon_name');
  }
}
