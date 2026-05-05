import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../l10n/app_locale.dart';
import '../widgets/gold_button.dart';
import '../widgets/app_toast.dart';
import '../services/customer_service.dart';

class LoyaltyScreen extends StatefulWidget {
  const LoyaltyScreen({super.key});

  @override
  State<LoyaltyScreen> createState() => _LoyaltyScreenState();
}

class _LoyaltyScreenState extends State<LoyaltyScreen> {
  Map<String, dynamic>? _loyaltyProfile;
  Map<String, dynamic>? _punchCard;
  Map<String, dynamic>? _referralInfo;
  List<Map<String, dynamic>> _activities = [];
  bool _loading = true;
  bool _redeeming = false;

  @override
  void initState() {
    super.initState();
    _fetchAllData();
  }

  Future<void> _fetchAllData() async {
    setState(() => _loading = true);
    await Future.wait([
      _fetchLoyaltyProfile(),
      _fetchPunchCard(),
      _fetchActivities(),
      _fetchReferralInfo(),
    ]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _fetchLoyaltyProfile() async {
    try {
      final res = await CustomerService.instance.getLoyaltyProfile();
      final data = res['data'] ?? res;
      if (data is Map<String, dynamic> && mounted) {
        setState(() => _loyaltyProfile = data);
      }
    } catch (_) {}
  }

  Future<void> _fetchPunchCard() async {
    try {
      final res = await CustomerService.instance.getPunchCard();
      final data = res['data'] ?? res;
      if (data is Map<String, dynamic> && mounted) {
        setState(() => _punchCard = data);
      }
    } catch (_) {}
  }

  Future<void> _fetchActivities() async {
    try {
      final res = await CustomerService.instance.getLoyaltyActivities();
      final raw = res['items'] ?? res['activities'] ?? res['history'] ?? res['data'] ?? res;
      final data = raw is List ? raw : (raw is Map ? (raw['items'] ?? raw['activities'] ?? raw['history'] ?? []) : []);
      if (data is List && mounted) {
        setState(() => _activities = List<Map<String, dynamic>>.from(data));
      }
    } catch (_) {}
  }

  Future<void> _fetchReferralInfo() async {
    try {
      final res = await CustomerService.instance.getReferralInfo();
      final data = res['data'] ?? res;
      if (data is Map<String, dynamic> && mounted) {
        setState(() => _referralInfo = data);
      }
    } catch (_) {}
  }

  Future<void> _redeemPoints(int points, String rewardType) async {
    setState(() => _redeeming = true);
    try {
      await CustomerService.instance.redeemPoints({'points': points, 'rewardType': rewardType});
      if (mounted) {
        AppToast.show(context, message: tr('redeemSuccess'), type: ToastType.success);
        _fetchLoyaltyProfile();
        _fetchActivities();
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(context, message: e.toString(), type: ToastType.error);
      }
    } finally {
      if (mounted) setState(() => _redeeming = false);
    }
  }

  Future<void> _shareReferral() async {
    try {
      await CustomerService.instance.shareReferral();
      if (mounted) {
        AppToast.show(context, message: tr('referralShared'), type: ToastType.success);
      }
    } catch (_) {}
  }

  // ── Data accessors ──
  String get _points => _loyaltyProfile?['points']?.toString() ?? '0';
  String get _tier => _loyaltyProfile?['tier']?.toString() ?? 'bronze';
  String get _nextTier => _loyaltyProfile?['nextTier']?.toString() ?? '';
  String get _pointsToNext => _loyaltyProfile?['pointsToNextTier']?.toString() ?? '0';
  double get _progress {
    final p = _loyaltyProfile?['progress'];
    if (p is num) return p.toDouble().clamp(0.0, 1.0);
    final pts = _loyaltyProfile?['points'];
    final toNext = _loyaltyProfile?['pointsToNextTier'];
    if (pts is num && toNext is num && (pts + toNext) > 0) {
      return (pts / (pts + toNext)).clamp(0.0, 1.0);
    }
    return 0.0;
  }

  int get _punchCount => (_punchCard?['current'] ?? _punchCard?['punchCount'] ?? 0) as int;
  int get _punchTotal => (_punchCard?['total'] ?? _punchCard?['punchTotal'] ?? 10) as int;
  String get _referralCode => _referralInfo?['code']?.toString() ?? _referralInfo?['referralCode']?.toString() ?? '';
  int get _referralCount => (_referralInfo?['referralCount'] ?? _referralInfo?['count'] ?? 0) as int;

  @override
  Widget build(BuildContext context) {
    if (_loading && _loyaltyProfile == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppTheme.getGold(context)),
            const SizedBox(height: 12),
            Text(tr('loadingLoyalty'),
                style: TextStyle(fontSize: 13, color: AppTheme.getTextSecondary(context))),
          ],
        ),
      );
    }

    if (!_loading && _loyaltyProfile == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.workspace_premium_outlined, size: 48, color: AppTheme.getTextTertiary(context)),
            const SizedBox(height: 12),
            Text(tr('loyaltyUnavailable'),
                style: TextStyle(fontSize: 14, color: AppTheme.getTextSecondary(context))),
            const SizedBox(height: 16),
            GoldButton(text: tr('retry'), onPressed: _fetchAllData),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchAllData,
      color: AppTheme.getGold(context),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            _buildHeader(),
            const SizedBox(height: 20),
            _buildPointsCard(),
            const SizedBox(height: 16),
            _buildProgressBar(),
            if (_punchCard != null) ...[
              const SizedBox(height: 24),
              _buildPunchCard(),
            ],
            _buildRedeemSection(),
            _buildReferralCard(),
            const SizedBox(height: 28),
            _buildActivitySection(),
            const SizedBox(height: 120),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Center(
        child: Text(tr('loyaltyRewards'),
            style: AppTheme.displayFont.copyWith(fontSize: 24, color: AppTheme.getTextPrimary(context))),
      ),
    );
  }

  Widget _buildPointsCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      decoration: BoxDecoration(
        color: AppTheme.getBgSecondary(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.getBorder(context)),
      ),
      child: Column(
        children: [
          // Tier badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.getGold(context).withValues(alpha: 0.4)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(_tier.toUpperCase(),
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700,
                    color: AppTheme.getGold(context), letterSpacing: 1.5)),
          ),
          const SizedBox(height: 16),
          // Points
          Text(_points,
              style: TextStyle(fontSize: 48, fontWeight: FontWeight.w700,
                  letterSpacing: -2, height: 1, color: AppTheme.getTextPrimary(context))),
          const SizedBox(height: 4),
          Text(tr('points').toUpperCase(),
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500,
                  color: AppTheme.getTextSecondary(context), letterSpacing: 1.5)),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: _progress,
              minHeight: 4,
              backgroundColor: AppTheme.getBorder(context),
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.getGold(context)),
            ),
          ),
          if (_nextTier.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('$_pointsToNext ${tr('morePointsTo')} $_nextTier',
                style: TextStyle(fontSize: 12, color: AppTheme.getTextSecondary(context))),
          ],
        ],
      ),
    );
  }

  Widget _buildPunchCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr('punchCard'),
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.getTextPrimary(context))),
          const SizedBox(height: 4),
          Text('$_punchCount / $_punchTotal ${tr('punchCardSub')}',
              style: TextStyle(fontSize: 12, color: AppTheme.getTextSecondary(context))),
          const SizedBox(height: 14),
          Row(
            children: List.generate(_punchTotal > 10 ? 10 : _punchTotal, (index) {
              final isStamped = index < _punchCount;
              final isReward = index == (_punchTotal > 10 ? 9 : _punchTotal - 1);
              return Expanded(
                child: Container(
                  height: 40,
                  margin: EdgeInsets.only(right: index < (_punchTotal > 10 ? 9 : _punchTotal - 1) ? 6 : 0),
                  decoration: BoxDecoration(
                    color: isStamped
                        ? AppTheme.getGold(context)
                        : AppTheme.getBgSecondary(context),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isReward && !isStamped
                          ? AppTheme.getGold(context)
                          : AppTheme.getBorder(context),
                    ),
                  ),
                  child: Center(
                    child: isStamped
                        ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                        : isReward
                            ? Icon(Icons.card_giftcard_rounded, size: 14, color: AppTheme.getGold(context))
                            : Text('${index + 1}',
                                style: TextStyle(fontSize: 11, color: AppTheme.getTextTertiary(context))),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildRedeemSection() {
    final pts = int.tryParse(_points.replaceAll(',', '')) ?? 0;
    if (pts < 50) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr('redeemPoints'),
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.getTextPrimary(context))),
          const SizedBox(height: 4),
          Text(tr('redeemSub'),
              style: TextStyle(fontSize: 12, color: AppTheme.getTextSecondary(context))),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _buildRedeemTile(
                icon: Icons.discount_outlined,
                label: tr('discount'),
                points: 100,
                enabled: pts >= 100 && !_redeeming,
                onTap: () => _showRedeemConfirm(100, 'discount'),
              )),
              const SizedBox(width: 10),
              Expanded(child: _buildRedeemTile(
                icon: Icons.content_cut_outlined,
                label: tr('freeService'),
                points: 500,
                enabled: pts >= 500 && !_redeeming,
                onTap: () => _showRedeemConfirm(500, 'free_service'),
              )),
              const SizedBox(width: 10),
              Expanded(child: _buildRedeemTile(
                icon: Icons.card_giftcard_outlined,
                label: tr('product'),
                points: 200,
                enabled: pts >= 200 && !_redeeming,
                onTap: () => _showRedeemConfirm(200, 'product'),
              )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRedeemTile({
    required IconData icon,
    required String label,
    required int points,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: AppTheme.getBgSecondary(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: enabled
                ? AppTheme.getGold(context).withValues(alpha: 0.4)
                : AppTheme.getBorder(context),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20,
                color: enabled ? AppTheme.getGold(context) : AppTheme.getTextTertiary(context)),
            const SizedBox(height: 8),
            Text(label,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                    color: enabled ? AppTheme.getTextPrimary(context) : AppTheme.getTextTertiary(context)),
                textAlign: TextAlign.center),
            const SizedBox(height: 2),
            Text('$points pts',
                style: TextStyle(fontSize: 10,
                    color: enabled ? AppTheme.getTextSecondary(context) : AppTheme.getTextTertiary(context))),
          ],
        ),
      ),
    );
  }

  void _showRedeemConfirm(int points, String rewardType) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.getBgSecondary(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(tr('redeemPoints'),
            style: TextStyle(color: AppTheme.getTextPrimary(context), fontWeight: FontWeight.w600)),
        content: Text('${tr("redeemConfirm")} $points ${tr("points")}?',
            style: TextStyle(color: AppTheme.getTextSecondary(context))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr('no'), style: TextStyle(color: AppTheme.getTextSecondary(context))),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _redeemPoints(points, rewardType);
            },
            child: Text(tr('redeem'),
                style: TextStyle(color: AppTheme.getGold(context), fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildReferralCard() {
    if (_referralCode.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(tr('referFriend'),
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.getTextPrimary(context))),
              if (_referralCount > 0)
                Text('$_referralCount ${tr("referred")}',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.getGold(context))),
            ],
          ),
          const SizedBox(height: 4),
          Text(tr('referSub'),
              style: TextStyle(fontSize: 12, color: AppTheme.getTextSecondary(context))),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: AppTheme.getBgSecondary(context),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.getBorder(context)),
                  ),
                  child: Text(_referralCode,
                      style: GoogleFonts.jetBrainsMono(
                          fontSize: 15, fontWeight: FontWeight.w500,
                          color: AppTheme.getGold(context), letterSpacing: 2)),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: _referralCode));
                  AppToast.show(context, message: tr('referralCopied'));
                },
                child: Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: AppTheme.getBgSecondary(context),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.getBorder(context)),
                  ),
                  child: Icon(Icons.copy_rounded, size: 18, color: AppTheme.getTextSecondary(context)),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _shareReferral,
                child: Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: AppTheme.getGold(context),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.share_rounded, size: 18, color: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActivitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(tr('recentActivity'),
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.getTextPrimary(context))),
        ),
        const SizedBox(height: 12),
        if (_activities.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Center(
              child: Text(tr('noActivityYet'),
                  style: TextStyle(fontSize: 13, color: AppTheme.getTextTertiary(context))),
            ),
          )
        else
          ...List.generate(_activities.length > 10 ? 10 : _activities.length, (index) {
            final item = _activities[index];
            final pts = item['points'] ?? item['pointsEarned'] ?? 0;
            final isEarn = (pts is num && pts > 0) || (pts is String && !pts.startsWith('-'));
            final ptsStr = pts is num ? (pts > 0 ? '+$pts' : '$pts') : pts.toString();
            final title = item['description']?.toString() ?? item['title']?.toString() ?? item['type']?.toString() ?? '';
            final date = item['date']?.toString() ?? item['createdAt']?.toString() ?? '';
            final displayDate = date.length > 10 ? date.substring(0, 10) : date;

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                border: index < (_activities.length > 10 ? 9 : _activities.length - 1)
                    ? Border(bottom: BorderSide(color: AppTheme.getBorder(context)))
                    : null,
              ),
              child: Row(
                children: [
                  Text(ptsStr,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: isEarn ? AppTheme.accentGreen : AppTheme.accentRed)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.getTextPrimary(context))),
                        if (displayDate.isNotEmpty)
                          Text(displayDate,
                              style: TextStyle(fontSize: 11, color: AppTheme.getTextTertiary(context))),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}
