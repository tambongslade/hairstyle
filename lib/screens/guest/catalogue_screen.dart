import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../l10n/app_locale.dart';
import '../../services/api_client.dart';
import '../../services/public_service.dart';
import '../../services/storage_service.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/gold_button.dart';
import 'client_fidelity_screen.dart';
import 'my_appointments_screen.dart';
import 'salon_auth_screen.dart';

/// Salon catalogue (guest-facing). Single salon, no auth — everything is
/// fetched from /public/salons/:salonId/catalogue.
class CatalogueScreen extends StatefulWidget {
  /// Called when the guest taps a CTA that switches tabs in the shell.
  final void Function(int tabIndex)? onTabSwitch;
  const CatalogueScreen({super.key, this.onTabSwitch});

  @override
  State<CatalogueScreen> createState() => _CatalogueScreenState();
}

class _CatalogueScreenState extends State<CatalogueScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _salon;
  List<Map<String, dynamic>> _styles = [];
  List<Map<String, dynamic>> _services = [];
  List<Map<String, dynamic>> _stylists = [];
  List<Map<String, dynamic>> _categories = [];
  String? _selectedCategoryId; // null = All

  @override
  void initState() {
    super.initState();
    _load();
  }

  String? get _salonId => StorageService.instance.selectedSalonId;

  /// The category id a style belongs to, reading either the flat `categoryId`
  /// or the nested `customCategory` object the API may return.
  String? _styleCategoryId(Map<String, dynamic> s) {
    final flat = s['categoryId']?.toString();
    if (flat != null && flat.isNotEmpty) return flat;
    final custom = s['customCategory'];
    if (custom is Map) return custom['id']?.toString();
    return null;
  }

  /// Styles after applying the selected category chip (client-side).
  List<Map<String, dynamic>> get _filteredStyles {
    if (_selectedCategoryId == null) return _styles;
    return _styles
        .where((s) => _styleCategoryId(s) == _selectedCategoryId)
        .toList();
  }

  Future<void> _load() async {
    final id = _salonId;
    if (id == null) {
      setState(() {
        _loading = false;
        _error = 'No salon selected. Open a salon catalogue link to begin.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await PublicService.instance.getCatalogue(id);
      final data = (res['data'] ?? res) as Map<String, dynamic>;
      final salon = (data['salon'] ?? data) as Map<String, dynamic>;
      final styles = (data['styles'] ?? data['hairstyles'] ?? []) as List;
      final services = (data['services'] ?? []) as List;
      final stylists = (data['stylists'] ?? []) as List;

      // Category chips are a nice-to-have — a failure here must not break the
      // catalogue, so it's fetched best-effort.
      List<Map<String, dynamic>> categories = [];
      try {
        final catRes = await PublicService.instance.getSalonCategories(id);
        final catRaw =
            catRes['data'] ?? catRes['items'] ?? catRes['categories'] ?? catRes;
        if (catRaw is List) {
          categories = List<Map<String, dynamic>>.from(catRaw.whereType<Map>());
        }
      } catch (e) {
        debugPrint('[Catalogue] categories unavailable: $e');
      }

      // Persist the salon name/logo so the rest of the shell can show them.
      await StorageService.instance.saveSelectedSalon(
        id: salon['id']?.toString() ?? id,
        name: salon['name']?.toString() ?? '',
        logoUrl: salon['logoUrl']?.toString() ?? salon['logo']?.toString(),
      );

      if (!mounted) return;
      setState(() {
        _salon = salon;
        _styles = List<Map<String, dynamic>>.from(styles.whereType<Map>());
        _services =
            List<Map<String, dynamic>>.from(services.whereType<Map>());
        _stylists =
            List<Map<String, dynamic>>.from(stylists.whereType<Map>());
        _categories = categories;
        // Drop a stale selection if that category no longer exists.
        if (_selectedCategoryId != null &&
            !categories.any((c) => c['id']?.toString() == _selectedCategoryId)) {
          _selectedCategoryId = null;
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Center(
        child: CircularProgressIndicator(
          color: AppTheme.getGold(context),
          strokeWidth: 2,
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline,
                  color: AppTheme.accentRed, size: 36),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.getTextSecondary(context),
                ),
              ),
              const SizedBox(height: 16),
              GoldButton(text: tr('retry'), onPressed: _load),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppTheme.getGold(context),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.only(top: 8, bottom: 100),
        children: [
          _buildHeader(),
          const SizedBox(height: 18),
          _buildCtas(),
          const SizedBox(height: 14),
          _buildMyPointsRow(),
          if (_isClientLoggedIn) ...[
            const SizedBox(height: 10),
            _buildMyAppointmentsRow(),
          ],
          const SizedBox(height: 24),
          if (_styles.isNotEmpty) _buildStylesGrid(),
          if (_services.isNotEmpty) ...[
            const SizedBox(height: 24),
            _buildServicesList(),
          ],
          if (_stylists.isNotEmpty) ...[
            const SizedBox(height: 24),
            _buildStylistsList(),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final name = _salon?['name']?.toString() ?? '';
    final desc = _salon?['description']?.toString() ?? '';
    final loc = _salon?['location']?.toString() ??
        _salon?['address']?.toString() ??
        '';
    final logo = ApiClient.getImageUrl(
        _salon?['logoUrl']?.toString() ?? _salon?['logo']?.toString() ?? '');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 64,
            height: 64,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppTheme.getBgGlass(context),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.getBorder(context)),
            ),
            child: logo.isNotEmpty
                ? Image.network(logo,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _logoFallback())
                : _logoFallback(),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: AppTheme.displayFont.copyWith(
                      fontSize: 22,
                      color: AppTheme.getTextPrimary(context),
                    )),
                if (loc.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.place_outlined,
                        size: 13, color: AppTheme.getTextSecondary(context)),
                    const SizedBox(width: 4),
                    Expanded(
                        child: Text(loc,
                            style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.getTextSecondary(context)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis)),
                  ]),
                ],
                if (desc.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(desc,
                      style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.getTextSecondary(context),
                          height: 1.4),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          _accountButton(),
        ],
      ),
    );
  }

  /// Top-right affordance: a "Sign in" pill when logged out, a person icon
  /// (→ fidelity page) when a customer is signed in.
  Widget _accountButton() {
    if (_isClientLoggedIn) {
      return GestureDetector(
        onTap: _openLoyalty,
        child: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: AppTheme.getGold(context).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.person_rounded,
              color: AppTheme.getGold(context), size: 20),
        ),
      );
    }
    return GestureDetector(
      onTap: () => _openAuth(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.getGold(context),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          tr('signIn'),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _logoFallback() => Container(
        color: AppTheme.getBgGlass(context),
        child: Icon(Icons.storefront_outlined,
            color: AppTheme.getTextTertiary(context)),
      );

  Widget _buildCtas() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: GoldButton(
              text: tr('tabTryOn'),
              onPressed: () => widget.onTabSwitch?.call(1),
              expanded: true,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GoldButton(
              text: tr('tabBook'),
              onPressed: () => widget.onTabSwitch?.call(2),
              expanded: true,
            ),
          ),
        ],
      ),
    );
  }

  /// True when a customer is signed in (has a token under this salon).
  bool get _isClientLoggedIn =>
      StorageService.instance.isLoggedIn && StorageService.instance.isCustomer;

  /// Loyalty entry point: signed-in customers see their fidelity page;
  /// everyone else gets the sign-in / sign-up screen first.
  Future<void> _openLoyalty() async {
    if (_isClientLoggedIn) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ClientFidelityScreen()),
      );
    } else {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const SalonAuthScreen()),
      );
    }
    // Auth state may have changed — refresh the header/account affordances.
    if (mounted) setState(() {});
  }

  Future<void> _openAuth({bool signup = false}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SalonAuthScreen(startOnSignup: signup)),
    );
    if (mounted) setState(() {});
  }

  Widget _buildMyPointsRow() {
    final loggedIn = _isClientLoggedIn;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _openLoyalty,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.getBgGlass(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.getBorder(context)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.getGold(context).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.workspace_premium_rounded,
                    color: AppTheme.getGold(context), size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loggedIn ? tr('myRewards') : tr('joinRewards'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.getTextPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      loggedIn
                          ? tr('trackTierRewards')
                          : tr('signInToEarn'),
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.getTextSecondary(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_rounded,
                  size: 16, color: AppTheme.getTextTertiary(context)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openAppointments() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const MyAppointmentsScreen()),
    );
    if (mounted) setState(() {});
  }

  /// Quick access to the signed-in customer's bookings at this salon.
  Widget _buildMyAppointmentsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _openAppointments,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.getBgGlass(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.getBorder(context)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.getGold(context).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.event_note_rounded,
                    color: AppTheme.getGold(context), size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('myAppointments'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.getTextPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tr('myAppointmentsSub'),
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.getTextSecondary(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_rounded,
                  size: 16, color: AppTheme.getTextTertiary(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChips() {
    // "All" + one chip per salon category.
    final chips = <(String?, String)>[
      (null, tr('all')),
      ..._categories
          .map((c) => (c['id']?.toString(), c['name']?.toString() ?? '')),
    ];
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: chips.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final id = chips[i].$1;
          final label = chips[i].$2;
          final isSelected = _selectedCategoryId == id;
          return GestureDetector(
            onTap: () => setState(() => _selectedCategoryId = id),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.getGold(context)
                    : AppTheme.getBgGlass(context),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? AppTheme.getGold(context)
                      : AppTheme.getBorder(context),
                ),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isSelected
                      ? Colors.white
                      : AppTheme.getTextSecondary(context),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStylesGrid() {
    final styles = _filteredStyles;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text('Styles',
              style: AppTheme.displayFont.copyWith(
                fontSize: 18,
                color: AppTheme.getTextPrimary(context),
              )),
        ),
        if (_categories.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildCategoryChips(),
        ],
        const SizedBox(height: 12),
        if (styles.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Center(
              child: Text(
                tr('noStylesYet'),
                style: TextStyle(
                    fontSize: 13, color: AppTheme.getTextSecondary(context)),
              ),
            ),
          )
        else
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.62,
            ),
            itemCount: styles.length,
            itemBuilder: (context, i) {
              final s = styles[i];
              final img =
                  ApiClient.getImageUrl(s['imageUrl']?.toString() ?? '');
              return Container(
                decoration: BoxDecoration(
                  color: AppTheme.getBgGlass(context),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.getBorder(context)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius:
                            const BorderRadius.vertical(top: Radius.circular(13)),
                        child: img.isNotEmpty
                            ? Image.network(img,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => _styleFallback())
                            : _styleFallback(),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s['name']?.toString() ?? '',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.getTextPrimary(context),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          // Price is optional — only show it when set.
                          if (s['price'] != null)
                            Text('${s["price"]} ${tr("fcfa")}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.getGold(context),
                                )),
                          if (s['longevity'] != null &&
                              s['longevity'].toString().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Row(
                                children: [
                                  Icon(Icons.schedule,
                                      size: 10,
                                      color: AppTheme.getTextTertiary(context)),
                                  const SizedBox(width: 3),
                                  Expanded(
                                    child: Text(s['longevity'].toString(),
                                        style: TextStyle(
                                          fontSize: 10,
                                          color:
                                              AppTheme.getTextTertiary(context),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _styleFallback() => Container(
        color: AppTheme.getBgGlass(context),
        child: Center(
            child: Icon(Icons.image_not_supported_outlined,
                color: AppTheme.getTextTertiary(context))),
      );

  Widget _buildServicesList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text('Services',
              style: AppTheme.displayFont.copyWith(
                fontSize: 18,
                color: AppTheme.getTextPrimary(context),
              )),
        ),
        const SizedBox(height: 8),
        ..._services.map((s) => GlassCard(
              margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s['name']?.toString() ?? '',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.getTextPrimary(context),
                            )),
                        if (s['description'] != null) ...[
                          const SizedBox(height: 2),
                          Text(s['description'].toString(),
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.getTextSecondary(context),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('${s["price"] ?? "0"} ${tr("fcfa")}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.getGold(context),
                      )),
                ],
              ),
            )),
      ],
    );
  }

  Widget _buildStylistsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text('Stylists',
              style: AppTheme.displayFont.copyWith(
                fontSize: 18,
                color: AppTheme.getTextPrimary(context),
              )),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 110,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemCount: _stylists.length,
            itemBuilder: (context, i) {
              final st = _stylists[i];
              final photo = ApiClient.getImageUrl(
                  st['photoUrl']?.toString() ?? st['photo']?.toString() ?? '');
              return Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.getBorder(context)),
                    ),
                    child: photo.isNotEmpty
                        ? Image.network(photo,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => _stylistFallback())
                        : _stylistFallback(),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: 80,
                    child: Text(st['name']?.toString() ?? '',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.getTextSecondary(context),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _stylistFallback() => Container(
        color: AppTheme.getBgGlass(context),
        child: Icon(Icons.person_outline,
            color: AppTheme.getTextTertiary(context)),
      );
}
