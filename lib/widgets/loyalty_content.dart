import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import 'glass_card.dart';

/// Renders a salon fidelity status from a loyalty data map: the points/tier
/// card, tier progress, punch card, and activity history. Shared by the guest
/// phone lookup and the signed-in client fidelity page so both look identical.
class LoyaltyContent extends StatelessWidget {
  final Map<String, dynamic> data;
  const LoyaltyContent({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    // Field names vary by endpoint: the public lookup / me-loyalty payloads use
    // totalPoints/loyaltyTier, while older responses use points/tier. Accept both.
    final points = data['totalPoints'] ?? data['points'] ?? 0;
    final tier =
        (data['loyaltyTier'] ?? data['tier'] ?? 'bronze').toString();
    final visits = data['visits'] ?? data['totalVisits'] ?? 0;
    final pointsToNext =
        data['pointsToNextTier'] ?? data['tierProgress']?['pointsToNextTier'];
    final nextTier = data['nextTier'] ?? data['tierProgress']?['nextTier'];
    final punch = data['punchCard'] as Map<String, dynamic>?;
    final activities = (data['activities'] ?? data['history'] ?? []) as List;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _pointsCard(context, points: points, tier: tier, visits: visits),
        if (pointsToNext != null && nextTier != null) ...[
          const SizedBox(height: 12),
          _tierProgress(context,
              pointsToNext: pointsToNext, nextTier: nextTier.toString()),
        ],
        if (punch != null) ...[
          const SizedBox(height: 12),
          _punchCard(context, punch),
        ],
        const SizedBox(height: 18),
        if (activities.isNotEmpty)
          _activities(context,
              List<Map<String, dynamic>>.from(activities.whereType<Map>())),
      ],
    );
  }

  Widget _pointsCard(BuildContext context,
      {required dynamic points, required String tier, required dynamic visits}) {
    final color = _tierColor(tier);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.18), AppTheme.getBgGlass(context)],
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
              style: AppTheme.displayFont
                  .copyWith(fontSize: 48, color: AppTheme.getGold(context))),
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
                fontSize: 12, color: AppTheme.getTextSecondary(context)),
          ),
        ],
      ),
    );
  }

  Widget _tierProgress(BuildContext context,
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
                      fontSize: 11, color: AppTheme.getTextSecondary(context)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _punchCard(BuildContext context, Map<String, dynamic> punch) {
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
                    ? Icon(Icons.check, size: 14, color: AppTheme.getGold(context))
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

  Widget _activities(
      BuildContext context, List<Map<String, dynamic>> activities) {
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
          final createdAt = a['createdAt']?.toString() ?? a['date']?.toString();
          final isRedeem = type == 'redeem';

          String formatted = '';
          if (createdAt != null && createdAt.isNotEmpty) {
            try {
              formatted =
                  DateFormat('MMM d, y').format(DateTime.parse(createdAt));
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
                              ? (isRedeem ? 'Points redeemed' : 'Points earned')
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
                        color:
                            isRedeem ? AppTheme.accentRed : AppTheme.accentGreen,
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

  static Color _tierColor(String tier) {
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
