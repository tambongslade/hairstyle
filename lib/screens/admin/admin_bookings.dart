import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../l10n/app_locale.dart';
import '../../services/admin_service.dart';
import 'admin_time_slots.dart';

class AdminBookings extends StatefulWidget {
  const AdminBookings({super.key});

  @override
  State<AdminBookings> createState() => _AdminBookingsState();
}

class _AdminBookingsState extends State<AdminBookings> {
  int _selectedDay = 2;
  String _filter = 'all';
  bool _loadingBookings = true;
  bool _loadingSchedule = true;
  bool _actionInProgress = false;

  List<String> _days = [];
  List<DateTime> _dayDates = [];

  List<_AdminBooking> _bookings = [];
  List<_StylistSlot> _stylistSlots = [];

  List<_AdminBooking> get _filteredBookings {
    if (_filter == 'all') return _bookings;
    return _bookings.where((b) => b.status == _filter).toList();
  }

  @override
  void initState() {
    super.initState();
    _initDays();
    _fetchBookings();
    _fetchStylistSchedule();
  }

  static const _weekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  /// The Monday of the currently displayed week
  late DateTime _weekStart;

  void _initDays() {
    final now = DateTime.now();
    _weekStart = now.subtract(Duration(days: now.weekday - 1));
    _buildWeekDays();
    // Select today if it falls within the week
    final todayIndex = _dayDates.indexWhere((d) => d.day == now.day && d.month == now.month && d.year == now.year);
    if (todayIndex >= 0) _selectedDay = todayIndex;
  }

  void _buildWeekDays() {
    _dayDates = List.generate(7, (i) => _weekStart.add(Duration(days: i)));
    _days = _dayDates.map((d) => '${_weekdayNames[d.weekday - 1]} ${d.day}').toList();
  }

  void _changeWeek(int delta) {
    setState(() {
      _weekStart = _weekStart.add(Duration(days: 7 * delta));
      _buildWeekDays();
      _selectedDay = 0;
    });
    _fetchBookings();
    _fetchStylistSchedule();
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _fetchBookings() async {
    setState(() => _loadingBookings = true);
    try {
      final selectedDate = _dayDates[_selectedDay];
      final dateStr = _formatDate(selectedDate);
      final query = <String, String>{'date': dateStr};
      final res = await AdminService.instance.getBookings(query: query);
      final raw = res['data'] ?? res;
      final list = raw is List ? raw : (raw is Map ? (raw['items'] ?? raw['bookings'] ?? []) : []);
      _bookings = (list as List).map((b) {
        final m = b is Map<String, dynamic> ? b : <String, dynamic>{};
        return _AdminBooking(
          m['id']?.toString() ?? '',
          m['customer'] ?? m['customerName'] ?? m['customer_name'] ?? '',
          m['service'] ?? '',
          m['time'] ?? '',
          m['stylist'] ?? '',
          m['status'] ?? 'pending',
          m['price']?.toString() ?? '0',
          m,
        );
      }).toList();
    } catch (e) {
      debugPrint('[AdminBookings] error: $e');
      _bookings = [];
    }
    if (mounted) setState(() => _loadingBookings = false);
  }

  Future<void> _fetchStylistSchedule() async {
    setState(() => _loadingSchedule = true);
    try {
      final res = await AdminService.instance.getStylistSchedule();
      final raw = res['data'] ?? res;
      final list = raw is List ? raw : (raw is Map ? raw['stylists'] ?? [] : []);
      _stylistSlots = (list as List).map((s) {
        return _StylistSlot(
          s['name'] ?? '',
          List<String>.from(s['slots'] ?? []),
          (s['bookingCount'] ?? s['booking_count'] ?? 0) as int,
        );
      }).toList();
    } catch (_) {
      _stylistSlots = [];
    }
    if (mounted) setState(() => _loadingSchedule = false);
  }

  Future<void> _updateStatus(String bookingId, String newStatus) async {
    if (_actionInProgress) return;
    setState(() => _actionInProgress = true);
    try {
      await AdminService.instance.updateBookingStatus(bookingId, newStatus);
      await _fetchBookings();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('errorOccurred'))),
        );
      }
    }
    if (mounted) setState(() => _actionInProgress = false);
  }

  Future<void> _checkIn(String bookingId) async {
    if (_actionInProgress) return;
    setState(() => _actionInProgress = true);
    try {
      await AdminService.instance.checkInBooking(bookingId);
      await _fetchBookings();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('errorOccurred'))),
        );
      }
    }
    if (mounted) setState(() => _actionInProgress = false);
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
        _buildDaySelector(),
        _buildStylistAvailability(),
        _buildFilters(),
        _buildBookingList(),
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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr('adminBookings'), style: AppTheme.displayFont.copyWith(fontSize: 24, color: AppTheme.getTextPrimary(context))),
                  Text(tr('manageAppointments'),
                      style: TextStyle(fontSize: 12, color: AppTheme.getTextSecondary(context))),
                ],
              ),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminTimeSlots()),
                ).then((_) {
                  _fetchBookings();
                  _fetchStylistSchedule();
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.getGold(context),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.schedule, color: Colors.white, size: 16),
                      const SizedBox(width: 6),
                      Text(tr('manageSlots'), style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600,
                        color: Colors.white,
                      )),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }
    );
  }

  Widget _buildDaySelector() {
    // Week label: "Mar 24 – 30"
    final weekEnd = _weekStart.add(const Duration(days: 6));
    final weekLabel = '${_weekStart.day}/${_weekStart.month} – ${weekEnd.day}/${weekEnd.month}';
    return Column(
      children: [
        // Week navigation
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () => _changeWeek(-1),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.getBgSecondary(context),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.getBorder(context)),
                  ),
                  child: Icon(Icons.chevron_left, size: 18, color: AppTheme.getTextSecondary(context)),
                ),
              ),
              Text(weekLabel, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                  color: AppTheme.getTextPrimary(context))),
              GestureDetector(
                onTap: () => _changeWeek(1),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.getBgSecondary(context),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.getBorder(context)),
                  ),
                  child: Icon(Icons.chevron_right, size: 18, color: AppTheme.getTextSecondary(context)),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
      height: 68,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
        scrollDirection: Axis.horizontal,
        itemCount: _days.length,
        itemBuilder: (context, index) {
          final isSelected = _selectedDay == index;
          final parts = _days[index].split(' ');
          return GestureDetector(
            onTap: () {
              setState(() => _selectedDay = index);
              _fetchBookings();
              _fetchStylistSchedule();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 50,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.getGold(context) : AppTheme.getBgSecondary(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? AppTheme.getGold(context) : AppTheme.getBorder(context),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(parts[0], style: TextStyle(fontSize: 10,
                      color: isSelected ? Colors.white : AppTheme.getTextSecondary(context))),
                  const SizedBox(height: 2),
                  Text(parts[1], style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : AppTheme.getTextPrimary(context))),
                ],
              ),
            ),
          );
        },
      ),
    ),
      ],
    );
  }

  Widget _buildStylistAvailability() {
    final stylists = _stylistSlots;

    if (_loadingSchedule && stylists.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Builder(
      builder: (context) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
              child: Text(tr('stylistAvailability'), style: AppTheme.displayFont.copyWith(fontSize: 16, color: AppTheme.getTextPrimary(context))),
            ),
            ...stylists.map((s) => Container(
                  margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.getBgSecondary(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.getBorder(context)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(s.name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.getTextPrimary(context))),
                          Text('${s.bookingCount} ${tr('bookings').toLowerCase()}',
                              style: TextStyle(fontSize: 11, color: AppTheme.getTextSecondary(context))),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 24,
                        child: Row(
                          children: List.generate(9, (i) {
                            final hour = 9 + i;
                            final isBusy = s.slots.any((slot) {
                              final startHour = int.parse(slot.split('-')[0].split(':')[0]);
                              final endHour = int.parse(slot.split('-')[1].split(':')[0]);
                              return hour >= startHour && hour < endHour;
                            });
                            return Expanded(
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 1),
                                decoration: BoxDecoration(
                                  color: isBusy
                                      ? AppTheme.getGold(context)
                                      : AppTheme.getBgSecondary(context),
                                  borderRadius: BorderRadius.circular(4),
                                  border: isBusy ? null : Border.all(color: AppTheme.getBorder(context)),
                                ),
                                child: Center(
                                  child: Text('${hour}h',
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: isBusy ? Colors.white : AppTheme.getTextTertiary(context),
                                          fontWeight: FontWeight.w600)),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
                )),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Row(
                children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(
                    color: AppTheme.getGold(context), borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 6),
                  Text(tr('booked'), style: TextStyle(fontSize: 10, color: AppTheme.getTextSecondary(context))),
                  const SizedBox(width: 16),
                  Container(width: 10, height: 10, decoration: BoxDecoration(
                    color: AppTheme.getBgSecondary(context), borderRadius: BorderRadius.circular(2),
                    border: Border.all(color: AppTheme.getBorder(context)))),
                  const SizedBox(width: 6),
                  Text(tr('available'), style: TextStyle(fontSize: 10, color: AppTheme.getTextSecondary(context))),
                ],
              ),
            ),
          ],
        );
      }
    );
  }

  Widget _buildFilters() {
    final filters = [
      ('all', tr('all')),
      ('confirmed', tr('statusConfirmed')),
      ('checked_in', tr('statusCheckedIn')),
      ('pending', tr('statusPending')),
      ('cancelled', tr('statusCancelled')),
    ];

    return SizedBox(
      height: 50,
      child: Builder(
        builder: (context) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            scrollDirection: Axis.horizontal,
            children: filters.map((f) {
              final isSelected = _filter == f.$1;
              return GestureDetector(
                onTap: () => setState(() => _filter = f.$1),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.getGold(context) : AppTheme.getBgSecondary(context),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? AppTheme.getGold(context) : AppTheme.getBorder(context),
                    ),
                  ),
                  child: Text(f.$2, style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w500,
                    color: isSelected ? Colors.white : AppTheme.getTextSecondary(context))),
                ),
              );
            }).toList(),
          );
        }
      ),
    );
  }

  Widget _buildBookingList() {
    if (_loadingBookings) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final bookings = _filteredBookings;
    return Builder(
      builder: (context) {
        if (bookings.isEmpty) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: Center(child: Text(tr('noBookingsToday'), style: TextStyle(fontSize: 13, color: AppTheme.getTextSecondary(context)))),
          );
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Column(
            children: bookings.map((b) {
              final notes = b.raw['notes']?.toString() ?? '';
              final duration = b.raw['duration']?.toString() ?? '';
              final date = b.raw['date']?.toString() ?? '';
              return GestureDetector(
                onTap: () => _showBookingDetail(b),
                child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.getBgSecondary(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.getBorder(context)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top row: customer + status
                    Row(
                      children: [
                        Expanded(
                          child: Text(b.customer, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.getTextPrimary(context))),
                        ),
                        _buildStatusBadge(b.status),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Appointment details preview
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 13, color: AppTheme.getTextTertiary(context)),
                        const SizedBox(width: 6),
                        Text(b.time, style: TextStyle(fontSize: 12, color: AppTheme.getTextSecondary(context))),
                        if (duration.isNotEmpty) ...[
                          Text('  ·  $duration min', style: TextStyle(fontSize: 12, color: AppTheme.getTextTertiary(context))),
                        ],
                        if (date.isNotEmpty) ...[
                          Text('  ·  $date', style: TextStyle(fontSize: 12, color: AppTheme.getTextTertiary(context))),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.content_cut, size: 13, color: AppTheme.getTextTertiary(context)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(b.service, style: TextStyle(fontSize: 12, color: AppTheme.getTextSecondary(context))),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.person_outline, size: 13, color: AppTheme.getTextTertiary(context)),
                        const SizedBox(width: 6),
                        Text(b.stylist, style: TextStyle(fontSize: 12, color: AppTheme.getTextSecondary(context))),
                        const Spacer(),
                        Text('${b.price} FCFA', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.getGold(context))),
                      ],
                    ),
                    if (notes.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(notes, style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppTheme.getTextTertiary(context)),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                    // Action buttons
                    if (b.status == 'confirmed' || b.status == 'pending') ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          if (b.status == 'confirmed')
                            _actionButton(tr('checkIn'), AppTheme.accentGreen,
                                _actionInProgress ? null : () => _checkIn(b.id)),
                          if (b.status == 'pending') ...[
                            _actionButton(tr('confirm'), AppTheme.accentGreen,
                                _actionInProgress ? null : () => _updateStatus(b.id, 'confirmed')),
                            const SizedBox(width: 8),
                            _actionButton(tr('decline'), AppTheme.accentRed,
                                _actionInProgress ? null : () => _updateStatus(b.id, 'cancelled')),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              );
            }).toList(),
          ),
        );
      }
    );
  }

  Widget _actionButton(String label, Color color, VoidCallback? onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
          ),
        ),
      ),
    );
  }

  void _showBookingDetail(_AdminBooking b) {
    final raw = b.raw;
    // Extract all useful fields from raw booking data
    final date = raw['date']?.toString() ?? '';
    final notes = raw['notes']?.toString() ?? '';
    final duration = raw['duration']?.toString();
    final styleName = raw['style']?['name']?.toString() ?? raw['styleName']?.toString() ?? b.service;
    final customerEmail = raw['customerEmail'] ?? raw['customer_email'] ?? '';
    final customerPhone = raw['customerPhone'] ?? raw['customer_phone'] ?? '';
    final createdAt = raw['createdAt'] ?? raw['created_at'] ?? '';

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.getBgSecondary(context),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 36, height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.getBorder(ctx),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // Header: title + status
                Row(
                  children: [
                    Expanded(
                      child: Text(tr('bookingDetails'),
                          style: AppTheme.displayFont.copyWith(fontSize: 20, color: AppTheme.getTextPrimary(ctx))),
                    ),
                    _buildStatusBadge(b.status),
                  ],
                ),
                const SizedBox(height: 16),

                // Customer info
                _DetailSection(
                  icon: Icons.person_outline,
                  title: tr('customer'),
                  children: [
                    _DetailRow(label: tr('name'), value: b.customer),
                    if (customerEmail.isNotEmpty)
                      _DetailRow(label: tr('email'), value: customerEmail),
                    if (customerPhone.isNotEmpty)
                      _DetailRow(label: tr('phone'), value: customerPhone),
                  ],
                ),
                const SizedBox(height: 12),

                // Service info
                _DetailSection(
                  icon: Icons.content_cut,
                  title: tr('serviceDetails'),
                  children: [
                    _DetailRow(label: tr('style'), value: styleName),
                    _DetailRow(label: tr('date'), value: date),
                    _DetailRow(label: tr('time'), value: b.time),
                    if (duration != null && duration.isNotEmpty)
                      _DetailRow(label: tr('duration'), value: '$duration min'),
                    _DetailRow(label: tr('price'), value: '${b.price} FCFA', isGold: true),
                    if (b.stylist.isNotEmpty)
                      _DetailRow(label: tr('withStylist'), value: b.stylist),
                  ],
                ),

                if (notes.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _DetailSection(
                    icon: Icons.note_outlined,
                    title: tr('notes'),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(notes,
                            style: TextStyle(fontSize: 13, color: AppTheme.getTextSecondary(ctx))),
                      ),
                    ],
                  ),
                ],

                if (createdAt.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${tr('bookedOn')} ${_formatDateTime(createdAt)}',
                      style: TextStyle(fontSize: 11, color: AppTheme.getTextTertiary(ctx)),
                    ),
                  ),
                ],

                // Action buttons
                if (b.status == 'pending' || b.status == 'confirmed') ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      if (b.status == 'confirmed')
                        _actionButton(tr('checkIn'), AppTheme.accentGreen,
                            () { Navigator.pop(ctx); _checkIn(b.id); }),
                      if (b.status == 'pending') ...[
                        _actionButton(tr('confirm'), AppTheme.accentGreen,
                            () { Navigator.pop(ctx); _updateStatus(b.id, 'confirmed'); }),
                        const SizedBox(width: 10),
                        _actionButton(tr('decline'), AppTheme.accentRed,
                            () { Navigator.pop(ctx); _updateStatus(b.id, 'cancelled'); }),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDateTime(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }

  Widget _buildStatusBadge(String status) {
    final color = switch (status) {
      'confirmed' => AppTheme.accentBlue,
      'checked_in' => AppTheme.accentGreen,
      'pending' => const Color(0xFFE5A100),
      'cancelled' => AppTheme.accentRed,
      _ => AppTheme.textTertiary,
    };
    final label = switch (status) {
      'confirmed' => tr('statusConfirmed'),
      'checked_in' => tr('statusCheckedIn'),
      'pending' => tr('statusPending'),
      'cancelled' => tr('statusCancelled'),
      _ => status,
    };

    return Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color));
  }
}

class _AdminBooking {
  final String id, customer, service, time, stylist, status, price;
  final Map<String, dynamic> raw;
  const _AdminBooking(this.id, this.customer, this.service, this.time, this.stylist, this.status, this.price, this.raw);
}

class _StylistSlot {
  final String name;
  final List<String> slots;
  final int bookingCount;
  const _StylistSlot(this.name, this.slots, this.bookingCount);
}

class _DetailSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<Widget> children;
  const _DetailSection({required this.icon, required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.getBgSecondary(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.getBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 16, color: AppTheme.getGold(context)),
            const SizedBox(width: 8),
            Text(title, style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600,
              color: AppTheme.getTextTertiary(context), letterSpacing: 0.3)),
          ]),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label, value;
  final bool isGold;
  const _DetailRow({required this.label, required this.value, this.isGold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: AppTheme.getTextSecondary(context))),
          Flexible(
            child: Text(value,
              style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600,
                color: isGold ? AppTheme.getGold(context) : AppTheme.getTextPrimary(context)),
              textAlign: TextAlign.end, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}
