import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../l10n/app_locale.dart';
import '../services/api_client.dart';
import '../services/customer_service.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import 'login_screen.dart';
import 'salon_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Uint8List? _localPhoto;
  String? _photoUrl;
  final _picker = ImagePicker();

  String _userName = '';
  String _userEmail = '';
  int _savedCount = 0;
  String? _loyaltyTier;
  int _loyaltyPoints = 0;
  List<Map<String, dynamic>> _savedStyles = [];
  List<Map<String, dynamic>> _badges = [];

  @override
  void initState() {
    super.initState();
    _fetchAll();
  }

  Future<void> _fetchAll() async {
    await Future.wait([
      _fetchProfile(),
      _fetchSavedStyles(),
      _fetchBadges(),
    ]);
  }

  Future<void> _fetchProfile() async {
    try {
      final response = await CustomerService.instance.getProfile();
      final data = response['data'] ?? response;
      if (mounted) {
        setState(() {
          _userName = data['name']?.toString() ?? data['fullName']?.toString() ?? '';
          _userEmail = data['email']?.toString() ?? '';
          _photoUrl = data['photoUrl']?.toString() ?? data['profilePhotoUrl']?.toString();
          _loyaltyPoints = (data['points'] ?? data['loyaltyPoints'] ?? 0) as int;
          _loyaltyTier = data['tier']?.toString() ?? data['loyaltyTier']?.toString();
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchSavedStyles() async {
    try {
      final response = await CustomerService.instance.getSavedStyles();
      final raw = response['items'] ?? response['styles'] ?? response['savedStyles'] ?? response['data'] ?? response;
      final data = raw is List ? raw : (raw is Map ? (raw['items'] ?? raw['styles'] ?? []) : []);
      if (data is List && mounted) {
        setState(() {
          _savedStyles = List<Map<String, dynamic>>.from(data);
          _savedCount = _savedStyles.length;
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchBadges() async {
    try {
      final response = await CustomerService.instance.getMyBadges();
      final raw = response['items'] ?? response['badges'] ?? response['data'] ?? response;
      final data = raw is List ? raw : [];
      if (mounted) {
        setState(() => _badges = List<Map<String, dynamic>>.from(data));
      }
    } catch (_) {}
  }

  Future<void> _handleLogout() async {
    try { await AuthService.instance.logout(); } catch (_) {}
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false,
      );
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.getBgSecondary(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(tr('deleteAccount'),
            style: const TextStyle(color: AppTheme.accentRed, fontWeight: FontWeight.w600)),
        content: Text(tr('deleteAccountConfirm'),
            style: TextStyle(color: AppTheme.getTextSecondary(context))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('no'), style: TextStyle(color: AppTheme.getTextSecondary(context))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('deleteAccount'),
                style: const TextStyle(color: AppTheme.accentRed, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await CustomerService.instance.deleteAccount();
        await AuthService.instance.logout();
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false,
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed: $e'), behavior: SnackBarBehavior.floating),
          );
        }
      }
    }
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.getBgSecondary(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(tr('signOut'),
            style: TextStyle(color: AppTheme.getTextPrimary(context), fontWeight: FontWeight.w600)),
        content: Text(tr('signOutSub'),
            style: TextStyle(color: AppTheme.getTextSecondary(context))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr('no'), style: TextStyle(color: AppTheme.getTextSecondary(context))),
          ),
          TextButton(
            onPressed: () { Navigator.pop(ctx); _handleLogout(); },
            child: Text(tr('signOut'),
                style: const TextStyle(color: AppTheme.accentRed, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, maxWidth: 512, maxHeight: 512, imageQuality: 85);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() => _localPhoto = bytes);
      _uploadProfilePhoto(picked);
    }
  }

  Future<void> _uploadProfilePhoto(XFile photo) async {
    try {
      final res = await CustomerService.instance.uploadProfilePhoto(photo);
      final data = res['data'] ?? res;
      if (mounted) {
        final newUrl = data['photoUrl']?.toString() ?? data['profilePhotoUrl']?.toString();
        if (newUrl != null) setState(() => _photoUrl = newUrl);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('photoUpdated')), duration: const Duration(seconds: 2), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), behavior: SnackBarBehavior.floating, backgroundColor: AppTheme.accentRed),
        );
      }
    }
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        decoration: BoxDecoration(
          color: AppTheme.getBgSecondary(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: AppTheme.getBorder(context))),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(color: AppTheme.getTextTertiary(context), borderRadius: BorderRadius.circular(2))),
            Text(tr('changePhoto'), style: AppTheme.displayFont.copyWith(fontSize: 18, color: AppTheme.getTextPrimary(context))),
            const SizedBox(height: 20),
            _PhotoOption(icon: Icons.camera_alt_outlined, label: tr('takePhoto'),
                onTap: () { Navigator.pop(ctx); _pickImage(ImageSource.camera); }),
            const SizedBox(height: 10),
            _PhotoOption(icon: Icons.photo_library_outlined, label: tr('chooseFromGallery'),
                onTap: () { Navigator.pop(ctx); _pickImage(ImageSource.gallery); }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _fetchAll,
      color: AppTheme.getGold(context),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            _buildProfileHeader(),
            _buildStats(),
            if (StorageService.instance.hasSalonSelected) _buildSalonBadge(),
            if (_badges.isNotEmpty) _buildBadgesPreview(),
            const SizedBox(height: 22),
            _buildSavedStyles(),
            _buildMenu(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    final fullPhotoUrl = _photoUrl != null ? ApiClient.getImageUrl(_photoUrl!) : '';

    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: _showPhotoOptions,
            child: Stack(
              children: [
                Container(
                  width: 84, height: 84,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.getGold(context).withValues(alpha: 0.3), width: 2),
                  ),
                  child: ClipOval(
                    child: _localPhoto != null
                        ? Image.memory(_localPhoto!, width: 80, height: 80, fit: BoxFit.cover)
                        : fullPhotoUrl.isNotEmpty
                            ? Image.network(fullPhotoUrl, width: 80, height: 80, fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => _buildAvatarPlaceholder())
                            : _buildAvatarPlaceholder(),
                  ),
                ),
                Positioned(
                  bottom: 0, right: 0,
                  child: Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: AppTheme.getGold(context), shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.getBgPrimary(context), width: 2),
                    ),
                    child: Icon(Icons.camera_alt, size: 14, color: AppTheme.getBgPrimary(context)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_userName.isNotEmpty)
            Text(_userName, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppTheme.getTextPrimary(context))),
          if (_userEmail.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(_userEmail, style: TextStyle(fontSize: 12, color: AppTheme.getTextSecondary(context))),
          ],
          if (_loyaltyTier != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.getGold(context).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_loyaltyTier!.toUpperCase(),
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.getGold(context), letterSpacing: 0.5)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAvatarPlaceholder() {
    return Container(
      width: 80, height: 80,
      color: AppTheme.getBgGlass(context),
      child: Icon(Icons.person, size: 36, color: AppTheme.getTextTertiary(context)),
    );
  }

  Widget _buildStats() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Row(
        children: [
          _statCard('$_loyaltyPoints', tr('points')),
          const SizedBox(width: 10),
          _statCard('$_savedCount', tr('saved')),
          const SizedBox(width: 10),
          _statCard('${_badges.length}', tr('badges')),
        ],
      ),
    );
  }

  Widget _statCard(String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: AppTheme.getBgGlass(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.getBorder(context)),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.getTextPrimary(context))),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 10, color: AppTheme.getTextSecondary(context))),
          ],
        ),
      ),
    );
  }

  Widget _buildSalonBadge() {
    final salonName = StorageService.instance.selectedSalonName ?? '';
    final logoUrl = ApiClient.getImageUrl(StorageService.instance.selectedSalonLogo ?? '');
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SalonScreen())),
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 14, 20, 0),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.getBgSecondary(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.getBorder(context)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: AppTheme.getGoldDim(context),
                border: Border.all(color: AppTheme.getBorder(context)),
              ),
              clipBehavior: Clip.antiAlias,
              child: logoUrl.isNotEmpty
                  ? Image.network(logoUrl, fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Icon(Icons.store_rounded, size: 22, color: AppTheme.getTextTertiary(context)))
                  : Icon(Icons.store_rounded, size: 22, color: AppTheme.getTextTertiary(context)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(salonName,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.getTextPrimary(context)),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(tr('mySalonSub'),
                      style: TextStyle(fontSize: 11, color: AppTheme.getTextTertiary(context))),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 20, color: AppTheme.getTextTertiary(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildBadgesPreview() {
    final display = _badges.length > 5 ? _badges.sublist(0, 5) : _badges;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
          child: Text(tr('badges'), style: AppTheme.displayFont.copyWith(fontSize: 18, color: AppTheme.getTextPrimary(context))),
        ),
        SizedBox(
          height: 70,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: display.length,
            itemBuilder: (context, index) {
              final badge = display[index];
              final name = badge['name']?.toString() ?? '';
              final iconUrl = badge['iconUrl']?.toString();
              return Container(
                width: 60,
                margin: const EdgeInsets.only(right: 10),
                child: Column(
                  children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: AppTheme.getGoldDim(context),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.getGold(context).withValues(alpha: 0.3)),
                      ),
                      child: iconUrl != null && iconUrl.isNotEmpty
                          ? ClipRRect(borderRadius: BorderRadius.circular(11),
                              child: Image.network(ApiClient.getImageUrl(iconUrl), fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Icon(Icons.emoji_events, color: AppTheme.getGold(context), size: 22)))
                          : Icon(Icons.emoji_events, color: AppTheme.getGold(context), size: 22),
                    ),
                    const SizedBox(height: 4),
                    Text(name, style: TextStyle(fontSize: 9, color: AppTheme.getTextSecondary(context)),
                        textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSavedStyles() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(tr('savedStyles'),
                  style: AppTheme.displayFont.copyWith(fontSize: 20, color: AppTheme.getTextPrimary(context))),
              if (_savedStyles.isNotEmpty)
                Text(tr('viewAll'),
                    style: TextStyle(fontSize: 12, color: AppTheme.getGold(context), fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (_savedStyles.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Center(
              child: Text(tr('noSavedStyles'),
                  style: TextStyle(fontSize: 12, color: AppTheme.getTextTertiary(context))),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: List.generate(
                _savedStyles.length > 3 ? 3 : _savedStyles.length,
                (index) {
                  final style = _savedStyles[index];
                  final imageUrl = ApiClient.getImageUrl(style['imageUrl']?.toString() ?? style['image']?.toString());
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: AspectRatio(
                        aspectRatio: 3 / 4,
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: imageUrl.isNotEmpty
                                  ? Image.network(imageUrl, fit: BoxFit.cover,
                                      width: double.infinity, height: double.infinity,
                                      errorBuilder: (_, _, _) => Container(
                                        decoration: BoxDecoration(
                                          color: AppTheme.getBgGlass(context),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Icon(Icons.image_not_supported, color: AppTheme.getTextTertiary(context)),
                                      ))
                                  : Container(
                                      decoration: BoxDecoration(
                                        color: AppTheme.getBgGlass(context),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(Icons.image, color: AppTheme.getTextTertiary(context)),
                                    ),
                            ),
                            Positioned(
                              top: 6, right: 6,
                              child: Container(
                                width: 24, height: 24,
                                decoration: BoxDecoration(
                                  color: AppTheme.accentRed.withValues(alpha: 0.8),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.favorite, color: Colors.white, size: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMenu() {
    final menuItems = [
      _MenuItem(Icons.store_outlined, tr('mySalon'), tr('mySalonSub')),
      _MenuItem(Icons.palette_outlined, tr('stylePreferences'), tr('stylePrefSub')),
      _MenuItem(Icons.emoji_events_outlined, tr('badges'), tr('badgesSub')),
      _MenuItem(Icons.auto_stories_outlined, tr('hairJourney'), tr('hairJourneySub')),
      _MenuItem(Icons.notifications_outlined, tr('notifications'), tr('notifSub')),
      _MenuItem(Icons.language, tr('language'), tr('langSub')),
      _MenuItem(Icons.lock_outline, tr('privacyData'), tr('privacySub')),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Column(
        children: [
          ...menuItems.map((item) => GestureDetector(
            onTap: () {
              if (item.title == tr('mySalon')) {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SalonScreen()));
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: AppTheme.getBorder(context))),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: AppTheme.getBgGlass(context),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(item.icon, color: AppTheme.getTextSecondary(context), size: 18),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.title,
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.getTextPrimary(context))),
                        Text(item.subtitle,
                            style: TextStyle(fontSize: 11, color: AppTheme.getTextSecondary(context))),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: AppTheme.getTextTertiary(context), size: 18),
                ],
              ),
            ),
          )),
          // Sign out
          GestureDetector(
            onTap: _confirmLogout,
            child: _buildDangerRow(Icons.logout, tr('signOut'), tr('signOutSub')),
          ),
          const SizedBox(height: 8),
          // Delete account
          GestureDetector(
            onTap: _confirmDeleteAccount,
            child: _buildDangerRow(Icons.delete_forever_outlined, tr('deleteAccount'), tr('deleteAccountSub'),
                bgColor: AppTheme.accentRed.withValues(alpha: 0.08)),
          ),
          const SizedBox(height: 120),
        ],
      ),
    );
  }

  Widget _buildDangerRow(IconData icon, String title, String subtitle, {Color? bgColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: bgColor ?? AppTheme.getBgGlass(context),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppTheme.accentRed, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.accentRed)),
                Text(subtitle, style: TextStyle(fontSize: 11, color: AppTheme.getTextSecondary(context))),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: AppTheme.getTextTertiary(context), size: 18),
        ],
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String title;
  final String subtitle;
  const _MenuItem(this.icon, this.title, this.subtitle);
}

class _PhotoOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PhotoOption({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: AppTheme.getBgGlass(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.getBorder(context)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppTheme.getTextSecondary(context)),
            const SizedBox(width: 14),
            Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.getTextPrimary(context))),
          ],
        ),
      ),
    );
  }
}
