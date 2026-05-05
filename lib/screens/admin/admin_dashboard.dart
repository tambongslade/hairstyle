import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../l10n/app_locale.dart';
import '../../services/admin_service.dart';
class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  bool _loading = true;
  String? _error;

  // KPIs
  String _todaysRevenue = '0';
  String _totalBookings = '0';
  String _activeCustomers = '0';
  String _tryOns = '0';

  // Lists
  List<_Booking> _todayBookings = [];
  List<Map<String, dynamic>> _topStyles = [];
  List<Map<String, dynamic>> _recentCustomers = [];

  @override
  void initState() {
    super.initState();
    _fetchDashboard();
  }

  Future<void> _fetchDashboard() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await AdminService.instance.getDashboard();
      final data = res['data'] as Map<String, dynamic>? ?? res;

      // KPIs - fields are at top level per API spec
      _todaysRevenue = '${data['todaysRevenue'] ?? 0}';
      _totalBookings = '${data['bookingsToday'] ?? 0}';
      _activeCustomers = '${data['customersCheckedIn'] ?? 0}';
      _tryOns = '${data['tryOnsThisWeek'] ?? 0}';

      // Today's bookings
      final bookingsRaw = data['todayBookings'] ?? data['today_bookings'] ?? [];
      _todayBookings = (bookingsRaw as List).map((b) {
        return _Booking(
          b['id']?.toString() ?? '',
          b['customerName'] ?? b['customer_name'] ?? '',
          b['service'] ?? '',
          b['time'] ?? '',
          b['stylist'] ?? '',
          b['status'] ?? 'pending',
        );
      }).toList();

      // Top styles
      final stylesRaw = data['topStyles'] ?? data['top_styles'] ?? [];
      _topStyles = List<Map<String, dynamic>>.from(stylesRaw);

      // Recent customers
      final customersRaw = data['recentCustomers'] ?? data['recent_customers'] ?? [];
      _recentCustomers = List<Map<String, dynamic>>.from(customersRaw);

      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  bool get _isTablet => MediaQuery.of(context).size.width >= 600;
  double get _maxWidth => _isTablet ? 700.0 : double.infinity;

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        _buildHeader(),
        _buildQuickStats(),
        _buildTodayBookings(),
        const SizedBox(height: 22),
        _buildPopularStyles(),
        const SizedBox(height: 22),
        _buildRecentCustomers(),
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

    return RefreshIndicator(
      onRefresh: _fetchDashboard,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        child: content,
      ),
    );
  }

  Widget _buildHeader() {
    return Builder(
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.asset(
                    'assets/logo.png',
                    height: 36,
                    fit: BoxFit.contain,
                  ),
                  Text(tr('adminDashboardTitle'),
                      style: TextStyle(fontSize: 12, color: AppTheme.getTextSecondary(context))),
                ],
              ),
              Row(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.circle, size: 6, color: AppTheme.accentGreen),
                      const SizedBox(width: 6),
                      Text(tr('open'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.accentGreen)),
                    ],
                  ),
                  const SizedBox(width: 10),
                  Icon(Icons.notifications_outlined, color: AppTheme.getTextSecondary(context), size: 22),
                ],
              ),
            ],
          ),
        );
      }
    );
  }

  Widget _buildQuickStats() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Builder(
        builder: (context) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              color: AppTheme.getBgSecondary(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.getBorder(context)),
            ),
            child: Row(
              children: [
                _statItem(_todaysRevenue, 'FCFA', tr('todaysRevenue')),
                _divider(context),
                _statItem(_totalBookings, tr('today'), tr('bookings')),
                _divider(context),
                _statItem(_activeCustomers, tr('checkedIn'), tr('customers')),
                _divider(context),
                _statItem(_tryOns, tr('thisWeek'), tr('tryOns')),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _statItem(String value, String unit, String label) {
    return Expanded(
      child: Builder(
        builder: (context) {
          return Column(
            children: [
              Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.getTextPrimary(context))),
              const SizedBox(height: 2),
              Text(unit, style: TextStyle(fontSize: 10, color: AppTheme.getGold(context), fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(label, style: TextStyle(fontSize: 10, color: AppTheme.getTextTertiary(context))),
            ],
          );
        },
      ),
    );
  }

  Widget _divider(BuildContext context) {
    return Container(
      width: 1, height: 36,
      color: AppTheme.getBorder(context),
    );
  }

  Widget _buildTodayBookings() {
    final bookings = _todayBookings;

    return Builder(
      builder: (context) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 22),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(tr('todaysBookings'), style: AppTheme.displayFont.copyWith(fontSize: 18, color: AppTheme.getTextPrimary(context))),
                  Text('${bookings.length} ${tr('total')}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.getTextSecondary(context))),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (bookings.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(tr('noBookingsToday'), style: TextStyle(fontSize: 13, color: AppTheme.getTextSecondary(context))),
              ),
            ...bookings.map((b) => Container(
                  margin: const EdgeInsets.fromLTRB(20, 0, 20, 6),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: AppTheme.getBgSecondary(context),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.getBorder(context)),
                  ),
                  child: Row(
                    children: [
                      Text(b.time, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.getGold(context))),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(b.customerName, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.getTextPrimary(context))),
                            Text('${b.service} · ${b.stylist}', style: TextStyle(fontSize: 11, color: AppTheme.getTextSecondary(context))),
                          ],
                        ),
                      ),
                      _StatusBadge(status: b.status),
                    ],
                  ),
                )),
          ],
        );
      }
    );
  }

  Widget _buildPopularStyles() {
    final defaultColors = [AppTheme.gold, AppTheme.accentBlue, AppTheme.accentGreen, const Color(0xFFAB68FF)];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(tr('topStylesWeek'), style: AppTheme.displayFont.copyWith(fontSize: 18, color: AppTheme.getTextPrimary(context))),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _topStyles.isEmpty
              ? Builder(builder: (context) => Text(tr('noData'), style: TextStyle(fontSize: 13, color: AppTheme.getTextSecondary(context))))
              : Column(
                  children: List.generate(_topStyles.length, (i) {
                    final s = _topStyles[i];
                    return _popularStyleRow(
                      s['name'] ?? '',
                      ((s['tryOnCount'] ?? s['count'] ?? 0) as num).toInt(),
                      'try-ons',
                      defaultColors[i % defaultColors.length],
                    );
                  }),
                ),
        ),
      ],
    );
  }

  Widget _popularStyleRow(String name, int count, String unit, Color color) {
    return Builder(
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.getTextPrimary(context))),
              ),
              Text('$count', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
              const SizedBox(width: 4),
              Text(unit, style: TextStyle(fontSize: 11, color: AppTheme.getTextSecondary(context))),
              const SizedBox(width: 12),
              SizedBox(
                width: 80,
                height: 6,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: count / 50,
                    backgroundColor: AppTheme.getBorder(context),
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
              ),
            ],
          ),
        );
      }
    );
  }

  Widget _buildRecentCustomers() {
    return Builder(
      builder: (context) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(tr('recentCustomers'), style: AppTheme.displayFont.copyWith(fontSize: 18, color: AppTheme.getTextPrimary(context))),
                  Text(tr('seeAll'), style: TextStyle(fontSize: 12, color: AppTheme.getGold(context), fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 100,
              child: _recentCustomers.isEmpty
                  ? Center(child: Text(tr('noData'), style: TextStyle(fontSize: 13, color: AppTheme.getTextSecondary(context))))
                  : ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      scrollDirection: Axis.horizontal,
                      children: _recentCustomers.map((c) {
                        final name = c['name'] ?? '';
                        final tier = c['tier'] ?? '';
                        final visits = c['visits'] ?? 0;
                        return _customerChip(name, tier, '$visits ${tr('visits').toLowerCase()}');
                      }).toList(),
                    ),
            ),
          ],
        );
      }
    );
  }

  Widget _customerChip(String name, String tier, String visits) {
    return Builder(
      builder: (context) {
        return Container(
          width: 110,
          margin: const EdgeInsets.only(right: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.getBgSecondary(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.getBorder(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(name, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.getTextPrimary(context)),
                  overflow: TextOverflow.ellipsis, maxLines: 1),
              const SizedBox(height: 4),
              if (tier.isNotEmpty)
                Text(tier, style: TextStyle(fontSize: 10, color: AppTheme.getGold(context), fontWeight: FontWeight.w500)),
              Text(visits, style: TextStyle(fontSize: 10, color: AppTheme.getTextTertiary(context))),
            ],
          ),
        );
      }
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'confirmed' => AppTheme.accentBlue,
      'checked_in' => AppTheme.accentGreen,
      'pending' => const Color(0xFFE5A100),
      _ => AppTheme.textTertiary,
    };
    final label = switch (status) {
      'confirmed' => tr('statusConfirmed'),
      'checked_in' => tr('statusCheckedIn'),
      'pending' => tr('statusPending'),
      _ => status,
    };

    return Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color));
  }
}

class _Booking {
  final String id, customerName, service, time, stylist, status;
  const _Booking(this.id, this.customerName, this.service, this.time, this.stylist, this.status);
}
