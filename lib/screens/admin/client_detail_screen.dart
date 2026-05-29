import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../l10n/app_locale.dart';
import '../../services/admin_service.dart';
import '../../services/api_client.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/gold_button.dart';

/// Full status for a single client in the salon's loyalty program.
class ClientDetailScreen extends StatefulWidget {
  final String clientId;
  const ClientDetailScreen({super.key, required this.clientId});

  @override
  State<ClientDetailScreen> createState() => _ClientDetailScreenState();
}

class _ClientDetailScreenState extends State<ClientDetailScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _client;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await AdminService.instance.getLoyaltyClient(widget.clientId);
      final data = (res['data'] ?? res) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _client = data;
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

  Future<void> _openAwardSheet() async {
    final client = _client;
    if (client == null) return;
    final phone = (client['clientPhone'] ?? client['phone'] ?? '').toString();
    if (phone.isEmpty) return;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AwardSheet(
        clientPhone: phone,
        clientName: (client['clientName'] ?? client['name'])?.toString(),
        clientEmail: (client['clientEmail'] ?? client['email'])?.toString(),
      ),
    );
    if (saved == true && mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
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
          'Client',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.getTextPrimary(context),
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(child: _buildBody()),
      floatingActionButton: _client == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _openAwardSheet,
              backgroundColor: AppTheme.getGold(context),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Award',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            ),
    );
  }

  Widget _buildBody() {
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
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.getTextSecondary(context))),
              const SizedBox(height: 16),
              GoldButton(text: tr('retry'), onPressed: _load),
            ],
          ),
        ),
      );
    }
    final c = _client!;
    final name = (c['clientName'] ?? c['name'] ?? '').toString();
    final phone = (c['clientPhone'] ?? c['phone'] ?? '').toString();
    final email = (c['clientEmail'] ?? c['email'] ?? '').toString();
    final points = c['points'] ?? 0;
    final tier = (c['tier'] ?? 'bronze').toString();
    final visits = c['visits'] ?? 0;
    final punch = c['punchCard'] as Map<String, dynamic>?;
    final activities = (c['activities'] ?? c['history'] ?? []) as List;

    final pointsToNext = c['pointsToNextTier'] ?? c['tierProgress']?['pointsToNextTier'];
    final nextTier = c['nextTier'] ?? c['tierProgress']?['nextTier'];

    return RefreshIndicator(
      onRefresh: _load,
      color: AppTheme.getGold(context),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
        children: [
          _buildHeader(name: name, phone: phone, email: email),
          const SizedBox(height: 18),
          _buildPointsCard(points: points, tier: tier, visits: visits),
          if (pointsToNext != null && nextTier != null) ...[
            const SizedBox(height: 14),
            _buildTierProgress(
                pointsToNext: pointsToNext, nextTier: nextTier.toString()),
          ],
          if (punch != null) ...[
            const SizedBox(height: 14),
            _buildPunchCard(punch),
          ],
          const SizedBox(height: 18),
          _buildActivities(List<Map<String, dynamic>>.from(
              activities.whereType<Map>())),
        ],
      ),
    );
  }

  Widget _buildHeader(
      {required String name, required String phone, required String email}) {
    return Row(
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: AppTheme.getGoldDim(context),
          child: Text(
            _initials(name, phone),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.getGold(context),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name.isEmpty ? phone : name,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.getTextPrimary(context),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(Icons.phone_outlined,
                      size: 12,
                      color: AppTheme.getTextSecondary(context)),
                  const SizedBox(width: 4),
                  Text(
                    phone,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.getTextSecondary(context),
                    ),
                  ),
                ],
              ),
              if (email.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(
                    children: [
                      Icon(Icons.mail_outline,
                          size: 12,
                          color: AppTheme.getTextSecondary(context)),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          email,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.getTextSecondary(context),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
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
            color.withValues(alpha: 0.15),
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
          const SizedBox(height: 8),
          Text('$points',
              style: AppTheme.displayFont.copyWith(
                fontSize: 44,
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
            '$visits ${visits == 1 ? "visit" : "visits"} total',
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Progress to ${nextTier.toUpperCase()}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: AppTheme.getTextSecondary(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$pts points to go',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.getTextPrimary(context),
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
                'CARD COMPLETE — REWARD READY',
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
        if (activities.isEmpty)
          GlassCard(
            margin: EdgeInsets.zero,
            child: Text(
              'No activity yet. Award points or record a visit to get started.',
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.getTextSecondary(context),
              ),
            ),
          )
        else
          ...activities.map((a) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _activityTile(a),
              )),
      ],
    );
  }

  Widget _activityTile(Map<String, dynamic> a) {
    final type = (a['type'] ?? 'earn').toString();
    final points = a['points'];
    final desc = (a['description'] ?? '').toString();
    final createdAt = a['createdAt']?.toString() ?? a['date']?.toString();
    final isRedeem = type == 'redeem';
    final isVisit = type == 'visit';

    String formattedDate = '';
    if (createdAt != null && createdAt.isNotEmpty) {
      try {
        formattedDate = DateFormat('MMM d, y · HH:mm').format(DateTime.parse(createdAt));
      } catch (_) {
        formattedDate = createdAt;
      }
    }

    IconData icon;
    Color color;
    if (isRedeem) {
      icon = Icons.redeem;
      color = AppTheme.accentRed;
    } else if (isVisit) {
      icon = Icons.event_available;
      color = AppTheme.accentBlue;
    } else {
      icon = Icons.add_circle_outline;
      color = AppTheme.accentGreen;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.getBgGlass(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.getBorder(context)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.15),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  desc.isEmpty ? _defaultDescription(type) : desc,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.getTextPrimary(context),
                  ),
                ),
                if (formattedDate.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    formattedDate,
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
                color: isRedeem ? AppTheme.accentRed : AppTheme.accentGreen,
              ),
            ),
        ],
      ),
    );
  }

  String _defaultDescription(String type) {
    switch (type) {
      case 'redeem':
        return 'Points redeemed';
      case 'visit':
        return 'Visit recorded';
      case 'adjust':
        return 'Adjustment';
      case 'earn':
      default:
        return 'Points earned';
    }
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

  String _initials(String name, String phone) {
    if (name.isNotEmpty) {
      final parts = name.trim().split(RegExp(r'\s+'));
      if (parts.length >= 2) {
        return (parts[0][0] + parts[1][0]).toUpperCase();
      }
      return parts[0][0].toUpperCase();
    }
    if (phone.isNotEmpty) {
      final digits = phone.replaceAll(RegExp(r'\D'), '');
      if (digits.isNotEmpty) return digits.substring(digits.length - 2);
    }
    return '?';
  }
}

/// Bottom sheet that posts to /admin/loyalty/clients/award.
class _AwardSheet extends StatefulWidget {
  final String clientPhone;
  final String? clientName;
  final String? clientEmail;
  const _AwardSheet({
    required this.clientPhone,
    this.clientName,
    this.clientEmail,
  });

  @override
  State<_AwardSheet> createState() => _AwardSheetState();
}

class _AwardSheetState extends State<_AwardSheet> {
  String _type = 'earn';
  final _valueCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _saving = false;
  String? _error;

  static const _types = [
    ('earn', 'Award points', Icons.add_circle_outline, 'Points'),
    ('redeem', 'Redeem points', Icons.redeem, 'Points'),
    ('visit', 'Mark visit', Icons.event_available, 'Visits'),
    ('adjust', 'Stamp punch', Icons.card_giftcard, 'Stamps'),
  ];

  @override
  void dispose() {
    _valueCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  String get _valueLabel {
    final t = _types.firstWhere((e) => e.$1 == _type);
    return t.$4;
  }

  Future<void> _submit() async {
    final value = int.tryParse(_valueCtrl.text.trim());
    if (value == null || value <= 0) {
      setState(() => _error = 'Enter a positive number.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final body = <String, dynamic>{
        'clientPhone': widget.clientPhone,
        if (widget.clientName != null && widget.clientName!.isNotEmpty)
          'clientName': widget.clientName,
        if (widget.clientEmail != null && widget.clientEmail!.isNotEmpty)
          'clientEmail': widget.clientEmail,
        'type': _type,
        if (_descCtrl.text.trim().isNotEmpty)
          'description': _descCtrl.text.trim(),
      };
      switch (_type) {
        case 'visit':
          body['visits'] = value;
          break;
        case 'adjust':
          body['stamps'] = value;
          break;
        case 'earn':
        case 'redeem':
          body['points'] = value;
          break;
      }
      await AdminService.instance.awardLoyalty(body);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: AppTheme.getBgPrimary(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: ListView(
          controller: scrollController,
          padding: EdgeInsets.fromLTRB(24, 14, 24, bottomInset + 24),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.getBorder(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Award loyalty',
              style: AppTheme.displayFont.copyWith(
                fontSize: 22,
                color: AppTheme.getTextPrimary(context),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.clientName?.isNotEmpty == true
                  ? '${widget.clientName} · ${widget.clientPhone}'
                  : widget.clientPhone,
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.getTextSecondary(context),
              ),
            ),
            const SizedBox(height: 18),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.6,
              children: _types.map((t) {
                final selected = _type == t.$1;
                return GestureDetector(
                  onTap: () => setState(() => _type = t.$1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppTheme.getGoldDim(context)
                          : AppTheme.getBgGlass(context),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected
                            ? AppTheme.getGold(context).withValues(alpha: 0.5)
                            : AppTheme.getBorder(context),
                        width: selected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(t.$3,
                            size: 18,
                            color: selected
                                ? AppTheme.getGold(context)
                                : AppTheme.getTextSecondary(context)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            t.$2,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: selected
                                  ? AppTheme.getGold(context)
                                  : AppTheme.getTextPrimary(context),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),
            _field(
              controller: _valueCtrl,
              label: _valueLabel,
              keyboard: TextInputType.number,
            ),
            const SizedBox(height: 12),
            _field(
              controller: _descCtrl,
              label: 'Note (optional)',
              keyboard: TextInputType.text,
              capitalize: true,
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.accentRed,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            const SizedBox(height: 18),
            GoldButton(
              text: _saving ? '...' : 'Save',
              expanded: true,
              enabled: !_saving,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    TextInputType keyboard = TextInputType.text,
    bool capitalize = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.getBgGlass(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.getBorder(context)),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboard,
        textCapitalization:
            capitalize ? TextCapitalization.sentences : TextCapitalization.none,
        style:
            TextStyle(color: AppTheme.getTextPrimary(context), fontSize: 14),
        decoration: InputDecoration(
          hintText: label,
          hintStyle:
              TextStyle(color: AppTheme.getTextTertiary(context), fontSize: 13),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
    );
  }
}
