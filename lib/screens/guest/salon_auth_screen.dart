import 'package:flutter/material.dart';
import '../../l10n/app_locale.dart';
import '../../services/api_client.dart';
import '../../services/public_service.dart';
import '../../services/storage_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/auth_error_dialog.dart';
import '../../widgets/gold_button.dart';
import 'guest_loyalty_screen.dart';

/// Salon-scoped customer auth. Reached from the shared catalogue link so a
/// client can sign in or create an account *under this salon* (which enrolls
/// them in its fidelity programme), or fall back to browsing/booking as a
/// guest. Pops `true` once authenticated.
class SalonAuthScreen extends StatefulWidget {
  /// When true the form starts on the "create account" tab.
  final bool startOnSignup;
  const SalonAuthScreen({super.key, this.startOnSignup = false});

  @override
  State<SalonAuthScreen> createState() => _SalonAuthScreenState();
}

class _SalonAuthScreenState extends State<SalonAuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  late bool _isSignup = widget.startOnSignup;
  bool _obscure = true;
  bool _submitting = false;
  String? _error;

  String? get _salonId => StorageService.instance.selectedSalonId;
  String get _salonName =>
      StorageService.instance.selectedSalonName ?? tr('thisSalon');

  @override
  void initState() {
    super.initState();
    // Prefill from any saved guest/customer profile.
    _name.text = StorageService.instance.guestName ?? '';
    _phone.text = StorageService.instance.guestPhone ?? '';
    _email.text = StorageService.instance.guestEmail ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final salonId = _salonId;
    if (salonId == null) {
      setState(() => _error = tr('noSalonSelectedShort'));
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      if (_isSignup) {
        await PublicService.instance.registerUnderSalon(
          salonId,
          name: _name.text.trim(),
          email: _email.text.trim(),
          password: _password.text,
          phone: _phone.text.trim(),
        );
      } else {
        await PublicService.instance.loginUnderSalon(
          salonId,
          email: _email.text.trim(),
          password: _password.text,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.message;
      });
      // A modal makes the failure (e.g. email already registered) impossible
      // to miss. While signing up, 409 offers a one-tap switch to login.
      AuthErrorDialog.show(
        context,
        e,
        onLoginInstead:
            _isSignup ? () => setState(() => _isSignup = false) : null,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.toString();
      });
      AuthErrorDialog.show(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Scaffold(
      backgroundColor: AppTheme.getBgPrimary(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: AppTheme.getTextPrimary(context)),
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: EdgeInsets.fromLTRB(24, 0, 24, bottomInset + 24),
            children: [
              Icon(Icons.workspace_premium_rounded,
                  color: AppTheme.getGold(context), size: 40),
              const SizedBox(height: 14),
              Text(
                _isSignup ? tr('joinRewards') : tr('welcomeBackClient'),
                style: AppTheme.displayFont.copyWith(
                  fontSize: 26,
                  color: AppTheme.getTextPrimary(context),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _isSignup
                    ? tr('joinRewardsSub').replaceAll('{salon}', _salonName)
                    : tr('signInClientSub').replaceAll('{salon}', _salonName),
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.getTextSecondary(context),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 22),
              _modeToggle(),
              const SizedBox(height: 20),
              if (_isSignup) ...[
                _field(_name, tr('fullName'), Icons.person_outline_rounded,
                    capitalize: true),
                const SizedBox(height: 14),
                _field(_phone, tr('phone'), Icons.phone_outlined,
                    keyboard: TextInputType.phone),
                const SizedBox(height: 14),
              ],
              _field(_email, tr('email'), Icons.mail_outline_rounded,
                  keyboard: TextInputType.emailAddress, isEmail: true),
              const SizedBox(height: 14),
              _passwordField(),
              if (_error != null) ...[
                const SizedBox(height: 14),
                _errorBanner(_error!),
              ],
              const SizedBox(height: 24),
              GoldButton(
                text: _submitting
                    ? '...'
                    : (_isSignup ? tr('createAccount') : tr('signIn')),
                expanded: true,
                enabled: !_submitting,
                onPressed: _submit,
              ),
              const SizedBox(height: 18),
              // Secondary paths: just check by phone, or keep browsing as guest.
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const GuestLoyaltyScreen()),
                  ),
                  child: Text(
                    tr('checkPointsByPhone'),
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.getTextSecondary(context),
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(
                    tr('continueAsGuest'),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.getGold(context),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modeToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.getBgGlass(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.getBorder(context)),
      ),
      child: Row(
        children: [
          _toggleHalf(tr('signIn'), !_isSignup, () {
            if (_isSignup) setState(() => _isSignup = false);
          }),
          _toggleHalf(tr('createAccount'), _isSignup, () {
            if (!_isSignup) setState(() => _isSignup = true);
          }),
        ],
      ),
    );
  }

  Widget _toggleHalf(String label, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: active ? AppTheme.getGold(context) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: active ? Colors.white : AppTheme.getTextSecondary(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController c,
    String label,
    IconData icon, {
    TextInputType keyboard = TextInputType.text,
    bool isEmail = false,
    bool capitalize = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.getBgGlass(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.getBorder(context)),
      ),
      child: TextFormField(
        controller: c,
        keyboardType: keyboard,
        textCapitalization:
            capitalize ? TextCapitalization.words : TextCapitalization.none,
        style: TextStyle(color: AppTheme.getTextPrimary(context), fontSize: 15),
        validator: (v) {
          if (v == null || v.trim().isEmpty) return tr('fieldRequired');
          if (isEmail && !v.contains('@')) return tr('invalidEmail');
          return null;
        },
        decoration: _decoration(label, icon),
      ),
    );
  }

  Widget _passwordField() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.getBgGlass(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.getBorder(context)),
      ),
      child: TextFormField(
        controller: _password,
        obscureText: _obscure,
        style: TextStyle(color: AppTheme.getTextPrimary(context), fontSize: 15),
        validator: (v) {
          if (v == null || v.isEmpty) return tr('fieldRequired');
          if (_isSignup && v.length < 6) return tr('passwordTooShort');
          return null;
        },
        decoration: _decoration(tr('password'), Icons.lock_outline_rounded)
            .copyWith(
          suffixIcon: IconButton(
            icon: Icon(
              _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: AppTheme.getTextTertiary(context),
              size: 20,
            ),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ),
      ),
    );
  }

  InputDecoration _decoration(String label, IconData icon) {
    return InputDecoration(
      hintText: label,
      hintStyle:
          TextStyle(color: AppTheme.getTextTertiary(context), fontSize: 14),
      prefixIcon: Padding(
        padding: const EdgeInsets.only(left: 14, right: 10),
        child: Icon(icon, color: AppTheme.getTextTertiary(context), size: 20),
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
      border: InputBorder.none,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  Widget _errorBanner(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.accentRed.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accentRed.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppTheme.accentRed, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 12, color: AppTheme.accentRed),
            ),
          ),
        ],
      ),
    );
  }
}
