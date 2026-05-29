import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../l10n/app_locale.dart';
import '../../services/api_client.dart';
import '../../services/public_service.dart';
import '../../services/storage_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/gold_button.dart';

/// Guest-facing loyalty view. Hits the public lookup endpoint with the
/// guest's phone (saved if available, otherwise prompts). 404 → friendly
/// "not enrolled yet" empty state.
class GuestLoyaltyScreen extends StatefulWidget {
  const GuestLoyaltyScreen({super.key});

  @override
  State<GuestLoyaltyScreen> createState() => _GuestLoyaltyScreenState();
}

class _GuestLoyaltyScreenState extends State<GuestLoyaltyScreen> {
  final _phoneCtrl = TextEditingController();
  bool _loading = false;
  String? _errorMessage;
  bool _notEnrolled = false;
  Map<String, dynamic>? _data;

  String? get _salonId => StorageService.instance.selectedSalonId;

  @override
  void initState() {
    super.initState();
    final savedPhone = StorageService.instance.guestPhone;
    if (savedPhone != null && savedPhone.isNotEmpty) {
      _phoneCtrl.text = savedPhone;
      _lookup();
    }
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _lookup() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) {
      setState(() => _errorMessage = 'Enter your phone number to continue.');
      return;
    }
    final salonId = _salonId;
    if (salonId == null) {
      setState(() => _errorMessage = 'No salon selected.');
      return;
    }
    setState(() {
      _loading = true;
      _errorMessage = null;
      _notEnrolled = false;
      _data = null;
    });
    try {
      final res = await PublicService.instance
          .lookupGuestLoyalty(salonId, phone: phone);
      final data = (res['data'] ?? res) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (e.statusCode == 404) {
          _notEnrolled = true;
        } else {
          _errorMessage = e.message;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final salonName = StorageService.instance.selectedSalonName ?? '';
    return Scaffold(
      backgroundColor: AppTheme.getBgPrimary(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppTheme.getTextPrimary(context)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'My points${salonName.isEmpty ? "" : " · $salonName"}',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppTheme.getTextPrimary(context),
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            _buildLookupBar(),
            const SizedBox(height: 20),
            _buildContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildLookupBar() {
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.getBgGlass(context),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.getBorder(context)),
            ),
            child: TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              onSubmitted: (_) => _lookup(),
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.getTextPrimary(context),
              ),
              decoration: InputDecoration(
                hintText: 'Your phone number',
                hintStyle: TextStyle(
                  fontSize: 14,
                  color: AppTheme.getTextTertiary(context),
                ),
                prefixIcon: Icon(Icons.phone_outlined,
                    size: 18, color: AppTheme.getTextTertiary(context)),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 50,
          child: GoldButton(
            text: _loading ? '...' : 'Check',
            enabled: !_loading,
            onPressed: _lookup,
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: CircularProgressIndicator(
            color: AppTheme.getGold(context),
            strokeWidth: 2,
          ),
        ),
      );
    }
    if (_errorMessage != null) {
      return _errorState(_errorMessage!);
    }
    if (_notEnrolled) {
      return _emptyEnrolled();
    }
    final data = _data;
    if (data == null) {
      return _intro();
    }
    return _buildLoyaltyContent(data);
  }

  Widget _intro() {
    return GlassCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.workspace_premium_outlined,
              color: AppTheme.getGold(context), size: 32),
          const SizedBox(height: 10),
          Text(
            'Track your points',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.getTextPrimary(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Enter the phone number you used at the salon to see your tier, points, and rewards.',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.getTextSecondary(context),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyEnrolled() {
    return GlassCard(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          Icon(Icons.spa_outlined,
              color: AppTheme.getTextTertiary(context), size: 36),
          const SizedBox(height: 12),
          Text(
            'You\'re not enrolled yet',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppTheme.getTextPrimary(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Book your first appointment — points start accumulating after your visit.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.getTextSecondary(context),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorState(String message) {
    return GlassCard(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: AppTheme.accentRed, size: 32),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.getTextSecondary(context),
            ),
          ),
          const SizedBox(height: 12),
          GoldButton(text: tr('retry'), onPressed: _lookup),
        ],
      ),
    );
  }

  Widget _buildLoyaltyContent(Map<String, dynamic> data) {
    final points = data['points'] ?? 0;
    final tier = (data['tier'] ?? 'bronze').toString();
    final visits = data['visits'] ?? 0;
    final pointsToNext =
        data['pointsToNextTier'] ?? data['tierProgress']?['pointsToNextTier'];
    final nextTier = data['nextTier'] ?? data['tierProgress']?['nextTier'];
    final punch = data['punchCard'] as Map<String, dynamic>?;
    final activities = (data['activities'] ?? data['history'] ?? []) as List;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPointsCard(points: points, tier: tier, visits: visits),
        if (pointsToNext != null && nextTier != null) ...[
          const SizedBox(height: 12),
          _buildTierProgress(
              pointsToNext: pointsToNext, nextTier: nextTier.toString()),
        ],
        if (punch != null) ...[
          const SizedBox(height: 12),
          _buildPunchCard(punch),
        ],
        const SizedBox(height: 18),
        if (activities.isNotEmpty)
          _buildActivities(List<Map<String, dynamic>>.from(
              activities.whereType<Map>())),
      ],
    );
  }

  Widget _buildPointsCard(
      {required dynamic points, required String tier, required dynamic visits}) {
    final color = _tierColor(tier);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.18),
            AppTheme.getBgGlass(context),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              tier.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text('$points',
              style: AppTheme.displayFont.copyWith(
                fontSize: 48,
                color: AppTheme.getGold(context),
              )),
          Text(
            'POINTS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
              color: AppTheme.getTextSecondary(context),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '$visits ${visits == 1 ? "visit" : "visits"} so far',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.getTextSecondary(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTierProgress(
      {required dynamic pointsToNext, required String nextTier}) {
    final pts = (pointsToNext is int)
        ? pointsToNext
        : int.tryParse(pointsToNext.toString()) ?? 0;
    return GlassCard(
      margin: EdgeInsets.zero,
      child: Row(
        children: [
          Icon(Icons.trending_up_rounded,
              color: AppTheme.getGold(context), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$pts pts to ${nextTier.toUpperCase()}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.getTextPrimary(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Keep visiting to level up.',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.getTextSecondary(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPunchCard(Map<String, dynamic> punch) {
    final current =
        (punch['stamps'] ?? punch['current'] ?? punch['punchCount'] ?? 0) as int;
    final total =
        (punch['totalNeeded'] ?? punch['total'] ?? punch['punchTotal'] ?? 10)
            as int;
    final complete = punch['complete'] == true;

    return GlassCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.card_giftcard,
                  size: 18, color: AppTheme.getGold(context)),
              const SizedBox(width: 8),
              Text(
                'Punch card',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.getTextPrimary(context),
                ),
              ),
              const Spacer(),
              Text(
                '$current / $total',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.getGold(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(total, (i) {
              final filled = i < current;
              return Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: filled
                      ? AppTheme.getGoldDim(context)
                      : AppTheme.getBgGlass(context),
                  border: Border.all(
                    color: filled
                        ? AppTheme.getGold(context).withValues(alpha: 0.5)
                        : AppTheme.getBorder(context),
                  ),
                ),
                child: filled
                    ? Icon(Icons.check,
                        size: 14, color: AppTheme.getGold(context))
                    : null,
              );
            }),
          ),
          if (complete) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.accentGreen.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'CARD COMPLETE — ASK FOR YOUR REWARD',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.accentGreen,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActivities(List<Map<String, dynamic>> activities) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'History',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.getTextSecondary(context),
              letterSpacing: 0.3,
            ),
          ),
        ),
        ...activities.map((a) {
          final type = (a['type'] ?? 'earn').toString();
          final points = a['points'];
          final desc = (a['description'] ?? '').toString();
          final createdAt =
              a['createdAt']?.toString() ?? a['date']?.toString();
          final isRedeem = type == 'redeem';

          String formatted = '';
          if (createdAt != null && createdAt.isNotEmpty) {
            try {
              formatted = DateFormat('MMM d, y')
                  .format(DateTime.parse(createdAt));
            } catch (_) {
              formatted = createdAt;
            }
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.getBgGlass(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.getBorder(context)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          desc.isEmpty
                              ? (isRedeem
                                  ? 'Points redeemed'
                                  : 'Points earned')
                              : desc,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.getTextPrimary(context),
                          ),
                        ),
                        if (formatted.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            formatted,
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.getTextTertiary(context),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (points != null)
                    Text(
                      isRedeem ? '−$points' : '+$points',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isRedeem
                            ? AppTheme.accentRed
                            : AppTheme.accentGreen,
                      ),
                    ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Color _tierColor(String tier) {
    switch (tier.toLowerCase()) {
      case 'platinum':
        return Colors.purple.shade400;
      case 'gold':
        return Colors.amber.shade700;
      case 'silver':
        return Colors.blueGrey.shade400;
      case 'bronze':
      default:
        return Colors.brown.shade400;
    }
  }
}
