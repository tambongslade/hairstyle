import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../l10n/app_locale.dart';
import '../../services/storage_service.dart';
import '../../widgets/gold_button.dart';

/// Modal sheet that captures the guest's name/phone/email and persists them
/// to [StorageService] so booking + try-on can both read from a single place.
class GuestInfoSheet extends StatefulWidget {
  final String? title;
  final String? subtitle;
  const GuestInfoSheet({super.key, this.title, this.subtitle});

  /// Convenience: show the sheet and resolve when the user saves (true) or
  /// dismisses (null/false).
  static Future<bool?> show(
    BuildContext context, {
    String? title,
    String? subtitle,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => GuestInfoSheet(title: title, subtitle: subtitle),
    );
  }

  @override
  State<GuestInfoSheet> createState() => _GuestInfoSheetState();
}

class _GuestInfoSheetState extends State<GuestInfoSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final s = StorageService.instance;
    _name = TextEditingController(text: s.guestName ?? '');
    _phone = TextEditingController(text: s.guestPhone ?? '');
    _email = TextEditingController(text: s.guestEmail ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    await StorageService.instance.saveGuestProfile(
      name: _name.text.trim(),
      phone: _phone.text.trim(),
      email: _email.text.trim(),
    );
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: AppTheme.getBgPrimary(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Form(
          key: _formKey,
          child: ListView(
            controller: scrollController,
            padding: EdgeInsets.fromLTRB(24, 14, 24, bottomInset + 24),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.getBorder(context),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                widget.title ?? 'Tell us about you',
                style: AppTheme.displayFont.copyWith(
                  fontSize: 22,
                  color: AppTheme.getTextPrimary(context),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.subtitle ??
                    'The salon needs these details to confirm your appointment.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.getTextSecondary(context),
                ),
              ),
              const SizedBox(height: 24),
              _field(_name, tr('fullName'), Icons.person_outline_rounded,
                  capitalize: true),
              const SizedBox(height: 14),
              _field(_phone, tr('phone'), Icons.phone_outlined,
                  keyboard: TextInputType.phone),
              const SizedBox(height: 14),
              _field(_email, tr('email'), Icons.mail_outline_rounded,
                  keyboard: TextInputType.emailAddress, isEmail: true),
              const SizedBox(height: 26),
              GoldButton(
                text: _saving ? '...' : tr('continueBtn'),
                expanded: true,
                enabled: !_saving,
                onPressed: _save,
              ),
            ],
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
        decoration: InputDecoration(
          hintText: label,
          hintStyle:
              TextStyle(color: AppTheme.getTextTertiary(context), fontSize: 14),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 14, right: 10),
            child:
                Icon(icon, color: AppTheme.getTextTertiary(context), size: 20),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }
}
