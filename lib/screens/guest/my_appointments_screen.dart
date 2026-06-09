import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../l10n/app_locale.dart';
import '../../services/api_client.dart';
import '../../services/customer_service.dart';
import '../../services/storage_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/gold_button.dart';

/// A signed-in customer's appointments at the current salon. Reads
/// GET /bookings (customer-scoped via the Bearer token) and groups them into
/// Upcoming / Past / Cancelled tabs. Lets the user cancel an upcoming booking.
class MyAppointmentsScreen extends StatefulWidget {
  const MyAppointmentsScreen({super.key});

  @override
  State<MyAppointmentsScreen> createState() => _MyAppointmentsScreenState();
}

enum _Tab { upcoming, past, cancelled }

class _MyAppointmentsScreenState extends State<MyAppointmentsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _bookings = [];
  _Tab _tab = _Tab.upcoming;
  String? _cancellingId;

  String? get _salonId => StorageService.instance.selectedSalonId;

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
      final res = await CustomerService.instance
          .getMyBookings(query: {'limit': '50'});
      // The list may sit at res['data'] (documented shape) or be a bare list.
      final raw = res['data'] ?? res['bookings'] ?? res['items'] ?? res;
      final list = raw is List ? raw : const [];
      var bookings = list
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      // Scope to the salon the customer is signed in under, when known.
      final salonId = _salonId;
      if (salonId != null && salonId.isNotEmpty) {
        final scoped =
            bookings.where((b) => b['salonId']?.toString() == salonId).toList();
        // Only narrow when it actually matches something — otherwise the API
        // may not echo salonId and we'd hide everything.
        if (scoped.isNotEmpty) bookings = scoped;
      }
      if (!mounted) return;
      setState(() {
        _bookings = bookings;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  /// `yyyy-MM-dd` for today, for cheap string comparison against booking dates.
  String get _todayStr => DateFormat('yyyy-MM-dd').format(DateTime.now());

  bool _isCancelled(Map<String, dynamic> b) =>
      (b['status']?.toString() ?? '') == 'cancelled';

  String _dateOf(Map<String, dynamic> b) => b['date']?.toString() ?? '';

  List<Map<String, dynamic>> get _visible {
    final today = _todayStr;
    final filtered = _bookings.where((b) {
      switch (_tab) {
        case _Tab.cancelled:
          return _isCancelled(b);
        case _Tab.upcoming:
          return !_isCancelled(b) && _dateOf(b).compareTo(today) >= 0;
        case _Tab.past:
          return !_isCancelled(b) && _dateOf(b).compareTo(today) < 0;
      }
    }).toList();
    // Upcoming: soonest first. Past/Cancelled: most recent first.
    filtered.sort((a, b) {
      final cmp = _dateOf(a).compareTo(_dateOf(b));
      return _tab == _Tab.upcoming ? cmp : -cmp;
    });
    return filtered;
  }

  Future<void> _cancel(Map<String, dynamic> b) async {
    final id = b['id']?.toString();
    if (id == null || id.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.getBgSecondary(ctx),
        title: Text(tr('cancelConfirmTitle'),
            style: TextStyle(color: AppTheme.getTextPrimary(ctx))),
        content: Text(tr('cancelConfirmMsg'),
            style: TextStyle(color: AppTheme.getTextSecondary(ctx))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('no'),
                style: TextStyle(color: AppTheme.getTextSecondary(ctx))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('yesCancelIt'),
                style: const TextStyle(color: AppTheme.accentRed)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _cancellingId = id);
    try {
      await CustomerService.instance.cancelBooking(id);
      if (!mounted) return;
      AppToast.show(context,
          message: tr('bookingCancelled'), type: ToastType.success);
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      AppToast.show(context, message: e.message, type: ToastType.error);
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, message: tr('retry'), type: ToastType.error);
    } finally {
      if (mounted) setState(() => _cancellingId = null);
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
          '${tr('myAppointments')}${salonName.isEmpty ? "" : " · $salonName"}',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppTheme.getTextPrimary(context),
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            _tabBar(),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _tabBar() {
    final tabs = <(_Tab, String)>[
      (_Tab.upcoming, tr('upcoming')),
      (_Tab.past, tr('past')),
      (_Tab.cancelled, tr('statusCancelled')),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppTheme.getBgGlass(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.getBorder(context)),
        ),
        child: Row(
          children: tabs.map((t) {
            final active = _tab == t.$1;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _tab = t.$1),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color:
                        active ? AppTheme.getGold(context) : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    t.$2,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: active
                          ? Colors.white
                          : AppTheme.getTextSecondary(context),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return Center(
        child: CircularProgressIndicator(
            color: AppTheme.getGold(context), strokeWidth: 2),
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
                  color: AppTheme.accentRed, size: 34),
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
    final items = _visible;
    if (items.isEmpty) return _empty();
    return RefreshIndicator(
      onRefresh: _load,
      color: AppTheme.getGold(context),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _bookingCard(items[i]),
      ),
    );
  }

  Widget _empty() {
    return ListView(
      physics:
          const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(32, 80, 32, 32),
      children: [
        Icon(Icons.event_busy_outlined,
            size: 44, color: AppTheme.getTextTertiary(context)),
        const SizedBox(height: 14),
        Text(tr('noAppointments'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppTheme.getTextPrimary(context),
            )),
        const SizedBox(height: 6),
        Text(tr('noAppointmentsSub'),
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: AppTheme.getTextSecondary(context))),
      ],
    );
  }

  Widget _bookingCard(Map<String, dynamic> b) {
    final style = b['style'] is Map ? b['style'] as Map : const {};
    final name = style['name']?.toString() ?? tr('bookingDetails');
    final img = ApiClient.getImageUrl(style['imageUrl']?.toString() ?? '');
    final price = b['price'] ?? style['price'];
    final status = b['status']?.toString() ?? 'pending';
    final canCancel = _tab == _Tab.upcoming &&
        (status == 'confirmed' || status == 'pending');
    final cancelling = _cancellingId == b['id']?.toString();

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.getBgGlass(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.getBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 64,
                    height: 64,
                    child: img.isNotEmpty
                        ? Image.network(img,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => _imgFallback())
                        : _imgFallback(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(name,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.getTextPrimary(context),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                          const SizedBox(width: 8),
                          _statusBadge(status),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.event_outlined,
                              size: 14,
                              color: AppTheme.getTextSecondary(context)),
                          const SizedBox(width: 5),
                          Text(_formatWhen(b),
                              style: TextStyle(
                                  fontSize: 12.5,
                                  color: AppTheme.getTextSecondary(context))),
                        ],
                      ),
                      if (price != null) ...[
                        const SizedBox(height: 4),
                        Text('$price ${tr("fcfa")}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.getGold(context),
                            )),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (canCancel) ...[
            Divider(height: 1, color: AppTheme.getBorder(context)),
            InkWell(
              onTap: cancelling ? null : () => _cancel(b),
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(16)),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                alignment: Alignment.center,
                child: cancelling
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppTheme.accentRed),
                      )
                    : Text(tr('cancelBooking'),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.accentRed,
                        )),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// "Sun, 15 Jun · 14:00" in the active locale.
  String _formatWhen(Map<String, dynamic> b) {
    final dateStr = _dateOf(b);
    final time = b['time']?.toString() ?? '';
    String datePart = dateStr;
    final parsed = DateTime.tryParse(dateStr);
    if (parsed != null) {
      datePart = DateFormat('EEE, d MMM', AppLocale.instance.languageCode)
          .format(parsed);
    }
    return time.isEmpty ? datePart : '$datePart · $time';
  }

  Widget _statusBadge(String status) {
    final color = switch (status) {
      'confirmed' => AppTheme.accentBlue,
      'checked_in' => AppTheme.accentGreen,
      'pending' => const Color(0xFFE5A100),
      'cancelled' => AppTheme.accentRed,
      _ => AppTheme.getTextTertiary(context),
    };
    final label = switch (status) {
      'confirmed' => tr('statusConfirmed'),
      'checked_in' => tr('statusCheckedIn'),
      'pending' => tr('statusPending'),
      'cancelled' => tr('statusCancelled'),
      _ => status,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
    );
  }

  Widget _imgFallback() => Container(
        color: AppTheme.getBgGlass(context),
        child: Icon(Icons.image_not_supported_outlined,
            color: AppTheme.getTextTertiary(context), size: 20),
      );
}
