import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../l10n/app_locale.dart';
import '../../services/admin_service.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/storage_service.dart';
import '../login_screen.dart';
import 'salon_profile_editor.dart';
import 'style_migration_screen.dart';

class AdminSettings extends StatefulWidget {
  const AdminSettings({super.key});

  @override
  State<AdminSettings> createState() => _AdminSettingsState();
}

class _AdminSettingsState extends State<AdminSettings> {
  bool _loading = true;

  // Salon active status
  bool _isActive = true;

  // Salon info (fallback to hardcoded)
  String _salonName = 'Belle Coiffure Douala';
  String _salonAddress = 'Rue de Bonaberi, Douala';
  String _salonPhone = '+237 6XX XXX XXX';
  String _salonDescription = '';
  String? _salonLogoUrl;
  String _openingHours = '';
  String _weekendHours = '';
  String _daysOff = '';

  // Stylists
  List<Map<String, dynamic>> _stylists = [];

  // Subscription
  String _subscriptionPlan = 'Pro Plan';

  // Loyalty config
  String _pointsPer500 = '';
  String _punchCardVal = '';
  String _birthdayVal = '';
  String _referralVal = '';

  @override
  void initState() {
    super.initState();
    AppLocale.instance.addListener(_onLocaleChange);
    _fetchAll();
  }

  @override
  void dispose() {
    AppLocale.instance.removeListener(_onLocaleChange);
    super.dispose();
  }

  void _onLocaleChange() {
    if (mounted) setState(() {});
  }

  Future<void> _fetchAll() async {
    setState(() => _loading = true);

    // Fetch all in parallel, each with independent error handling
    await Future.wait([
      _fetchSalon(),
      _fetchStylists(),
      _fetchSubscription(),
      _fetchLoyaltyConfig(),
    ]);

    setState(() => _loading = false);
  }

  Future<void> _fetchSalon() async {
    try {
      final res = await AdminService.instance.getSalon();
      final data = res['data'] as Map<String, dynamic>? ?? res;
      setState(() {
        _salonName = data['name']?.toString() ?? _salonName;
        // Backend canonical field is `location`; accept legacy `address` too.
        _salonAddress = (data['location'] ?? data['address'])?.toString() ?? _salonAddress;
        _salonPhone = data['phone']?.toString() ?? _salonPhone;
        _salonDescription = data['description']?.toString() ?? _salonDescription;
        _salonLogoUrl = data['logoUrl']?.toString();
        _isActive = data['isActive'] ?? data['is_active'] ?? _isActive;

        // Business hours
        final hours = data['hours'] as Map<String, dynamic>? ?? data['businessHours'] as Map<String, dynamic>? ?? {};
        if (hours.isNotEmpty) {
          _openingHours = hours['opening'] ?? hours['openingHours'] ?? hours['weekday'] ?? '';
          _weekendHours = hours['weekend'] ?? hours['weekendHours'] ?? '';
          _daysOff = hours['daysOff'] ?? hours['days_off'] ?? hours['closedDays'] ?? '';
        }
      });
    } catch (_) {
      // Keep hardcoded fallback values
    }
  }

  Future<void> _fetchStylists() async {
    try {
      final res = await AdminService.instance.getStylists();
      final raw = res['stylists'] ?? res['data'] ?? res;
      final data = raw is List ? raw : (raw is Map ? (raw['stylists'] ?? []) : []);
      if (data is List && data.isNotEmpty) {
        setState(() {
          _stylists = List<Map<String, dynamic>>.from(data);
        });
      }
    } catch (_) {
      // Keep empty list; UI will show hardcoded fallback
    }
  }

  Future<void> _fetchSubscription() async {
    try {
      final res = await AdminService.instance.getSubscription();
      final data = res['data'] as Map<String, dynamic>? ?? res;
      setState(() {
        final plan = data['plan'] ?? data['name'] ?? 'Pro Plan';
        _subscriptionPlan = plan.toString();
      });
    } catch (_) {
      // Keep hardcoded fallback
    }
  }

  Future<void> _fetchLoyaltyConfig() async {
    try {
      final res = await AdminService.instance.getLoyaltyConfig();
      final data = res['data'] as Map<String, dynamic>? ?? res;
      setState(() {
        _pointsPer500 = data['pointsPer500']?.toString() ?? data['points_per_500']?.toString() ?? '';
        _punchCardVal = data['punchCard']?.toString() ?? data['punch_card']?.toString() ?? '';
        _birthdayVal = data['birthdayReward']?.toString() ?? data['birthday_reward']?.toString() ?? '';
        _referralVal = data['referralBonus']?.toString() ?? data['referral_bonus']?.toString() ?? '';
      });
    } catch (_) {
      // Keep empty strings; UI will use tr() fallback
    }
  }

  Future<void> _toggleActive(bool value) async {
    setState(() => _isActive = value);
    try {
      await AdminService.instance.updateSalon({'isActive': value});
    } catch (_) {
      if (mounted) setState(() => _isActive = !value);
    }
  }

  // ── Edit dialogs ──

  Future<void> _showEditDialog(String title, String currentValue, Future<void> Function(String) onSave) async {
    final controller = TextEditingController(text: currentValue);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: title),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('no'))),
          TextButton(onPressed: () => Navigator.pop(ctx, controller.text), child: Text(tr('save'))),
        ],
      ),
    );
    if (result != null && result.isNotEmpty && result != currentValue) {
      await onSave(result);
    }
  }

  Future<void> _editSalonField(String field, String current) async {
    await _showEditDialog(field, current, (val) async {
      final updateData = <String, dynamic>{};
      if (field == tr('salonName')) updateData['name'] = val;
      if (field == tr('address')) updateData['location'] = val;
      if (field == tr('phone')) updateData['phone'] = val;
      try {
        await AdminService.instance.updateSalon(updateData);
        await _fetchSalon();
      } catch (_) {}
    });
  }

  Future<void> _openProfileEditor() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const SalonProfileEditor()),
    );
    if (changed == true) {
      await _fetchSalon();
    }
  }

  Future<void> _editBusinessHours(String field, String current) async {
    await _showEditDialog(field, current, (val) async {
      final hours = <String, dynamic>{};
      if (field == tr('openingHours')) hours['opening'] = val;
      if (field == tr('weekendHours')) hours['weekend'] = val;
      if (field == tr('daysOff')) hours['daysOff'] = val;
      try {
        await AdminService.instance.updateSalon({'hours': hours});
        await _fetchSalon();
      } catch (_) {}
    });
  }

  Future<void> _editLoyaltyField(String field, String current) async {
    await _showEditDialog(field, current, (val) async {
      final updateData = <String, dynamic>{};
      if (field == tr('pointsPer500')) updateData['pointsPer500'] = val;
      if (field == tr('punchCardSetting')) updateData['punchCard'] = val;
      if (field == tr('birthdayReward')) updateData['birthdayReward'] = val;
      if (field == tr('referralBonus')) updateData['referralBonus'] = val;
      try {
        await AdminService.instance.updateLoyaltyConfig(updateData);
        await _fetchLoyaltyConfig();
      } catch (_) {}
    });
  }

  Future<void> _showAddStylistDialog() async {
    final nameController = TextEditingController();
    final specialtyController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('addStylist')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: InputDecoration(hintText: tr('stylist')),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: specialtyController,
              decoration: InputDecoration(hintText: tr('braidsSpecialist')),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('no'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('save'))),
        ],
      ),
    );
    if (result == true && nameController.text.isNotEmpty) {
      try {
        await AdminService.instance.addStylist({
          'name': nameController.text,
          'specialty': specialtyController.text,
        });
        await _fetchStylists();
      } catch (_) {}
    }
  }

  Future<void> _showLanguagePicker() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        decoration: BoxDecoration(
          color: AppTheme.getBgSecondary(ctx),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: AppTheme.getBorder(ctx))),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(
                color: AppTheme.getTextTertiary(ctx),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(tr('language'),
                style: AppTheme.displayFont.copyWith(fontSize: 18, color: AppTheme.getTextPrimary(ctx))),
            const SizedBox(height: 18),
            _languageOption(ctx, 'en', 'EN', 'English'),
            const SizedBox(height: 10),
            _languageOption(ctx, 'fr', 'FR', 'Français'),
          ],
        ),
      ),
    );
    if (selected != null && selected != AppLocale.instance.languageCode) {
      AppLocale.instance.setLanguage(selected);
      await StorageService.instance.saveLanguage(selected);
    }
  }

  Widget _languageOption(BuildContext ctx, String code, String shortCode, String label) {
    final isSelected = AppLocale.instance.languageCode == code;
    return GestureDetector(
      onTap: () => Navigator.pop(ctx, code),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.getGold(ctx).withValues(alpha: 0.12)
              : AppTheme.getBgGlass(ctx),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? AppTheme.getGold(ctx).withValues(alpha: 0.5)
                : AppTheme.getBorder(ctx),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.getGold(ctx).withValues(alpha: 0.18)
                    : AppTheme.getBgPrimary(ctx),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(shortCode,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? AppTheme.getGold(ctx) : AppTheme.getTextSecondary(ctx),
                      letterSpacing: 1,
                    )),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.getTextPrimary(ctx),
                  )),
            ),
            if (isSelected)
              Icon(Icons.check_circle, size: 20, color: AppTheme.getGold(ctx)),
          ],
        ),
      ),
    );
  }

  Future<void> _handleLogout() async {
    try {
      await AuthService.instance.logout();
    } catch (_) {}
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  // ── Build helpers (same styling as original) ──

  List<_SettingsRow> _buildBusinessHoursRows() {
    return [
      _SettingsRow(Icons.access_time, tr('openingHours'),
          _openingHours.isNotEmpty ? _openingHours : tr('openingHoursVal'),
          onTap: () => _editBusinessHours(tr('openingHours'), _openingHours.isNotEmpty ? _openingHours : tr('openingHoursVal'))),
      _SettingsRow(Icons.weekend, tr('weekendHours'),
          _weekendHours.isNotEmpty ? _weekendHours : tr('weekendHoursVal'),
          onTap: () => _editBusinessHours(tr('weekendHours'), _weekendHours.isNotEmpty ? _weekendHours : tr('weekendHoursVal'))),
      _SettingsRow(Icons.event_busy, tr('daysOff'),
          _daysOff.isNotEmpty ? _daysOff : tr('sunday'),
          onTap: () => _editBusinessHours(tr('daysOff'), _daysOff.isNotEmpty ? _daysOff : tr('sunday'))),
    ];
  }

  List<_SettingsRow> _buildLoyaltyRows() {
    return [
      _SettingsRow(Icons.star, tr('pointsPer500'),
          _pointsPer500.isNotEmpty ? _pointsPer500 : tr('pointsPer500Val'),
          onTap: () => _editLoyaltyField(tr('pointsPer500'), _pointsPer500.isNotEmpty ? _pointsPer500 : tr('pointsPer500Val'))),
      _SettingsRow(Icons.card_giftcard, tr('punchCardSetting'),
          _punchCardVal.isNotEmpty ? _punchCardVal : tr('punchCardVal'),
          onTap: () => _editLoyaltyField(tr('punchCardSetting'), _punchCardVal.isNotEmpty ? _punchCardVal : tr('punchCardVal'))),
      _SettingsRow(Icons.cake, tr('birthdayReward'),
          _birthdayVal.isNotEmpty ? _birthdayVal : tr('birthdayVal'),
          onTap: () => _editLoyaltyField(tr('birthdayReward'), _birthdayVal.isNotEmpty ? _birthdayVal : tr('birthdayVal'))),
      _SettingsRow(Icons.people, tr('referralBonus'),
          _referralVal.isNotEmpty ? _referralVal : tr('referralVal'),
          onTap: () => _editLoyaltyField(tr('referralBonus'), _referralVal.isNotEmpty ? _referralVal : tr('referralVal'))),
    ];
  }

  List<_SettingsRow> _buildStaffRows() {
    return [
      _SettingsRow(Icons.person_add, tr('addStylist'), tr('addStylistSub'),
          isAction: true, onTap: _showAddStylistDialog),
    ];
  }

  void _openStyleMigration() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const StyleMigrationScreen()),
    );
  }

  List<_SettingsRow> _buildAccountRows() {
    return [
      _SettingsRow(Icons.edit_outlined, tr('editSalonProfile'),
          tr('editSalonProfileSub'),
          isAction: true, onTap: _openProfileEditor),
      _SettingsRow(Icons.cloud_upload_outlined, tr('syncStyles'), tr('syncStylesSub'),
          isAction: true, onTap: _openStyleMigration),
      _SettingsRow(Icons.storefront, tr('salonName'), _salonName,
          onTap: () => _editSalonField(tr('salonName'), _salonName)),
      _SettingsRow(Icons.location_on, tr('address'), _salonAddress,
          onTap: () => _editSalonField(tr('address'), _salonAddress)),
      _SettingsRow(Icons.phone, tr('phone'), _salonPhone,
          onTap: () => _editSalonField(tr('phone'), _salonPhone)),
      _SettingsRow(
        Icons.language,
        tr('language'),
        AppLocale.instance.isEnglish ? tr('english') : tr('french'),
        onTap: _showLanguagePicker,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final isTablet = MediaQuery.of(context).size.width >= 600;
    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        _buildHeader(),
        _buildSalonInfo(),
        const SizedBox(height: 22),
        _buildSection(tr('businessHours'), _buildBusinessHoursRows()),
        const SizedBox(height: 22),
        _buildSection(tr('loyaltyConfig'), _buildLoyaltyRows()),
        const SizedBox(height: 22),
        _buildSection(tr('staffManagement'), _buildStaffRows()),
        const SizedBox(height: 22),
        _buildSection(tr('account'), _buildAccountRows()),
        const SizedBox(height: 22),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GestureDetector(
              onTap: _handleLogout,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: AppTheme.accentRed,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(tr('signOut'),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 120),
        ],
      );

    if (isTablet) {
      content = Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: content,
        ),
      );
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: content,
    );
  }

  Widget _buildHeader() {
    return Builder(
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr('settings'), style: AppTheme.displayFont.copyWith(fontSize: 24, color: AppTheme.getTextPrimary(context))),
              Text(tr('manageSalon'),
                  style: TextStyle(fontSize: 12, color: AppTheme.getTextSecondary(context))),
            ],
          ),
        );
      }
    );
  }

  Widget _buildSalonInfo() {
    final initials = _salonName.isNotEmpty
        ? _salonName.split(' ').where((w) => w.isNotEmpty).take(2).map((w) => w[0].toUpperCase()).join()
        : 'BC';
    final stylistCount = _stylists.isNotEmpty ? _stylists.length : 3;
    final fullLogoUrl = ApiClient.getImageUrl(_salonLogoUrl);

    return Builder(
      builder: (context) {
        return GestureDetector(
          onTap: _openProfileEditor,
          child: Container(
            margin: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.getBgSecondary(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.getBorder(context)),
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppTheme.getGold(context),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: fullLogoUrl.isNotEmpty
                      ? Image.network(
                          fullLogoUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _logoFallback(initials),
                          loadingBuilder: (ctx, child, progress) =>
                              progress == null
                                  ? child
                                  : _logoFallback(initials),
                        )
                      : _logoFallback(initials),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              _salonName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.getTextPrimary(context)),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(Icons.edit,
                              size: 14, color: AppTheme.getTextTertiary(context)),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text('$_subscriptionPlan · $stylistCount ${tr('stylist')}s',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.getTextSecondary(context))),
                      if (_salonDescription.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          _salonDescription,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.getTextTertiary(context),
                              height: 1.3),
                        ),
                      ],
                    ],
                  ),
                ),
                Column(
                  children: [
                    Switch(
                      value: _isActive,
                      onChanged: _toggleActive,
                      activeTrackColor: AppTheme.accentGreen,
                      inactiveThumbColor: AppTheme.getTextTertiary(context),
                      inactiveTrackColor: AppTheme.getBorder(context),
                    ),
                    Text(_isActive ? tr('active') : tr('inactive'),
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: _isActive
                                ? AppTheme.accentGreen
                                : AppTheme.accentRed)),
                  ],
                ),
              ],
            ),
          ),
        );
      }
    );
  }

  Widget _logoFallback(String initials) {
    return Center(
      child: Text(
        initials,
        style: const TextStyle(
            fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
      ),
    );
  }

  Widget _buildSection(String title, List<_SettingsRow> items) {
    return Builder(
      builder: (context) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(title, style: AppTheme.displayFont.copyWith(fontSize: 16, color: AppTheme.getTextPrimary(context))),
            ),
            const SizedBox(height: 10),
            ...items.map((item) => GestureDetector(
                  onTap: item.onTap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: AppTheme.getBorder(context))),
                      ),
                      child: Row(
                        children: [
                          Icon(item.icon, size: 18,
                              color: item.isAction ? AppTheme.getGold(context) : AppTheme.getTextSecondary(context)),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                                    color: item.isAction ? AppTheme.getGold(context) : AppTheme.getTextPrimary(context))),
                                Text(item.subtitle, style: TextStyle(fontSize: 11, color: AppTheme.getTextSecondary(context))),
                              ],
                            ),
                          ),
                          if (item.onTap != null)
                            Icon(Icons.chevron_right, size: 16, color: AppTheme.getTextTertiary(context)),
                        ],
                      ),
                    ),
                  ),
                )),
          ],
        );
      }
    );
  }
}

class _SettingsRow {
  final IconData icon;
  final String title, subtitle;
  final bool isAction;
  final VoidCallback? onTap;
  const _SettingsRow(this.icon, this.title, this.subtitle, {this.isAction = false, this.onTap});
}
