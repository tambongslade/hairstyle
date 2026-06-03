import 'package:flutter/material.dart';
import '../../l10n/app_locale.dart';
import '../../services/api_client.dart';
import '../../services/public_service.dart';
import '../../services/storage_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/gold_button.dart';
import '../../widgets/loyalty_content.dart';

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
    return LoyaltyContent(data: data);
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

}
