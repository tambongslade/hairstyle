import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../l10n/app_locale.dart';
import '../../services/admin_service.dart';

class AdminAnalytics extends StatefulWidget {
  const AdminAnalytics({super.key});

  @override
  State<AdminAnalytics> createState() => _AdminAnalyticsState();
}

class _AdminAnalyticsState extends State<AdminAnalytics> {
  bool _isLoading = true;
  String _selectedPeriod = '7days'; // today, 7days, 30days, 90days

  // Analytics overview data (with fallback defaults)
  String _totalRevenue = '342,500';
  String _revenueChange = '+18.5%';
  String _revenueComparison = '';
  String _avgTicket = '6,850 F';
  String _avgTicketChange = '+8%';
  String _visits = '52';
  String _visitsChange = '+12%';
  String _tryOns = '134';
  String _tryOnsChange = '+24%';

  // Customer insight data (with fallback defaults)
  String _retentionRate = '78%';
  String _newCustomers = '14';
  String _avgFrequency = '2.3x';
  String _churnRisk = '6';

  // Revenue chart data (with fallback defaults)
  List<int> _chartValues = [35, 52, 41, 68, 55, 73, 60];
  List<String> _chartLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  // Loyalty data (with fallback defaults)
  int _platinumCount = 8;
  int _goldCount = 15;
  int _silverCount = 32;
  int _bronzeCount = 67;
  String _pointsIssued = '12,400';
  String _redeemed = '3,200';
  String _referrals = '18';

  @override
  void initState() {
    super.initState();
    _revenueComparison = tr('vsLastWeek');
    _fetchAllData();
  }

  String get _periodQueryValue => _selectedPeriod;

  Future<void> _fetchAllData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _fetchOverview(),
      _fetchRevenueChart(),
      _fetchLoyaltyAnalytics(),
    ]);
    setState(() => _isLoading = false);
  }

  Future<void> _fetchOverview() async {
    try {
      final response = await AdminService.instance.getAnalyticsOverview(
        query: {'period': _periodQueryValue},
      );
      final data = response['data'] ?? response;
      if (data is Map<String, dynamic>) {
        setState(() {
          _totalRevenue = _formatNumber(data['totalRevenue']);
          _revenueChange = '+${data['revenueChange'] ?? 0}%';
          _avgTicket = '${_formatNumber(data['avgTicket'])} F';
          _visits = '${data['totalVisits'] ?? _visits}';
          _visitsChange = '+${data['visitsChange'] ?? 0}%';
          _tryOns = '${data['totalTryOns'] ?? _tryOns}';
          _retentionRate = '${data['customerRetention'] ?? _retentionRate}%';
          _newCustomers = '${data['newCustomers'] ?? _newCustomers}';
          if (data['totalCustomers'] != null) {
            _churnRisk = '${data['totalCustomers']}';
          }
        });
      }
    } catch (e) {
      debugPrint('Failed to fetch analytics overview: $e');
    }
  }

  Future<void> _fetchRevenueChart() async {
    try {
      final response = await AdminService.instance.getRevenueChart(
        query: {'period': _periodQueryValue},
      );
      final data = response['data'] ?? response;
      if (data is Map<String, dynamic>) {
        final values = data['values'] ?? data['chartValues'];
        final labels = data['labels'] ?? data['chartLabels'];
        if (values is List && values.isNotEmpty) {
          setState(() {
            _chartValues = values.map<int>((v) => (v is num) ? v.toInt() : 0).toList();
          });
        }
        if (labels is List && labels.isNotEmpty) {
          setState(() {
            _chartLabels = labels.map<String>((l) => '$l').toList();
          });
        }
      } else if (data is List && data.isNotEmpty) {
        setState(() {
          _chartValues = data.map<int>((item) {
            if (item is Map) return ((item['value'] ?? item['amount'] ?? 0) as num).toInt();
            if (item is num) return item.toInt();
            return 0;
          }).toList();
          if (data.first is Map && data.first['label'] != null) {
            _chartLabels = data.map<String>((item) => '${item['label']}').toList();
          }
        });
      }
    } catch (e) {
      debugPrint('Failed to fetch revenue chart: $e');
    }
  }

  Future<void> _fetchLoyaltyAnalytics() async {
    try {
      final response = await AdminService.instance.getLoyaltyAnalytics();
      final data = response['data'] ?? response;
      if (data is Map<String, dynamic>) {
        final tiers = data['tierDistribution'] as Map<String, dynamic>? ?? {};
        setState(() {
          _platinumCount = (tiers['platinum'] ?? _platinumCount) is int ? (tiers['platinum'] ?? _platinumCount) : int.tryParse('${tiers['platinum']}') ?? _platinumCount;
          _goldCount = (tiers['gold'] ?? _goldCount) is int ? (tiers['gold'] ?? _goldCount) : int.tryParse('${tiers['gold']}') ?? _goldCount;
          _silverCount = (tiers['silver'] ?? _silverCount) is int ? (tiers['silver'] ?? _silverCount) : int.tryParse('${tiers['silver']}') ?? _silverCount;
          _bronzeCount = (tiers['bronze'] ?? _bronzeCount) is int ? (tiers['bronze'] ?? _bronzeCount) : int.tryParse('${tiers['bronze']}') ?? _bronzeCount;
          _pointsIssued = _formatNumber(data['activeMembers'] ?? _pointsIssued);
          _redeemed = _formatNumber(data['totalPointsRedeemed'] ?? _redeemed);
          _referrals = '${data['referralConversions'] ?? _referrals}';
        });
      }
    } catch (e) {
      debugPrint('Failed to fetch loyalty analytics: $e');
    }
  }

  String _formatNumber(dynamic value) {
    if (value == null) return '0';
    final num n = value is num ? value : num.tryParse('$value') ?? 0;
    if (n >= 1000) {
      return '${(n / 1000).toStringAsFixed(n % 1000 == 0 ? 0 : 1)}k';
    }
    return '$value';
  }

  void _onPeriodChanged(String period) {
    setState(() => _selectedPeriod = period);
    _fetchAllData();
  }

  bool get _isTablet => MediaQuery.of(context).size.width >= 600;
  double get _maxWidth => _isTablet ? 700.0 : double.infinity;

  @override
  Widget build(BuildContext context) {
    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        _buildHeader(),
        _buildPeriodSelector(),
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.only(top: 40),
            child: Center(child: CircularProgressIndicator()),
          )
        else ...[
          _buildRevenueCard(),
          _buildMetricsRow(),
          const SizedBox(height: 22),
          _buildCustomerMetrics(),
          const SizedBox(height: 22),
          _buildLoyaltyMetrics(),
        ],
        const SizedBox(height: 120),
      ],
    );

    if (_isTablet) {
      content = Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: _maxWidth),
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
              Text(tr('analytics'), style: AppTheme.displayFont.copyWith(fontSize: 24, color: AppTheme.getTextPrimary(context))),
              Text(tr('salonPerformance'),
                  style: TextStyle(fontSize: 12, color: AppTheme.getTextSecondary(context))),
            ],
          ),
        );
      }
    );
  }

  Widget _buildPeriodSelector() {
    final periods = [
      ('today', tr('today')),
      ('7days', tr('days7')),
      ('30days', tr('days30')),
      ('90days', tr('days90')),
    ];
    return Builder(
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Row(
            children: periods.map((entry) {
              final isSelected = _selectedPeriod == entry.$1;
              return Expanded(
                child: GestureDetector(
                  onTap: () => _onPeriodChanged(entry.$1),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.getGold(context) : AppTheme.getBgSecondary(context),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? AppTheme.getGold(context) : AppTheme.getBorder(context),
                      ),
                    ),
                    child: Center(
                      child: Text(entry.$2, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : AppTheme.getTextSecondary(context))),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      }
    );
  }

  Widget _buildRevenueCard() {
    return Builder(
      builder: (context) {
        return Container(
          margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.getBgSecondary(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.getBorder(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr('totalRevenue'), style: TextStyle(fontSize: 12, color: AppTheme.getTextSecondary(context))),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(_totalRevenue, style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -1, color: AppTheme.getTextPrimary(context))),
                  const SizedBox(width: 4),
                  Text('FCFA', style: TextStyle(fontSize: 14, color: AppTheme.getTextSecondary(context))),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.trending_up, size: 12, color: AppTheme.accentGreen),
                      const SizedBox(width: 4),
                      Text(_revenueChange, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.accentGreen)),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Text(_revenueComparison, style: TextStyle(fontSize: 11, color: AppTheme.getTextSecondary(context))),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 60,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: _chartValues.map((val) {
                    final maxVal = _chartValues.reduce((a, b) => a > b ? a : b);
                    final barHeight = maxVal > 0 ? (val / maxVal) * 60 : 0.0;
                    return Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        height: barHeight.toDouble(),
                        decoration: BoxDecoration(
                          color: AppTheme.getGold(context),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: _chartLabels.map((d) {
                  return Expanded(
                    child: Center(child: Text(d, style: TextStyle(fontSize: 11, color: AppTheme.getTextSecondary(context)))),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      }
    );
  }

  Widget _buildMetricsRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          _metricCard(tr('avgTicket'), _avgTicket, Icons.receipt_long, AppTheme.accentBlue, _avgTicketChange),
          const SizedBox(width: 10),
          _metricCard(tr('visits'), _visits, Icons.directions_walk, AppTheme.accentGreen, _visitsChange),
          const SizedBox(width: 10),
          _metricCard(tr('tryOns'), _tryOns, Icons.visibility_outlined, const Color(0xFFAB68FF), _tryOnsChange),
        ],
      ),
    );
  }

  Widget _metricCard(String label, String value, IconData icon, Color color, String change) {
    return Expanded(
      child: Builder(
        builder: (context) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.getBgSecondary(context),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.getBorder(context)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(height: 8),
                Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.getTextPrimary(context))),
                Text(label, style: TextStyle(fontSize: 12, color: AppTheme.getTextSecondary(context))),
                const SizedBox(height: 4),
                Text(change, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.accentGreen)),
              ],
            ),
          );
        }
      ),
    );
  }

  Widget _buildCustomerMetrics() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(tr('customerInsights'), style: AppTheme.displayFont.copyWith(fontSize: 18, color: AppTheme.getTextPrimary(context))),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(
                child: _insightCard(tr('retentionRate'), _retentionRate, AppTheme.accentGreen,
                    tr('retentionSub')),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _insightCard(tr('newCustomers'), _newCustomers, AppTheme.accentBlue,
                    tr('newCustomersSub')),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(
                child: _insightCard(tr('avgFrequency'), _avgFrequency, AppTheme.gold,
                    tr('avgFreqSub')),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _insightCard(tr('churnRisk'), _churnRisk, AppTheme.accentRed,
                    tr('churnSub')),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _insightCard(String label, String value, Color color, String desc) {
    return Builder(
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.getBgSecondary(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.getBorder(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.getTextPrimary(context))),
              const SizedBox(height: 2),
              Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.getTextPrimary(context))),
              const SizedBox(height: 4),
              Text(desc, style: TextStyle(fontSize: 10, color: AppTheme.getTextSecondary(context), height: 1.3)),
            ],
          ),
        );
      }
    );
  }

  Widget _buildLoyaltyMetrics() {
    return Builder(
      builder: (context) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(tr('loyaltyPerformance'), style: AppTheme.displayFont.copyWith(fontSize: 18, color: AppTheme.getTextPrimary(context))),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.getBgSecondary(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.getBorder(context)),
                ),
                child: Column(
                  children: [
                    Text(tr('tierDistribution'), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.getTextPrimary(context))),
                    const SizedBox(height: 14),
                    _tierRow('Platinum', _platinumCount, AppTheme.tealLight),
                    _tierRow('Gold', _goldCount, AppTheme.getGold(context)),
                    _tierRow('Silver', _silverCount, AppTheme.accentBlue),
                    _tierRow('Bronze', _bronzeCount, AppTheme.getTextSecondary(context)),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _loyaltyStat(tr('pointsIssued'), _pointsIssued),
                        _loyaltyStat(tr('redeemed'), _redeemed),
                        _loyaltyStat(tr('referrals'), _referrals),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      }
    );
  }

  Widget _tierRow(String tier, int count, Color color) {
    return Builder(
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              SizedBox(width: 60, child: Text(tier, style: TextStyle(fontSize: 11, color: AppTheme.getTextSecondary(context)))),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: count / 80,
                    minHeight: 6,
                    backgroundColor: AppTheme.getBorder(context),
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(width: 24, child: Text('$count', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color))),
            ],
          ),
        );
      }
    );
  }

  Widget _loyaltyStat(String label, String value) {
    return Builder(
      builder: (context) {
        return Column(
          children: [
            Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.getGold(context))),
            Text(label, style: TextStyle(fontSize: 10, color: AppTheme.getTextSecondary(context))),
          ],
        );
      }
    );
  }
}
