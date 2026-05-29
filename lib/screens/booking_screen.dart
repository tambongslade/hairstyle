import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../l10n/app_locale.dart';
import '../widgets/gold_button.dart';
import '../widgets/glass_card.dart';
import '../widgets/app_toast.dart';
import '../services/api_client.dart';
import '../services/customer_service.dart';
import '../services/public_service.dart';
import '../services/storage_service.dart';
import 'guest/guest_info_sheet.dart';
import 'salon_screen.dart';

class BookingScreen extends StatefulWidget {
  /// When true, the screen uses the unauthenticated /public/salons endpoints
  /// and collects the guest's name/phone/email instead of relying on an
  /// account.
  final bool guestMode;
  const BookingScreen({super.key, this.guestMode = false});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  bool _isBooking = false;
  int _currentStep = 0; // 0=category, 1=style, 2=date/time, 3=confirm

  bool get _guest => widget.guestMode;

  // Selections
  String _selectedGender = 'women';
  String? _selectedCategory;
  Map<String, dynamic>? _selectedStyle;
  int _selectedDateIndex = 0;
  int _selectedTimeIndex = -1;

  // Styles
  List<Map<String, dynamic>> _allStyles = [];
  List<Map<String, dynamic>> _filteredStyles = [];
  bool _loadingStyles = true;
  String? _stylesError;

  // Bookings
  List<Map<String, dynamic>> _myBookings = [];
  bool _loadingBookings = true;

  // Salon-based availability
  List<Map<String, dynamic>> _availableDates = [];
  List<Map<String, dynamic>> _timeSlots = [];
  bool _loadingDates = false;
  bool _loadingTimes = false;

  bool _submitting = false;

  String? get _salonId => StorageService.instance.selectedSalonId;
  bool get _hasSalon => StorageService.instance.hasSalonSelected;

  @override
  void initState() {
    super.initState();
    if (_hasSalon) _fetchInitialData();
    if (_guest) {
      // Guest mode skips the bookings list — drop straight into the flow.
      _isBooking = true;
    }
  }

  Future<void> _fetchInitialData() async {
    _fetchStyles();
    if (!_guest) _fetchMyBookings();
  }

  // ── Styles ──
  Future<void> _fetchStyles() async {
    setState(() { _loadingStyles = true; _stylesError = null; });
    try {
      final allItems = <Map<String, dynamic>>[];
      if (_guest) {
        // Guest mode: pull styles from the salon catalogue (no auth, no paging).
        final salonId = _salonId;
        if (salonId == null) {
          if (mounted) setState(() { _loadingStyles = false; });
          return;
        }
        final res = await PublicService.instance.getCatalogue(salonId);
        final data = (res['data'] ?? res) as Map<String, dynamic>;
        final raw = data['styles'] ?? data['hairstyles'] ?? [];
        if (raw is List) {
          allItems.addAll(List<Map<String, dynamic>>.from(raw.whereType<Map>()));
        }
      } else {
        int page = 1;
        bool hasMore = true;
        while (hasMore) {
          final res = await CustomerService.instance.getStyles(query: {'page': page.toString(), 'limit': '50'});
          final raw = res['items'] ?? res['styles'] ?? res['data'] ?? res;
          final data = raw is List ? raw : (raw is Map ? (raw['items'] ?? raw['styles'] ?? []) : []);
          if (data is List && data.isNotEmpty) {
            allItems.addAll(List<Map<String, dynamic>>.from(data));
            final total = res['totalPages'] ?? res['total'];
            hasMore = total is int ? page < total : data.length >= 50;
            page++;
          } else {
            hasMore = false;
          }
        }
      }
      if (mounted) setState(() { _allStyles = allItems; _loadingStyles = false; });
    } catch (_) {
      if (mounted) setState(() { _loadingStyles = false; _stylesError = tr('errorLoadingStyles'); });
    }
  }

  void _filterStyles() {
    _filteredStyles = _allStyles.where((s) {
      final g = s['gender']?.toString();
      final matchGender = g == _selectedGender;
      final matchCategory = _selectedCategory == null || s['category']?.toString() == _selectedCategory;
      return matchGender && matchCategory;
    }).toList();
  }

  List<String> get _availableCategories {
    return _allStyles
        .where((s) => s['gender']?.toString() == _selectedGender)
        .map((s) => s['category']?.toString() ?? '')
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList();
  }

  // ── Bookings ──
  Future<void> _fetchMyBookings() async {
    setState(() => _loadingBookings = true);
    try {
      final res = await CustomerService.instance.getMyBookings();
      final raw = res['data'] ?? res['items'] ?? res['bookings'] ?? res;
      final data = raw is List ? raw : (raw is Map ? (raw['data'] ?? raw['items'] ?? []) : []);
      if (data is List && mounted) {
        setState(() { _myBookings = List<Map<String, dynamic>>.from(data); _loadingBookings = false; });
      } else {
        if (mounted) setState(() => _loadingBookings = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loadingBookings = false);
    }
  }

  // ── Salon-based availability ──
  Future<void> _fetchAvailableDates() async {
    if (_salonId == null) return;
    setState(() { _loadingDates = true; _availableDates = []; _timeSlots = []; _selectedDateIndex = 0; _selectedTimeIndex = -1; });
    try {
      final res = _guest
          ? await PublicService.instance.getAvailableDates(_salonId!)
          : await CustomerService.instance.getAvailableDates(salonId: _salonId!);
      final data = res['data'] ?? res;
      final list = data is List ? data : (data is Map ? (data['dates'] ?? []) : []);
      if (list is List && mounted) {
        final dates = List<Map<String, dynamic>>.from(list.map((d) => d is Map ? d : {'date': d.toString()}));
        // Auto-select first open date
        int firstOpen = dates.indexWhere((d) => d['isOpen'] == true);
        if (firstOpen < 0) firstOpen = 0;
        setState(() { _availableDates = dates; _selectedDateIndex = firstOpen; _loadingDates = false; });
        if (dates.isNotEmpty) _fetchAvailableTimes();
      } else {
        if (mounted) setState(() => _loadingDates = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loadingDates = false);
    }
  }

  Future<void> _fetchAvailableTimes() async {
    if (_salonId == null || _availableDates.isEmpty) return;
    final dateStr = _availableDates[_selectedDateIndex]['date']?.toString() ?? '';
    if (dateStr.isEmpty) return;

    setState(() { _loadingTimes = true; _timeSlots = []; _selectedTimeIndex = -1; });
    try {
      final res = _guest
          ? await PublicService.instance.getAvailableTimes(_salonId!, date: dateStr)
          : await CustomerService.instance.getAvailableTimes(salonId: _salonId!, date: dateStr);
      final data = res['data'] ?? res;
      final isOpen = data['isOpen'] ?? true;
      final slots = data['slots'] as List? ?? [];

      if (mounted) {
        if (isOpen == false) {
          setState(() { _timeSlots = []; _loadingTimes = false; });
        } else {
          final slotList = List<Map<String, dynamic>>.from(slots.map((s) => s is Map ? s : {'time': s.toString(), 'available': true}));
          // Auto-select first available
          int firstAvail = slotList.indexWhere((s) => s['available'] == true);
          setState(() { _timeSlots = slotList; _selectedTimeIndex = firstAvail; _loadingTimes = false; });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _loadingTimes = false);
    }
  }

  String get _selectedDateStr {
    if (_availableDates.isEmpty || _selectedDateIndex >= _availableDates.length) return '';
    return _availableDates[_selectedDateIndex]['date']?.toString() ?? '';
  }

  String get _selectedTimeStr {
    if (_timeSlots.isEmpty || _selectedTimeIndex < 0 || _selectedTimeIndex >= _timeSlots.length) return '';
    return _timeSlots[_selectedTimeIndex]['time']?.toString() ?? '';
  }

  String _fmtDate(String dateStr) {
    try { return DateFormat('E, MMM d').format(DateTime.parse(dateStr)); } catch (_) { return dateStr; }
  }

  // ── Flow ──
  void _startBooking() {
    setState(() { _isBooking = true; _currentStep = 0; _selectedCategory = null; _selectedStyle = null; _filteredStyles = []; _selectedDateIndex = 0; _selectedTimeIndex = -1; _availableDates = []; _timeSlots = []; });
    if (_allStyles.isEmpty && !_loadingStyles) _fetchStyles();
  }

  void _cancelBookingFlow() {
    if (_guest) {
      // Guest mode has no landing list — go back to step 0 instead of leaving.
      setState(() => _currentStep = 0);
      return;
    }
    setState(() { _isBooking = false; _currentStep = 0; });
  }

  void _nextStep() {
    if (_currentStep == 1) _fetchAvailableDates();
    if (_currentStep < 3) setState(() => _currentStep++);
  }

  void _prevStep() {
    if (_currentStep > 0) { setState(() => _currentStep--); } else { _cancelBookingFlow(); }
  }

  Future<void> _confirmBooking() async {
    if (_guest && !StorageService.instance.hasGuestProfile) {
      final saved = await GuestInfoSheet.show(context);
      if (saved != true) return;
    }
    setState(() => _submitting = true);
    try {
      if (_guest) {
        final s = StorageService.instance;
        await PublicService.instance.createGuestBooking(
          _salonId!,
          clientName: s.guestName ?? '',
          clientPhone: s.guestPhone ?? '',
          clientEmail: s.guestEmail ?? '',
          date: _selectedDateStr,
          time: _selectedTimeStr,
          styleId: _selectedStyle?['id']?.toString(),
          notes: _selectedStyle?['notes']?.toString(),
        );
      } else {
        await CustomerService.instance.createBooking({
          'salonId': _salonId,
          'date': _selectedDateStr,
          'time': _selectedTimeStr,
          if (_selectedStyle != null) 'styleId': _selectedStyle!['id']?.toString() ?? '',
          if (_selectedStyle?['notes'] != null) 'notes': _selectedStyle!['notes'],
        });
      }
      if (!mounted) return;
      AppToast.show(context, message: tr('appointmentConfirmed'), type: ToastType.success);
      Future.delayed(const Duration(seconds: 1), () {
        if (!mounted) return;
        if (_guest) {
          // Guest mode has no bookings list to fall back to — restart the flow.
          _startBooking();
        } else {
          setState(() => _isBooking = false);
          _fetchMyBookings();
        }
      });
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, message: e.toString(), type: ToastType.error);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _cancelBookingApi(String id) async {
    try {
      await CustomerService.instance.cancelBooking(id);
      if (mounted) { AppToast.show(context, message: tr('bookingCancelled'), type: ToastType.success); _fetchMyBookings(); }
    } catch (_) {
      if (mounted) AppToast.show(context, message: tr('bookingFailed'), type: ToastType.error);
    }
  }

  void _openSalonSelector() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SalonScreen(isSelector: true, onSalonSelected: () {
        Navigator.of(context).pop();
        setState(() {});
        _fetchInitialData();
      }),
    ));
  }

  String _categoryLabel(String cat) => switch (cat) {
    'wigs' => tr('catWigs'), 'braids' => tr('catBraids'), 'locs' => tr('catLocs'),
    'curls' => tr('catCurls'), 'fades' => tr('catFades'), 'twists' => tr('catTwists'),
    'weaves' => tr('catWeaves'), 'natural' => tr('catNatural'), 'cornrows' => tr('catCornrows'),
    'updos' => tr('catUpdos'), 'color' => tr('catColor'), _ => cat,
  };

  IconData _categoryIcon(String cat) => switch (cat) {
    'wigs' => Icons.face_retouching_natural, 'braids' => Icons.grain,
    'locs' => Icons.waves, 'curls' => Icons.blur_on, 'fades' => Icons.content_cut,
    _ => Icons.grid_view_rounded,
  };

  Color _statusColor(String s) => switch (s) {
    'confirmed' => AppTheme.accentGreen, 'pending' => Colors.orange,
    'checked_in' => AppTheme.accentBlue, 'cancelled' => AppTheme.accentRed,
    _ => AppTheme.accentBlue,
  };

  // ═══════════════════════════════════════
  //  RESPONSIVE HELPERS
  // ═══════════════════════════════════════
  bool get _isTablet => MediaQuery.of(context).size.width >= 600;
  double get _maxContentWidth => _isTablet ? 600.0 : double.infinity;
  int get _categoryColumns => _isTablet ? 3 : 2;
  int get _styleColumns => _isTablet ? 3 : 2;
  int get _timeSlotsPerRow => _isTablet ? 6 : 4;

  Widget _responsiveCenter({required Widget child}) {
    if (!_isTablet) return child;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: _maxContentWidth),
        child: child,
      ),
    );
  }

  // ═══════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    if (!_hasSalon) return _buildNoSalonView();
    if (_isTablet) return _buildTabletLayout();

    // Style step — sticky bottom button
    if (_isBooking && _currentStep == 1) {
      return Stack(
        children: [
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: _responsiveCenter(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SizedBox(height: 8), _buildHeader(), _buildProgress(), const SizedBox(height: 6),
                _buildStyleStep(), const SizedBox(height: 160),
              ]),
            ),
          ),
          Positioned(left: 0, right: 0, bottom: 80, child: _responsiveCenter(
            child: _buildStickyButton(
              enabled: _selectedStyle != null, text: tr('continueBtn'), onPressed: _nextStep,
            ),
          )),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchMyBookings,
      color: AppTheme.getGold(context),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        child: _responsiveCenter(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 8), _buildHeader(),
            if (!_isBooking) ...[_buildBookingsList(), const SizedBox(height: 16), _buildNewBookingButton()]
            else ...[
              _buildProgress(), const SizedBox(height: 6),
              if (_currentStep == 0) _buildCategoryStep(),
              if (_currentStep == 2) _buildDateTimeStep(),
              if (_currentStep == 3) _buildConfirmStep(),
            ],
            const SizedBox(height: 100),
          ]),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════
  //  TABLET — full-screen two-pane layout
  // ═══════════════════════════════════════
  Widget _buildTabletLayout() {
    // Landing (bookings list) — wide, 2-column cards
    if (!_isBooking) {
      return RefreshIndicator(
        onRefresh: _fetchMyBookings,
        color: AppTheme.getGold(context),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SizedBox(height: 8), _buildHeader(),
                _buildBookingsListTablet(),
                const SizedBox(height: 16), _buildNewBookingButton(),
                const SizedBox(height: 100),
              ]),
            ),
          ),
        ),
      );
    }

    // Booking flow — summary sidebar (left) + active step (right)
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // LEFT — progress + live summary
        Expanded(
          flex: 2,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: _buildBookingSidebar(),
          ),
        ),
        const SizedBox(width: 16),
        // RIGHT — active step
        Expanded(
          flex: 3,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 8),
              if (_currentStep == 0) _buildCategoryStep(),
              if (_currentStep == 1) ...[
                _buildStyleStep(),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: GoldButton(text: tr('continueBtn'), expanded: true,
                      enabled: _selectedStyle != null, onPressed: _nextStep),
                ),
                _buildBackButton(),
              ],
              if (_currentStep == 2) _buildDateTimeStep(),
              if (_currentStep == 3) _buildConfirmStep(),
              const SizedBox(height: 100),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _buildBookingSidebar() {
    final steps = [tr('category'), tr('style'), '${tr('date')} & ${tr('time')}', tr('confirmBooking')];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 8),
      _buildHeader(),
      const SizedBox(height: 24),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(children: List.generate(steps.length, (i) {
          final isDone = _currentStep > i;
          final isActive = _currentStep == i;
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(children: [
              Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive ? AppTheme.getGold(context)
                      : isDone ? AppTheme.getGoldDim(context) : AppTheme.getBgGlass(context),
                  border: Border.all(color: isActive || isDone
                      ? AppTheme.getGold(context).withValues(alpha: 0.5) : AppTheme.getBorder(context)),
                ),
                child: Center(child: isDone
                    ? Icon(Icons.check, size: 16, color: AppTheme.getGold(context))
                    : Text('${i + 1}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                        color: isActive ? Colors.black : AppTheme.getTextSecondary(context)))),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(steps[i], style: TextStyle(fontSize: 14,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive ? AppTheme.getTextPrimary(context) : AppTheme.getTextSecondary(context)))),
            ]),
          );
        })),
      ),
      const SizedBox(height: 8),
      _buildSidebarSummary(),
    ]);
  }

  Widget _buildSidebarSummary() {
    final style = _selectedStyle;
    if (_selectedCategory == null && style == null) return const SizedBox.shrink();
    final img = style != null ? ApiClient.getImageUrl(style['imageUrl']?.toString() ?? '') : '';
    final showDateTime = _currentStep >= 2 && _selectedTimeIndex >= 0;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.getBgGlass(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.getBorder(context)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(tr('reviewDetails'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
            color: AppTheme.getTextSecondary(context))),
        const SizedBox(height: 12),
        if (style != null) ...[
          Row(children: [
            Container(
              width: 48, height: 58, clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.getBorder(context))),
              child: img.isNotEmpty
                  ? Image.network(img, fit: BoxFit.cover, errorBuilder: (_, _, _) => _bookingPlaceholder())
                  : _bookingPlaceholder(),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(style['name']?.toString() ?? '', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                  color: AppTheme.getTextPrimary(context)), maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text('${style["price"] ?? "0"} ${tr("fcfa")}', style: TextStyle(fontSize: 12,
                  fontWeight: FontWeight.w600, color: AppTheme.getGold(context))),
            ])),
          ]),
          const SizedBox(height: 8),
        ],
        if (_selectedCategory != null)
          _ConfirmRow(tr('category'), _categoryLabel(_selectedCategory!), isLast: !showDateTime),
        if (showDateTime) ...[
          _ConfirmRow(tr('date'), _fmtDate(_selectedDateStr)),
          _ConfirmRow(tr('time'), _selectedTimeStr, isLast: true),
        ],
      ]),
    );
  }

  Widget _buildBookingsListTablet() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Text(tr('yourBookings'), style: AppTheme.displayFont.copyWith(fontSize: 18, color: AppTheme.getTextPrimary(context)))),
      const SizedBox(height: 12),
      if (_loadingBookings)
        Padding(padding: const EdgeInsets.symmetric(vertical: 30),
            child: Center(child: CircularProgressIndicator(color: AppTheme.getGold(context), strokeWidth: 2)))
      else if (_myBookings.isEmpty)
        Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: GlassCard(child: Column(children: [
            Icon(Icons.event_available, size: 40, color: AppTheme.getTextTertiary(context)),
            const SizedBox(height: 12),
            Text(tr('noBookingsYet'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.getTextSecondary(context))),
            const SizedBox(height: 4),
            Text(tr('noBookingsSub'), style: TextStyle(fontSize: 12, color: AppTheme.getTextTertiary(context)), textAlign: TextAlign.center),
          ])))
      else
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: LayoutBuilder(builder: (context, c) {
            final cardW = (c.maxWidth - 16) / 2;
            return Wrap(spacing: 16, runSpacing: 0,
                children: _myBookings.map((b) => SizedBox(width: cardW, child: _buildBookingCard(b, grid: true))).toList());
          }),
        ),
    ]);
  }

  // ── No salon ──
  Widget _buildNoSalonView() => Center(
    child: Padding(padding: const EdgeInsets.all(40), child: Column(
      mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 80, height: 80, decoration: BoxDecoration(color: AppTheme.accentBlue.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: const Icon(Icons.store_rounded, color: AppTheme.accentBlue, size: 36)),
        const SizedBox(height: 20),
        Text(tr('noSalonConnected'), style: AppTheme.displayFont.copyWith(fontSize: 20, color: AppTheme.getTextPrimary(context)), textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(tr('noSalonConnectedSub'), style: TextStyle(fontSize: 13, color: AppTheme.getTextSecondary(context)), textAlign: TextAlign.center),
        const SizedBox(height: 24),
        if (!_guest) GoldButton(text: tr('findSalon'), onPressed: _openSalonSelector),
      ],
    )),
  );

  Widget _buildHeader() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(tr('bookAppointment'), style: AppTheme.displayFont.copyWith(fontSize: 24, color: AppTheme.getTextPrimary(context))),
      const SizedBox(height: 4),
      Row(children: [
        Icon(Icons.store_rounded, size: 14, color: AppTheme.accentGreen),
        const SizedBox(width: 4),
        Text(StorageService.instance.selectedSalonName ?? '', style: TextStyle(fontSize: 12, color: AppTheme.getTextSecondary(context))),
      ]),
    ]),
  );

  Widget _buildStickyButton({required bool enabled, required String text, required VoidCallback onPressed}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [AppTheme.getBgPrimary(context).withValues(alpha: 0), AppTheme.getBgPrimary(context)], stops: const [0.0, 0.3])),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        GoldButton(text: text, expanded: true, enabled: enabled, onPressed: onPressed),
        const SizedBox(height: 6),
        GestureDetector(onTap: _prevStep, child: Padding(padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(tr('back'), style: TextStyle(fontSize: 12, color: AppTheme.getGold(context), fontWeight: FontWeight.w500)))),
      ]),
    );
  }

  // ── Bookings list ──
  Widget _buildBookingsList() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Text(tr('yourBookings'), style: AppTheme.displayFont.copyWith(fontSize: 18, color: AppTheme.getTextPrimary(context)))),
      const SizedBox(height: 12),
      if (_loadingBookings)
        Padding(padding: const EdgeInsets.symmetric(vertical: 30),
            child: Center(child: CircularProgressIndicator(color: AppTheme.getGold(context), strokeWidth: 2)))
      else if (_myBookings.isEmpty)
        Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: GlassCard(child: Column(children: [
            Icon(Icons.event_available, size: 40, color: AppTheme.getTextTertiary(context)),
            const SizedBox(height: 12),
            Text(tr('noBookingsYet'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.getTextSecondary(context))),
            const SizedBox(height: 4),
            Text(tr('noBookingsSub'), style: TextStyle(fontSize: 12, color: AppTheme.getTextTertiary(context)), textAlign: TextAlign.center),
          ])))
      else
        ...List.generate(_myBookings.length, (i) => _buildBookingCard(_myBookings[i])),
    ]);
  }

  Widget _buildBookingCard(Map<String, dynamic> booking, {bool grid = false}) {
    final id = booking['id']?.toString() ?? '';
    final styleName = booking['style']?['name']?.toString() ?? booking['styleName']?.toString() ?? tr('appointment');
    final styleImg = ApiClient.getImageUrl(booking['style']?['imageUrl']?.toString() ?? '');
    final date = booking['date']?.toString() ?? '';
    final time = booking['time']?.toString() ?? '';
    final status = booking['status']?.toString() ?? 'pending';
    final price = booking['price']?.toString() ?? booking['style']?['price']?.toString();
    final duration = booking['duration'];
    final isCancellable = status == 'pending' || status == 'confirmed';
    final statusColor = _statusColor(status);

    return GlassCard(
      margin: grid ? const EdgeInsets.only(bottom: 16) : const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Style image
          Container(
            width: 60, height: 70,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.getBorder(context))),
            clipBehavior: Clip.antiAlias,
            child: styleImg.isNotEmpty
                ? Image.network(styleImg, fit: BoxFit.cover, errorBuilder: (_, _, _) => _bookingPlaceholder())
                : _bookingPlaceholder(),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(styleName, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.getTextPrimary(context)), maxLines: 1, overflow: TextOverflow.ellipsis)),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                  child: Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: statusColor))),
            ]),
            const SizedBox(height: 4),
            Row(children: [
              Icon(Icons.calendar_today_outlined, size: 12, color: AppTheme.getTextTertiary(context)),
              const SizedBox(width: 4),
              Text('${_fmtDate(date)} · $time', style: TextStyle(fontSize: 11, color: AppTheme.getTextSecondary(context))),
              if (duration != null) ...[
                const SizedBox(width: 8),
                Text('${duration}min', style: TextStyle(fontSize: 10, color: AppTheme.getTextTertiary(context))),
              ],
            ]),
            const SizedBox(height: 6),
            Row(children: [
              if (price != null)
                Text('$price ${tr("fcfa")}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.getGold(context))),
              const Spacer(),
              if (isCancellable)
                GestureDetector(
                  onTap: () => _showCancelDialog(id, styleName),
                  child: Text(tr('cancel'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppTheme.accentRed)),
                ),
            ]),
          ])),
        ],
      ),
    );
  }

  Widget _bookingPlaceholder() => Container(color: AppTheme.getBgGlass(context),
      child: Icon(Icons.content_cut, size: 22, color: AppTheme.getTextTertiary(context)));

  void _showCancelDialog(String id, String name) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: AppTheme.getBgSecondary(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(tr('cancelConfirmTitle'), style: TextStyle(color: AppTheme.getTextPrimary(context), fontWeight: FontWeight.w600)),
      content: Text('${tr("cancelConfirmMsg")}\n\n$name', style: TextStyle(color: AppTheme.getTextSecondary(context))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('no'), style: TextStyle(color: AppTheme.getTextSecondary(context)))),
        TextButton(onPressed: () { Navigator.pop(ctx); _cancelBookingApi(id); },
            child: Text(tr('yesCancelIt'), style: const TextStyle(color: AppTheme.accentRed, fontWeight: FontWeight.w600))),
      ],
    ));
  }

  Widget _buildNewBookingButton() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: GoldButton(text: tr('bookNewAppointment'), expanded: true, onPressed: _startBooking),
  );

  // ── Progress ──
  Widget _buildProgress() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
    child: Row(children: [
      _StepDot(isActive: _currentStep == 0, isDone: _currentStep > 0), _StepLine(isDone: _currentStep > 0),
      _StepDot(isActive: _currentStep == 1, isDone: _currentStep > 1), _StepLine(isDone: _currentStep > 1),
      _StepDot(isActive: _currentStep == 2, isDone: _currentStep > 2), _StepLine(isDone: _currentStep > 2),
      _StepDot(isActive: _currentStep == 3, isDone: false),
    ]),
  );

  // ═══════════════════════════════════════
  //  STEP 0: Category
  // ═══════════════════════════════════════
  Widget _buildCategoryStep() {
    if (_loadingStyles) return _centeredLoader(tr('loadingStyles'));
    if (_stylesError != null) return _centeredError(_stylesError!, _fetchStyles);
    final categories = _availableCategories;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Gender toggle
      Padding(padding: const EdgeInsets.fromLTRB(20, 20, 20, 0), child: Row(children: [
        Expanded(child: _GenderTab(label: tr('women'), isSelected: _selectedGender == 'women',
            onTap: () => setState(() { _selectedGender = 'women'; _selectedCategory = null; }))),
        const SizedBox(width: 10),
        Expanded(child: _GenderTab(label: tr('men'), isSelected: _selectedGender == 'men',
            onTap: () => setState(() { _selectedGender = 'men'; _selectedCategory = null; }))),
      ])),
      const SizedBox(height: 20),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(tr('chooseCategory'), style: AppTheme.displayFont.copyWith(fontSize: 18, color: AppTheme.getTextPrimary(context)))),
      const SizedBox(height: 14),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 20),
        child: GridView.count(crossAxisCount: _categoryColumns, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 2.2,
            children: categories.map((cat) {
              final isSelected = _selectedCategory == cat;
              final count = _allStyles.where((s) => s['gender']?.toString() == _selectedGender && s['category']?.toString() == cat).length;
              return GestureDetector(
                onTap: () => setState(() => _selectedCategory = cat),
                child: AnimatedContainer(duration: const Duration(milliseconds: 250), padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.getGoldDim(context) : AppTheme.getBgGlass(context),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isSelected ? AppTheme.getGold(context).withValues(alpha: 0.4) : AppTheme.getBorder(context)),
                  ),
                  child: Row(children: [
                    Icon(_categoryIcon(cat), color: isSelected ? AppTheme.getGold(context) : AppTheme.getTextSecondary(context), size: 22),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(_categoryLabel(cat), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.getTextPrimary(context))),
                      Text('$count ${tr("stylesCount")}', style: TextStyle(fontSize: 11, color: AppTheme.getTextSecondary(context))),
                    ])),
                  ]),
                ),
              );
            }).toList()),
      ),
      const SizedBox(height: 16),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 20),
          child: GoldButton(text: tr('continueBtn'), expanded: true, enabled: _selectedCategory != null,
              onPressed: () { _filterStyles(); _nextStep(); })),
      _buildBackButton(),
    ]);
  }

  // ═══════════════════════════════════════
  //  STEP 1: Style
  // ═══════════════════════════════════════
  Widget _buildStyleStep() {
    final styles = _filteredStyles;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Text(tr('chooseStyle'), style: AppTheme.displayFont.copyWith(fontSize: 18, color: AppTheme.getTextPrimary(context)))),
      const SizedBox(height: 4),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(_selectedCategory != null ? _categoryLabel(_selectedCategory!) : '',
              style: TextStyle(fontSize: 12, color: AppTheme.getGold(context), fontWeight: FontWeight.w500))),
      const SizedBox(height: 14),
      if (styles.isEmpty)
        Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Center(child: Text(tr('noStylesFound'), style: TextStyle(fontSize: 13, color: AppTheme.getTextSecondary(context)))))
      else
        Padding(padding: const EdgeInsets.symmetric(horizontal: 20),
          child: GridView.builder(
            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: _styleColumns, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.62),
            itemCount: styles.length,
            itemBuilder: (context, index) {
              final style = styles[index];
              final styleId = style['id']?.toString() ?? '';
              final selectedId = _selectedStyle?['id']?.toString() ?? '';
              final isSelected = _selectedStyle != null && styleId == selectedId;
              return GestureDetector(
                onTap: () => setState(() => _selectedStyle = style),
                child: AnimatedContainer(duration: const Duration(milliseconds: 250),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.getGoldDim(context) : AppTheme.getBgGlass(context),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isSelected ? AppTheme.getGold(context).withValues(alpha: 0.5) : AppTheme.getBorder(context), width: isSelected ? 1.5 : 1),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
                      child: Image.network(ApiClient.getImageUrl(style['imageUrl']?.toString() ?? ''),
                          width: double.infinity, fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(color: AppTheme.getBgGlass(context),
                              child: Center(child: Icon(Icons.image_not_supported_outlined, color: AppTheme.getTextTertiary(context), size: 32)))),
                    )),
                    Padding(padding: const EdgeInsets.fromLTRB(10, 8, 10, 10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(style['name']?.toString() ?? '', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.getTextPrimary(context)),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text('${style["price"] ?? "0"} ${tr("fcfa")}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppTheme.getGold(context))),
                      if (style['duration'] != null)
                        Text('${style["duration"]} min', style: TextStyle(fontSize: 10, color: AppTheme.getTextTertiary(context))),
                    ])),
                  ]),
                ),
              );
            },
          ),
        ),
    ]);
  }

  // ═══════════════════════════════════════
  //  STEP 2: Date & Time (salon-based)
  // ═══════════════════════════════════════
  Widget _buildDateTimeStep() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // ── Date picker ──
      Padding(padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Text(tr('selectDate'), style: AppTheme.displayFont.copyWith(fontSize: 18, color: AppTheme.getTextPrimary(context)))),
      const SizedBox(height: 12),
      if (_loadingDates)
        Padding(padding: const EdgeInsets.symmetric(vertical: 24), child: Center(child: CircularProgressIndicator(color: AppTheme.getGold(context), strokeWidth: 2)))
      else if (_availableDates.isEmpty)
        Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20), child: Center(child: Column(children: [
          Icon(Icons.event_busy, size: 36, color: AppTheme.getTextTertiary(context)),
          const SizedBox(height: 8),
          Text(tr('noDatesAvailable'), style: TextStyle(fontSize: 13, color: AppTheme.getTextSecondary(context))),
        ])))
      else
        SizedBox(height: 78, child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 20), scrollDirection: Axis.horizontal,
          itemCount: _availableDates.length, separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final d = _availableDates[index];
            final dateStr = d['date']?.toString() ?? '';
            final isOpen = d['isOpen'] != false;
            final availSlots = d['availableSlots'] as int? ?? 0;
            final totalSlots = d['totalSlots'] as int? ?? 0;
            final isSelected = _selectedDateIndex == index;
            DateTime? dt; try { dt = DateTime.parse(dateStr); } catch (_) {}

            // Color: green=available, orange=almost full, grey=closed
            Color dotColor;
            if (!isOpen) { dotColor = AppTheme.getTextTertiary(context); }
            else if (totalSlots > 0 && availSlots <= (totalSlots * 0.2).ceil()) { dotColor = Colors.orange; }
            else { dotColor = AppTheme.accentGreen; }

            return GestureDetector(
              onTap: isOpen ? () { setState(() { _selectedDateIndex = index; _selectedTimeIndex = -1; }); _fetchAvailableTimes(); } : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250), width: 64,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: !isOpen ? AppTheme.getBgGlass(context).withValues(alpha: 0.5)
                      : isSelected ? AppTheme.getGoldDim(context) : AppTheme.getBgGlass(context),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isSelected ? AppTheme.getGold(context).withValues(alpha: 0.4) : AppTheme.getBorder(context)),
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(dt != null ? DateFormat('E').format(dt) : '', style: TextStyle(fontSize: 10,
                      color: !isOpen ? AppTheme.getTextTertiary(context) : isSelected ? AppTheme.getGold(context) : AppTheme.getTextSecondary(context))),
                  const SizedBox(height: 2),
                  Text(dt != null ? DateFormat('d').format(dt) : dateStr, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                      color: !isOpen ? AppTheme.getTextTertiary(context) : isSelected ? AppTheme.getGold(context) : AppTheme.getTextPrimary(context))),
                  const SizedBox(height: 4),
                  // Availability dot
                  Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor)),
                ]),
              ),
            );
          },
        )),

      // ── Time slots ──
      const SizedBox(height: 24),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(tr('selectTime'), style: AppTheme.displayFont.copyWith(fontSize: 18, color: AppTheme.getTextPrimary(context)))),
      const SizedBox(height: 12),
      if (_loadingTimes)
        Padding(padding: const EdgeInsets.symmetric(vertical: 24), child: Center(child: Column(children: [
          SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.getGold(context))),
          const SizedBox(height: 8),
          Text(tr('loadingSlots'), style: TextStyle(fontSize: 12, color: AppTheme.getTextSecondary(context))),
        ])))
      else if (_timeSlots.isEmpty)
        Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(
              color: AppTheme.accentRed.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              const Icon(Icons.event_busy, color: AppTheme.accentRed, size: 22),
              const SizedBox(width: 12),
              Expanded(child: Text(tr('salonClosedDay'), style: TextStyle(fontSize: 13, color: AppTheme.getTextSecondary(context)))),
            ]),
          ),
        )
      else
        Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: LayoutBuilder(
        builder: (context, constraints) {
          final cols = _timeSlotsPerRow;
          final slotWidth = (constraints.maxWidth - (cols - 1) * 8) / cols;
          return Wrap(spacing: 8, runSpacing: 8,
          children: List.generate(_timeSlots.length, (index) {
            final slot = _timeSlots[index];
            final time = slot['time']?.toString() ?? '';
            final available = slot['available'] == true;
            final spotsLeft = slot['spotsLeft'] as int? ?? 0;
            final isSelected = _selectedTimeIndex == index;
            final isLow = available && spotsLeft > 0 && spotsLeft <= 2;

            return GestureDetector(
              onTap: available ? () => setState(() => _selectedTimeIndex = index) : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: slotWidth,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: !available ? AppTheme.getBgGlass(context).withValues(alpha: 0.4)
                      : isSelected ? AppTheme.getGoldDim(context) : AppTheme.getBgGlass(context),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isSelected ? AppTheme.getGold(context).withValues(alpha: 0.4) : AppTheme.getBorder(context)),
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(time, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                      color: !available ? AppTheme.getTextTertiary(context)
                          : isSelected ? AppTheme.getGold(context) : AppTheme.getTextPrimary(context),
                      decoration: !available ? TextDecoration.lineThrough : null)),
                  if (isLow)
                    Text('$spotsLeft ${tr("left")}', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.orange)),
                  if (!available)
                    Text(tr('full'), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: AppTheme.getTextTertiary(context))),
                ]),
              ),
            );
          }),
        );
        },
      )),

      const SizedBox(height: 20),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 20),
          child: GoldButton(text: tr('reviewBooking'), expanded: true,
              enabled: !_loadingTimes && _selectedTimeIndex >= 0, onPressed: _nextStep)),
      _buildBackButton(),
    ]);
  }

  // ═══════════════════════════════════════
  //  STEP 3: Confirm
  // ═══════════════════════════════════════
  Widget _buildConfirmStep() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0), padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: AppTheme.getBgGlass(context), borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.getBorder(context))),
      child: Column(children: [
        Container(width: 60, height: 60, decoration: BoxDecoration(shape: BoxShape.circle,
            gradient: LinearGradient(colors: [AppTheme.accentGreen.withValues(alpha: 0.2), AppTheme.accentGreen.withValues(alpha: 0.05)])),
            child: const Icon(Icons.check, color: AppTheme.accentGreen, size: 28)),
        const SizedBox(height: 16),
        Text(tr('confirmBooking'), style: AppTheme.displayFont.copyWith(fontSize: 22, color: AppTheme.getTextPrimary(context))),
        const SizedBox(height: 6),
        Text(tr('reviewDetails'), style: TextStyle(fontSize: 13, color: AppTheme.getTextSecondary(context))),
        const SizedBox(height: 16),
        Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(12)),
          child: Column(children: [
            _ConfirmRow(tr('salon'), StorageService.instance.selectedSalonName ?? ''),
            _ConfirmRow(tr('style'), _selectedStyle?['name']?.toString() ?? ''),
            _ConfirmRow(tr('category'), _selectedCategory != null ? _categoryLabel(_selectedCategory!) : ''),
            _ConfirmRow(tr('date'), _fmtDate(_selectedDateStr)),
            _ConfirmRow(tr('time'), _selectedTimeStr),
            if (_selectedStyle?['duration'] != null)
              _ConfirmRow(tr('duration'), '${_selectedStyle!["duration"]} min'),
            _ConfirmRow(tr('price'), '${_selectedStyle?["price"] ?? "0"} ${tr("fcfa")}', isGold: true, isLast: true),
          ]),
        ),
        const SizedBox(height: 16),
        GoldButton(text: _submitting ? tr('submitting') : tr('confirmAppointment'),
            expanded: true, enabled: !_submitting, onPressed: _confirmBooking),
        const SizedBox(height: 12),
        GestureDetector(onTap: _prevStep,
            child: Text(tr('changeTime'), style: TextStyle(fontSize: 12, color: AppTheme.getGold(context), fontWeight: FontWeight.w500))),
      ]),
    );
  }

  Widget _buildBackButton() => Center(child: Padding(padding: const EdgeInsets.only(top: 12),
      child: GestureDetector(onTap: _prevStep,
          child: Text(tr('back'), style: TextStyle(fontSize: 12, color: AppTheme.getGold(context), fontWeight: FontWeight.w500)))));

  Widget _centeredLoader(String text) => Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Center(child: Column(children: [
        SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.getGold(context))),
        const SizedBox(height: 12),
        Text(text, style: TextStyle(fontSize: 13, color: AppTheme.getTextSecondary(context))),
      ])));

  Widget _centeredError(String text, VoidCallback onRetry) => Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Center(child: Column(children: [
        const Icon(Icons.error_outline, color: AppTheme.accentRed, size: 36),
        const SizedBox(height: 12),
        Text(text, style: TextStyle(fontSize: 13, color: AppTheme.getTextSecondary(context))),
        const SizedBox(height: 16),
        GoldButton(text: tr('retry'), onPressed: onRetry),
        const SizedBox(height: 8), _buildBackButton(),
      ])));
}

// ─── Helper widgets ───

class _GenderTab extends StatelessWidget {
  final String label; final bool isSelected; final VoidCallback onTap;
  const _GenderTab({required this.label, required this.isSelected, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap,
    child: AnimatedContainer(duration: const Duration(milliseconds: 250), padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: isSelected ? AppTheme.getGoldDim(context) : AppTheme.getBgGlass(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isSelected ? AppTheme.getGold(context).withValues(alpha: 0.4) : AppTheme.getBorder(context)),
      ),
      child: Center(child: Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
          color: isSelected ? AppTheme.getGold(context) : AppTheme.getTextSecondary(context))))));
}

class _ConfirmRow extends StatelessWidget {
  final String label, value; final bool isGold, isLast;
  const _ConfirmRow(this.label, this.value, {this.isGold = false, this.isLast = false});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 8),
    decoration: BoxDecoration(border: isLast ? null : Border(bottom: BorderSide(color: AppTheme.getBorder(context)))),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(fontSize: 13, color: AppTheme.getTextSecondary(context))),
      Flexible(child: Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
          color: isGold ? AppTheme.getGold(context) : AppTheme.getTextPrimary(context)),
          textAlign: TextAlign.end, overflow: TextOverflow.ellipsis)),
    ]),
  );
}

class _StepDot extends StatelessWidget {
  final bool isActive, isDone;
  const _StepDot({required this.isActive, required this.isDone});
  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 300), width: isActive ? 28 : 12, height: 12,
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(6),
        color: isActive ? AppTheme.getGold(context) : isDone ? AppTheme.accentGreen : AppTheme.getBgGlassStrong(context)));
}

class _StepLine extends StatelessWidget {
  final bool isDone;
  const _StepLine({required this.isDone});
  @override
  Widget build(BuildContext context) => Expanded(child: Container(height: 1, margin: const EdgeInsets.symmetric(horizontal: 6),
      color: isDone ? AppTheme.accentGreen.withValues(alpha: 0.3) : AppTheme.getBorder(context)));
}
