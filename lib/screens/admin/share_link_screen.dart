import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../l10n/app_locale.dart';
import '../../services/admin_service.dart';
import '../../services/api_client.dart';
import '../../services/storage_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/gold_button.dart';

/// Admin-facing screen that shows the salon's public share link.
/// Salon owners send this to clients via WhatsApp / SMS / etc; the client
/// opens it and lands on [GuestShell] without signing up.
class ShareLinkScreen extends StatefulWidget {
  const ShareLinkScreen({super.key});

  @override
  State<ShareLinkScreen> createState() => _ShareLinkScreenState();
}

class _ShareLinkScreenState extends State<ShareLinkScreen> {
  bool _loading = true;
  String? _error;
  String? _salonId;
  String? _salonName;

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
      final res = await AdminService.instance.getSalon();
      final data = (res['data'] ?? res) as Map<String, dynamic>;
      final id = data['id']?.toString();
      final name = data['name']?.toString();
      if (id == null || id.isEmpty) {
        throw Exception('Salon profile is missing an id.');
      }
      if (mounted) {
        setState(() {
          _salonId = id;
          _salonName = name;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  String get _link => _salonId == null ? '' : ApiClient.catalogueShareUrl(_salonId!);

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _link));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Link copied'),
        backgroundColor: AppTheme.accentGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _share() async {
    final name = _salonName ?? StorageService.instance.selectedSalonName ?? 'us';
    final message =
        'Hi! Browse styles, try them on with AI, and book an appointment at $name: $_link';
    await Share.share(message, subject: 'Book with $name');
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
          'Customer link',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.getTextPrimary(context),
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(child: _buildBody()),
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
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.getTextSecondary(context),
                ),
              ),
              const SizedBox(height: 16),
              GoldButton(text: tr('retry'), onPressed: _load),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        Text(
          'Share with your clients',
          style: AppTheme.displayFont.copyWith(
            fontSize: 22,
            color: AppTheme.getTextPrimary(context),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Anyone with this link can browse your catalogue, try a style on with AI, and book — no sign up needed.',
          style: TextStyle(
            fontSize: 13,
            color: AppTheme.getTextSecondary(context),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 20),
        _buildQrCard(),
        const SizedBox(height: 16),
        _buildLinkCard(),
        const SizedBox(height: 16),
        _buildActions(),
        const SizedBox(height: 24),
        _buildHowTo(),
      ],
    );
  }

  Widget _buildQrCard() {
    return GlassCard(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: QrImageView(
              data: _link,
              size: 200,
              backgroundColor: Colors.white,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Colors.black,
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Colors.black,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLinkCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      decoration: BoxDecoration(
        color: AppTheme.getBgGlass(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.getBorder(context)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _link,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTheme.getTextPrimary(context),
                fontFamily: 'monospace',
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            tooltip: 'Copy',
            onPressed: _copy,
            icon: Icon(Icons.copy_rounded,
                color: AppTheme.getGold(context), size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Row(
      children: [
        Expanded(
          child: GoldButton(
            text: 'Share',
            onPressed: _share,
            expanded: true,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _copy,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: BorderSide(color: AppTheme.getGold(context)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: Icon(Icons.copy_rounded,
                color: AppTheme.getGold(context), size: 18),
            label: Text(
              'Copy link',
              style: TextStyle(
                color: AppTheme.getGold(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHowTo() {
    final steps = [
      ('Send the link', 'Share by WhatsApp, SMS, email, or print the QR code.'),
      ('Client browses your styles', 'No sign-up needed — they land on your salon\'s catalogue.'),
      ('They book or try on a look', 'Bookings and try-ons land in your dashboard.'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How it works',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.getTextSecondary(context),
          ),
        ),
        const SizedBox(height: 10),
        for (int i = 0; i < steps.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: AppTheme.getGoldDim(context),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: AppTheme.getGold(context).withValues(alpha: 0.4)),
                  ),
                  child: Center(
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.getGold(context),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        steps[i].$1,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.getTextPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        steps[i].$2,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.getTextSecondary(context),
                          height: 1.4,
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
}
