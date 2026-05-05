import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import '../../l10n/app_locale.dart';
import '../../services/admin_service.dart';

class AdminTimeSlots extends StatefulWidget {
  const AdminTimeSlots({super.key});

  @override
  State<AdminTimeSlots> createState() => _AdminTimeSlotsState();
}

class _AdminTimeSlotsState extends State<AdminTimeSlots> {
  int _selectedDay = 0; // 0=Mon..6=Sun
  bool _loading = true;
  bool _saving = false;
  List<_TimeSlot> _slots = [];
  final Map<int, int> _dayCounts = {};

  // Bulk setup form state
  bool _showBulkForm = false;
  final Set<int> _bulkDays = {};
  TimeOfDay _bulkStart = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _bulkEnd = const TimeOfDay(hour: 18, minute: 0);
  int _bulkMax = 3;
  int _bulkInterval = 30; // minutes

  static const _dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _dayLabelsFr = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
  static const _intervals = [15, 30, 60];

  /// Maps UI index (0=Mon..6=Sun) to backend dayOfWeek (0=Sun..6=Sat)
  int _toDayOfWeek(int uiIndex) => uiIndex == 6 ? 0 : uiIndex + 1;

  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  /// How many slots will be generated from the form
  int get _previewSlotCount {
    final startMin = _bulkStart.hour * 60 + _bulkStart.minute;
    final endMin = _bulkEnd.hour * 60 + _bulkEnd.minute;
    if (endMin <= startMin || _bulkInterval <= 0) return 0;
    return ((endMin - startMin) / _bulkInterval).floor() + 1;
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDay = (now.weekday - 1).clamp(0, 6);
    _fetchSlots();
    _fetchAllDayCounts();
  }

  /// Extract slot list from API response.
  /// API returns grouped: { "slots": { "1": [...], "2": [...] } }
  /// or filtered: { "slots": { "1": [...] } } when ?dayOfWeek=1
  List _extractSlots(Map<String, dynamic> res, int dayOfWeek) {
    final raw = res['data'] ?? res;
    final slotsField = raw is Map ? (raw['slots'] ?? raw['timeSlots']) : raw;

    // Grouped map: { "1": [...], "2": [...] }
    if (slotsField is Map) {
      final dayKey = dayOfWeek.toString();
      final daySlots = slotsField[dayKey];
      if (daySlots is List) return daySlots;
      // If filtered, might only have one key — return first list found
      for (final v in slotsField.values) {
        if (v is List) return v;
      }
      return [];
    }
    // Flat list (fallback)
    if (slotsField is List) return slotsField;
    return [];
  }

  Future<void> _fetchAllDayCounts() async {
    // Fetch all days at once (no filter) to get counts
    try {
      final res = await AdminService.instance.getTimeSlots();
      final raw = res['data'] ?? res;
      final slotsField = raw is Map ? (raw['slots'] ?? raw['timeSlots']) : null;

      if (slotsField is Map) {
        // Grouped: { "0": [...], "1": [...], ... }
        for (int ui = 0; ui < 7; ui++) {
          final dow = _toDayOfWeek(ui);
          final daySlots = slotsField[dow.toString()];
          if (mounted) {
            setState(() => _dayCounts[ui] = daySlots is List ? daySlots.length : 0);
          }
        }
      }
    } catch (_) {
      for (int ui = 0; ui < 7; ui++) {
        if (mounted) setState(() => _dayCounts[ui] = 0);
      }
    }
  }

  Future<void> _fetchSlots() async {
    setState(() => _loading = true);
    try {
      final dow = _toDayOfWeek(_selectedDay);
      final res = await AdminService.instance
          .getTimeSlots(query: {'dayOfWeek': dow.toString()});
      final list = _extractSlots(res, dow);
      _slots = list.map((s) => _TimeSlot(
            id: s['id']?.toString() ?? '',
            time: s['time'] ?? '',
            maxBookings: (s['maxBookings'] ?? s['max_bookings'] ?? 1) as int,
            currentBookings:
                (s['currentBookings'] ?? s['current_bookings'] ?? s['booked'] ?? 0) as int,
          )).toList()
        ..sort((a, b) => a.time.compareTo(b.time));
      _dayCounts[_selectedDay] = _slots.length;
    } catch (_) {
      _slots = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _saveBulk() async {
    if (_bulkDays.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      await AdminService.instance.createTimeSlotsBulk(
        days: _bulkDays.map(_toDayOfWeek).toList(),
        startTime: _fmtTime(_bulkStart),
        endTime: _fmtTime(_bulkEnd),
        maxBookings: _bulkMax,
        slotInterval: _bulkInterval,
      );
      _showBulkForm = false;
      _bulkDays.clear();
      await _fetchSlots();
      _fetchAllDayCounts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('slotsSaved'))),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('errorOccurred'))),
        );
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _updateSlotCapacity(_TimeSlot slot, int newMax) async {
    try {
      await AdminService.instance.updateTimeSlot(slot.id, {'maxBookings': newMax});
      await _fetchSlots();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('errorOccurred'))),
        );
      }
    }
  }

  Future<void> _deleteSlot(_TimeSlot slot) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.getBgSecondary(ctx),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(tr('deleteSlotTitle'),
            style: TextStyle(color: AppTheme.getTextPrimary(ctx))),
        content: Text('${tr('deleteSlotMsg')} ${slot.time}?',
            style: TextStyle(color: AppTheme.getTextSecondary(ctx))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('no'),
                style: TextStyle(color: AppTheme.getTextSecondary(ctx))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                Text(tr('delete'), style: const TextStyle(color: AppTheme.accentRed)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await AdminService.instance.deleteTimeSlot(slot.id);
      await _fetchSlots();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('errorOccurred'))),
        );
      }
    }
  }

  Future<void> _pickBulkTime({required bool isStart}) async {
    final initial = isStart ? _bulkStart : _bulkEnd;
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(
                primary: AppTheme.getGold(ctx),
                onPrimary: AppTheme.getBgPrimary(ctx),
                surface: AppTheme.getBgSecondary(ctx),
                onSurface: AppTheme.getTextPrimary(ctx),
              ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _bulkStart = picked;
        } else {
          _bulkEnd = picked;
        }
      });
    }
  }

  // ═══════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.getBgPrimary(context),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildDaySelector(),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildBody(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.getBgGlass(context),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.getBorder(context)),
              ),
              child: Icon(Icons.arrow_back_ios_new,
                  size: 16, color: AppTheme.getTextPrimary(context)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr('timeSlots'),
                    style: AppTheme.displayFont.copyWith(fontSize: 22)),
                Text(tr('manageSlotsDesc'),
                    style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.getTextSecondary(context))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDaySelector() {
    final isFr = AppLocale.instance.isFrench;
    final labels = isFr ? _dayLabelsFr : _dayLabels;
    return SizedBox(
      height: 76,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        scrollDirection: Axis.horizontal,
        itemCount: 7,
        itemBuilder: (context, index) {
          final isSelected = _selectedDay == index;
          final count = _dayCounts[index];
          final hasSlots = count != null && count > 0;
          return GestureDetector(
            onTap: () {
              setState(() => _selectedDay = index);
              _fetchSlots();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 52,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.getGoldDim(context)
                    : AppTheme.getBgGlass(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? AppTheme.getGold(context).withValues(alpha: 0.4)
                      : AppTheme.getBorder(context),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(labels[index],
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? AppTheme.getGold(context)
                            : AppTheme.getTextSecondary(context),
                      )),
                  const SizedBox(height: 4),
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: hasSlots
                          ? (isSelected
                              ? AppTheme.getGold(context).withValues(alpha: 0.2)
                              : AppTheme.accentGreen.withValues(alpha: 0.15))
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: hasSlots
                          ? Text('$count',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: isSelected
                                    ? AppTheme.getGold(context)
                                    : AppTheme.accentGreen,
                              ))
                          : Container(
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                color: AppTheme.getTextTertiary(context),
                                shape: BoxShape.circle,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(),
          const SizedBox(height: 12),
          if (_slots.isEmpty && !_showBulkForm) _buildEmptyState(),
          if (_slots.isNotEmpty) ...[
            _buildTimeline(),
            const SizedBox(height: 16),
            _buildSlotGrid(),
          ],
          if (_showBulkForm) ...[
            const SizedBox(height: 20),
            _buildBulkForm(),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${_slots.length} ${tr('slotsConfigured')}',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.getTextPrimary(context))),
            if (_slots.isNotEmpty)
              Text('${_slots.first.time} – ${_slots.last.time}',
                  style: TextStyle(
                      fontSize: 11, color: AppTheme.getTextTertiary(context))),
          ],
        ),
        GestureDetector(
          onTap: () {
            setState(() {
              _showBulkForm = !_showBulkForm;
              if (_showBulkForm) {
                // Pre-select current day
                _bulkDays.clear();
                _bulkDays.add(_selectedDay);
              }
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: _showBulkForm
                  ? null
                  : LinearGradient(
                      colors: [AppTheme.getGold(context), AppTheme.teal]),
              color:
                  _showBulkForm ? AppTheme.accentRed.withValues(alpha: 0.1) : null,
              borderRadius: BorderRadius.circular(10),
              border: _showBulkForm
                  ? Border.all(color: AppTheme.accentRed.withValues(alpha: 0.2))
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_showBulkForm ? Icons.close : Icons.add,
                    size: 16,
                    color: _showBulkForm
                        ? AppTheme.accentRed
                        : AppTheme.getBgPrimary(context)),
                const SizedBox(width: 6),
                Text(_showBulkForm ? tr('cancel') : tr('addSlots'),
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _showBulkForm
                            ? AppTheme.accentRed
                            : AppTheme.getBgPrimary(context))),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        color: AppTheme.getBgGlass(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.getBorder(context)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.getGoldDim(context),
              shape: BoxShape.circle,
            ),
            child:
                Icon(Icons.schedule, size: 32, color: AppTheme.getGold(context)),
          ),
          const SizedBox(height: 16),
          Text(tr('noSlotsTitle'),
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.getTextPrimary(context))),
          const SizedBox(height: 6),
          Text(tr('noSlotsSub'),
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13, color: AppTheme.getTextSecondary(context))),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () {
              setState(() {
                _showBulkForm = true;
                _bulkDays.clear();
                _bulkDays.add(_selectedDay);
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [AppTheme.getGold(context), AppTheme.teal]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(tr('setupSchedule'),
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.getBgPrimary(context))),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════
  //  BULK SETUP FORM
  // ═══════════════════════════════════════

  Widget _buildBulkForm() {
    final isFr = AppLocale.instance.isFrench;
    final labels = isFr ? _dayLabelsFr : _dayLabels;
    final slotCount = _previewSlotCount;
    final dayCount = _bulkDays.length;
    final totalSlots = slotCount * dayCount;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.getGoldDim(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.getGold(context).withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Row(
            children: [
              Icon(Icons.bolt, size: 18, color: AppTheme.getGold(context)),
              const SizedBox(width: 8),
              Text(tr('bulkSetup'),
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.getTextPrimary(context))),
            ],
          ),
          const SizedBox(height: 4),
          Text(tr('bulkSetupDesc'),
              style: TextStyle(
                  fontSize: 11, color: AppTheme.getTextSecondary(context))),
          const SizedBox(height: 16),

          // ── 1. Day picker ──
          Text(tr('selectDays'),
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.getTextTertiary(context),
                  letterSpacing: 0.5)),
          const SizedBox(height: 8),
          Row(
            children: List.generate(7, (i) {
              final selected = _bulkDays.contains(i);
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      if (selected) {
                        _bulkDays.remove(i);
                      } else {
                        _bulkDays.add(i);
                      }
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: EdgeInsets.only(right: i < 6 ? 6 : 0),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppTheme.getGold(context).withValues(alpha: 0.15)
                          : AppTheme.getBgGlass(context),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: selected
                            ? AppTheme.getGold(context).withValues(alpha: 0.4)
                            : AppTheme.getBorder(context),
                      ),
                    ),
                    child: Center(
                      child: Text(labels[i].substring(0, 2),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: selected
                                ? AppTheme.getGold(context)
                                : AppTheme.getTextSecondary(context),
                          )),
                    ),
                  ),
                ),
              );
            }),
          ),
          // Quick select helpers
          const SizedBox(height: 6),
          Row(
            children: [
              _QuickDayChip(
                label: tr('weekdays'),
                onTap: () => setState(() {
                  _bulkDays.clear();
                  _bulkDays.addAll([0, 1, 2, 3, 4]); // Mon-Fri
                }),
              ),
              const SizedBox(width: 6),
              _QuickDayChip(
                label: tr('weekend'),
                onTap: () => setState(() {
                  _bulkDays.clear();
                  _bulkDays.addAll([5, 6]); // Sat-Sun
                }),
              ),
              const SizedBox(width: 6),
              _QuickDayChip(
                label: tr('allDays'),
                onTap: () => setState(() {
                  _bulkDays.clear();
                  _bulkDays.addAll([0, 1, 2, 3, 4, 5, 6]);
                }),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // ── 2. Time range ──
          Text(tr('timeRange'),
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.getTextTertiary(context),
                  letterSpacing: 0.5)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _TimePickerButton(
                label: tr('from'),
                time: _fmtTime(_bulkStart),
                onTap: () => _pickBulkTime(isStart: true),
              )),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Icon(Icons.arrow_forward,
                    size: 16, color: AppTheme.getTextTertiary(context)),
              ),
              Expanded(child: _TimePickerButton(
                label: tr('to'),
                time: _fmtTime(_bulkEnd),
                onTap: () => _pickBulkTime(isStart: false),
              )),
            ],
          ),
          const SizedBox(height: 18),

          // ── 3. Interval ──
          Text(tr('interval'),
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.getTextTertiary(context),
                  letterSpacing: 0.5)),
          const SizedBox(height: 8),
          Row(
            children: _intervals.map((mins) {
              final selected = _bulkInterval == mins;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _bulkInterval = mins),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: EdgeInsets.only(right: mins != _intervals.last ? 8 : 0),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppTheme.getGold(context).withValues(alpha: 0.15)
                          : AppTheme.getBgGlass(context),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected
                            ? AppTheme.getGold(context).withValues(alpha: 0.4)
                            : AppTheme.getBorder(context),
                      ),
                    ),
                    child: Center(
                      child: Text('$mins min',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: selected
                                ? AppTheme.getGold(context)
                                : AppTheme.getTextSecondary(context),
                          )),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),

          // ── 4. Max bookings ──
          Text(tr('maxBookingsPerSlot'),
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.getTextTertiary(context),
                  letterSpacing: 0.5)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.getBgGlass(context),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.getBorder(context)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: _bulkMax > 1 ? () => setState(() => _bulkMax--) : null,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.getBgGlassStrong(context),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.remove,
                        size: 20,
                        color: _bulkMax > 1
                            ? AppTheme.getTextPrimary(context)
                            : AppTheme.getTextTertiary(context)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      Text('$_bulkMax',
                          style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.getGold(context))),
                      Text(tr('peoplePerSlot'),
                          style: TextStyle(
                              fontSize: 10,
                              color: AppTheme.getTextSecondary(context))),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _bulkMax++),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.getBgGlassStrong(context),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.add,
                        size: 20, color: AppTheme.getTextPrimary(context)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // ── Preview + Save ──
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.getBgGlass(context),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.getBorder(context)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline,
                    size: 16, color: AppTheme.getTextTertiary(context)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$slotCount ${tr('slotsPerDay')} × $dayCount ${tr('daysSelected')} = $totalSlots ${tr('totalSlotsCreated')}',
                    style: TextStyle(
                        fontSize: 12, color: AppTheme.getTextSecondary(context)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: (_saving || _bulkDays.isEmpty || _previewSlotCount == 0)
                ? null
                : _saveBulk,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                gradient: (_bulkDays.isEmpty || _previewSlotCount == 0)
                    ? null
                    : LinearGradient(
                        colors: [AppTheme.getGold(context), AppTheme.teal]),
                color: (_bulkDays.isEmpty || _previewSlotCount == 0)
                    ? AppTheme.getBgGlassStrong(context)
                    : null,
                borderRadius: BorderRadius.circular(12),
                boxShadow: (_bulkDays.isNotEmpty && _previewSlotCount > 0)
                    ? [
                        BoxShadow(
                          color: AppTheme.teal.withValues(alpha: 0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        )
                      ]
                    : null,
              ),
              child: _saving
                  ? Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(
                              AppTheme.getBgPrimary(context)),
                        ),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check,
                            size: 18,
                            color: (_bulkDays.isEmpty || _previewSlotCount == 0)
                                ? AppTheme.getTextTertiary(context)
                                : AppTheme.getBgPrimary(context)),
                        const SizedBox(width: 8),
                        Text(
                          '${tr('createSlots')} ($totalSlots)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: (_bulkDays.isEmpty || _previewSlotCount == 0)
                                ? AppTheme.getTextTertiary(context)
                                : AppTheme.getBgPrimary(context),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════
  //  TIMELINE + SLOT CARDS
  // ═══════════════════════════════════════

  Widget _buildTimeline() {
    const startHour = 7;
    const totalHours = 14;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.getBgGlass(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.getBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr('dayOverview'),
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.getTextTertiary(context),
                  letterSpacing: 0.5)),
          const SizedBox(height: 10),
          SizedBox(
            height: 28,
            child: LayoutBuilder(builder: (context, constraints) {
              final totalWidth = constraints.maxWidth;
              return Stack(
                children: [
                  Container(
                    height: 28,
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white.withValues(alpha: 0.03)
                          : Colors.black.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  ..._slots.map((slot) {
                    final parts = slot.time.split(':');
                    final hour = int.parse(parts[0]) + int.parse(parts[1]) / 60;
                    final fraction =
                        ((hour - startHour) / totalHours).clamp(0.0, 1.0);
                    final left = fraction * (totalWidth - 6);
                    final fillRatio = slot.maxBookings > 0
                        ? slot.currentBookings / slot.maxBookings
                        : 0.0;
                    final color = fillRatio >= 1.0
                        ? AppTheme.accentRed
                        : fillRatio >= 0.7
                            ? const Color(0xFFE5A100)
                            : AppTheme.accentGreen;
                    return Positioned(
                      left: left,
                      top: 2,
                      child: Container(
                        width: 6,
                        height: 24,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    );
                  }),
                ],
              );
            }),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${startHour}h',
                  style: TextStyle(
                      fontSize: 9, color: AppTheme.getTextTertiary(context))),
              Text('12h',
                  style: TextStyle(
                      fontSize: 9, color: AppTheme.getTextTertiary(context))),
              Text('${startHour + totalHours}h',
                  style: TextStyle(
                      fontSize: 9, color: AppTheme.getTextTertiary(context))),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _legendDot(AppTheme.accentGreen, tr('available')),
              const SizedBox(width: 14),
              _legendDot(const Color(0xFFE5A100), tr('almostFull')),
              const SizedBox(width: 14),
              _legendDot(AppTheme.accentRed, tr('full')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(
                fontSize: 10, color: AppTheme.getTextSecondary(context))),
      ],
    );
  }

  Widget _buildSlotGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _slots.map((slot) => _buildSlotCard(slot)).toList(),
    );
  }

  Widget _buildSlotCard(_TimeSlot slot) {
    final fillRatio =
        slot.maxBookings > 0 ? slot.currentBookings / slot.maxBookings : 0.0;
    final statusColor = fillRatio >= 1.0
        ? AppTheme.accentRed
        : fillRatio >= 0.7
            ? const Color(0xFFE5A100)
            : AppTheme.accentGreen;
    final spotsLeft = slot.maxBookings - slot.currentBookings;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.getBgGlass(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.getBorder(context)),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.getGoldDim(context),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(slot.time,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.getGold(context),
                    fontFamily: 'JetBrains Mono',
                  )),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text('${slot.currentBookings}/${slot.maxBookings}',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.getTextPrimary(context))),
                  const SizedBox(width: 6),
                  Text(tr('bookings').toLowerCase(),
                      style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.getTextSecondary(context))),
                ]),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: SizedBox(
                    height: 6,
                    child: LinearProgressIndicator(
                      value: fillRatio.clamp(0.0, 1.0),
                      backgroundColor:
                          Theme.of(context).brightness == Brightness.dark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.black.withValues(alpha: 0.05),
                      valueColor: AlwaysStoppedAnimation(
                          statusColor.withValues(alpha: 0.7)),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  spotsLeft > 0
                      ? '$spotsLeft ${tr('spotsLeft')}'
                      : tr('full'),
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: statusColor),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _showEditCapacity(slot),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.accentBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.edit_outlined,
                  size: 18, color: AppTheme.accentBlue),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _deleteSlot(slot),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.accentRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.delete_outline,
                  size: 18, color: AppTheme.accentRed),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditCapacity(_TimeSlot slot) {
    final controller = TextEditingController(text: slot.maxBookings.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.getBgSecondary(ctx),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('${tr('editCapacity')} – ${slot.time}',
            style:
                TextStyle(fontSize: 16, color: AppTheme.getTextPrimary(ctx))),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          autofocus: true,
          style: TextStyle(
              color: AppTheme.getTextPrimary(ctx),
              fontSize: 18,
              fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            labelText: tr('maxBookings'),
            labelStyle: TextStyle(color: AppTheme.getTextSecondary(ctx)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppTheme.getBorder(ctx)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppTheme.getGold(ctx)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr('cancel'),
                style: TextStyle(color: AppTheme.getTextSecondary(ctx))),
          ),
          TextButton(
            onPressed: () {
              final val = int.tryParse(controller.text);
              if (val != null && val > 0) {
                Navigator.pop(ctx);
                _updateSlotCapacity(slot, val);
              }
            },
            child:
                Text(tr('save'), style: TextStyle(color: AppTheme.getGold(ctx))),
          ),
        ],
      ),
    );
  }
}

// ─── Helper widgets ───

class _TimePickerButton extends StatelessWidget {
  final String label;
  final String time;
  final VoidCallback onTap;

  const _TimePickerButton({
    required this.label,
    required this.time,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: AppTheme.getBgGlass(context),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.getBorder(context)),
        ),
        child: Row(
          children: [
            Icon(Icons.schedule, size: 16, color: AppTheme.getGold(context)),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 10,
                        color: AppTheme.getTextTertiary(context))),
                Text(time,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.getTextPrimary(context))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickDayChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickDayChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppTheme.getBgGlass(context),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppTheme.getBorder(context)),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 10,
                color: AppTheme.getTextSecondary(context),
                fontWeight: FontWeight.w500)),
      ),
    );
  }
}

// ─── Models ───

class _TimeSlot {
  final String id;
  final String time;
  final int maxBookings;
  final int currentBookings;

  const _TimeSlot({
    required this.id,
    required this.time,
    required this.maxBookings,
    required this.currentBookings,
  });
}
