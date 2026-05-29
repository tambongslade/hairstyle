import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../l10n/app_locale.dart';
import '../../services/api_client.dart';
import '../../services/public_service.dart';
import '../../services/storage_service.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/gold_button.dart';
import 'guest_loyalty_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _load();
  }

  String? get _salonId => StorageService.instance.selectedSalonId;

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
        ],
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

  Widget _buildMyPointsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const GuestLoyaltyScreen()),
        ),
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
                      'My points',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.getTextPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Track your tier, rewards, and visits.',
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

  Widget _buildStylesGrid() {
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
        const SizedBox(height: 12),
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
            itemCount: _styles.length,
            itemBuilder: (context, i) {
              final s = _styles[i];
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
                          Text('${s["price"] ?? "0"} ${tr("fcfa")}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.getGold(context),
                              )),
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
