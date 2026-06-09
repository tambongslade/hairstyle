import 'package:flutter/material.dart';
import '../../l10n/app_locale.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/public_service.dart';
import '../../services/storage_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/gold_button.dart';
import '../../widgets/loyalty_content.dart';
import 'my_appointments_screen.dart';

/// Fidelity page for a signed-in customer at the current salon. Reads
/// /public/salons/:salonId/me/loyalty with the Bearer token. Includes a
/// sign-out action that returns the user to the guest experience.
class ClientFidelityScreen extends StatefulWidget {
  const ClientFidelityScreen({super.key});

  @override
  State<ClientFidelityScreen> createState() => _ClientFidelityScreenState();
}

class _ClientFidelityScreenState extends State<ClientFidelityScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _data;

  String? get _salonId => StorageService.instance.selectedSalonId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final salonId = _salonId;
    if (salonId == null) {
      setState(() {
        _loading = false;
        _error = tr('noSalonSelectedShort');
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    debugPrint('[Fidelity] GET /public/salons/$salonId/me/loyalty');
    try {
      final res = await PublicService.instance.getMyLoyalty(salonId);
      debugPrint('[Fidelity] response keys=${res.keys.toList()}');
      // Loyalty payload may sit at res, res['data'], or res['loyalty'].
      final raw = res['loyalty'] ?? res['data'] ?? res;
      final data = raw is Map<String, dynamic>
          ? raw
          : Map<String, dynamic>.from(raw as Map);
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } on ApiException catch (e) {
      debugPrint('[Fidelity] API ERROR status=${e.statusCode} message="${e.message}"');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (e, st) {
      debugPrint('[Fidelity] ERROR: $e');
      debugPrintStack(stackTrace: st, label: '[Fidelity] _load');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.getBgSecondary(ctx),
        title: Text(tr('signOut'),
            style: TextStyle(color: AppTheme.getTextPrimary(ctx))),
        content: Text(tr('signOutConfirm'),
            style: TextStyle(color: AppTheme.getTextSecondary(ctx))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('cancel'),
                style: TextStyle(color: AppTheme.getTextSecondary(ctx))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('signOut'),
                style: const TextStyle(color: AppTheme.accentRed)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await AuthService.instance.logout();
    if (!mounted) return;
    Navigator.of(context).pop();
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
          '${tr('myRewards')}${salonName.isEmpty ? "" : " · $salonName"}',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppTheme.getTextPrimary(context),
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.event_note_rounded,
                color: AppTheme.getTextSecondary(context), size: 20),
            tooltip: tr('myAppointments'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MyAppointmentsScreen()),
            ),
          ),
          IconButton(
            icon: Icon(Icons.logout_rounded,
                color: AppTheme.getTextSecondary(context), size: 20),
            tooltip: tr('signOut'),
            onPressed: _signOut,
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          color: AppTheme.getGold(context),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              _profileHeader(),
              const SizedBox(height: 18),
              _buildBody(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _profileHeader() {
    final name = StorageService.instance.guestName ??
        _data?['clientName']?.toString() ??
        _data?['name']?.toString() ??
        '';
    final email = StorageService.instance.guestEmail ??
        _data?['clientEmail']?.toString() ??
        _data?['email']?.toString() ??
        '';
    if (name.isEmpty && email.isEmpty) return const SizedBox.shrink();
    return Row(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: AppTheme.getGoldDim(context),
          child: Icon(Icons.person_rounded, color: AppTheme.getGold(context)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (name.isNotEmpty)
                Text(name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.getTextPrimary(context),
                    )),
              if (email.isNotEmpty)
                Text(email,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.getTextSecondary(context),
                    )),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
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
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 30),
        child: Column(
          children: [
            const Icon(Icons.error_outline, color: AppTheme.accentRed, size: 32),
            const SizedBox(height: 10),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13, color: AppTheme.getTextSecondary(context)),
            ),
            const SizedBox(height: 14),
            GoldButton(text: tr('retry'), onPressed: _load),
          ],
        ),
      );
    }
    final data = _data;
    if (data == null) return const SizedBox.shrink();
    return LoyaltyContent(data: data);
  }
}
