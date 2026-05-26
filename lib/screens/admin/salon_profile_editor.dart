import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/app_theme.dart';
import '../../l10n/app_locale.dart';
import '../../services/admin_service.dart';
import '../../services/api_client.dart';
import '../../services/storage_service.dart';

class SalonProfileEditor extends StatefulWidget {
  const SalonProfileEditor({super.key});

  @override
  State<SalonProfileEditor> createState() => _SalonProfileEditorState();
}

class _SalonProfileEditorState extends State<SalonProfileEditor> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  final _picker = ImagePicker();

  String? _existingLogoUrl;
  XFile? _newLogo;
  Uint8List? _newLogoBytes;

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    AppLocale.instance.addListener(_onLocaleChange);
    _fetch();
  }

  @override
  void dispose() {
    AppLocale.instance.removeListener(_onLocaleChange);
    _nameCtrl.dispose();
    _locationCtrl.dispose();
    _phoneCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _onLocaleChange() {
    if (mounted) setState(() {});
  }

  Future<void> _fetch() async {
    try {
      final res = await AdminService.instance.getSalon();
      final data = res['data'] as Map<String, dynamic>? ?? res;
      _nameCtrl.text = data['name']?.toString() ?? '';
      _locationCtrl.text =
          (data['location'] ?? data['address'] ?? '').toString();
      _phoneCtrl.text = data['phone']?.toString() ?? '';
      _descCtrl.text = data['description']?.toString() ?? '';
      _existingLogoUrl = data['logoUrl']?.toString();
    } catch (_) {
      // Use empty fields as fallback
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickLogo() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() {
      _newLogo = picked;
      _newLogoBytes = bytes;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final res = await AdminService.instance.updateSalonWithLogo(
        logo: _newLogo,
        fields: {
          'name': _nameCtrl.text.trim(),
          'location': _locationCtrl.text.trim(),
          'phone': _phoneCtrl.text.trim(),
          'description': _descCtrl.text.trim(),
        },
      );

      // Update selected-salon cache so the customer-side salon card refreshes.
      final data = res['data'] as Map<String, dynamic>? ?? res;
      final id = data['id']?.toString();
      final name = data['name']?.toString();
      final logoUrl = data['logoUrl']?.toString();
      if (id != null && name != null && id.isNotEmpty && name.isNotEmpty) {
        await StorageService.instance
            .saveSelectedSalon(id: id, name: name, logoUrl: logoUrl);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('salonProfileSaved')),
          backgroundColor: AppTheme.accentGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError(tr('salonProfileSaveFailed'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppTheme.accentRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.getBgPrimary(context),
      appBar: AppBar(
        backgroundColor: AppTheme.getBgPrimary(context),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppTheme.getTextPrimary(context)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          tr('editSalonProfile'),
          style: TextStyle(
            color: AppTheme.getTextPrimary(context),
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  Center(child: _buildLogo()),
                  const SizedBox(height: 8),
                  Center(
                    child: GestureDetector(
                      onTap: _pickLogo,
                      child: Text(
                        _newLogoBytes != null || (_existingLogoUrl?.isNotEmpty ?? false)
                            ? tr('changeLogo')
                            : tr('tapToAddLogo'),
                        style: const TextStyle(
                          color: AppTheme.teal,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  _label(tr('salonName')),
                  const SizedBox(height: 8),
                  _field(
                    controller: _nameCtrl,
                    hint: 'LIS Beauty',
                    icon: Icons.storefront_outlined,
                    required: true,
                    capitalize: true,
                  ),
                  const SizedBox(height: 16),

                  _label(tr('salonLocation')),
                  const SizedBox(height: 8),
                  _field(
                    controller: _locationCtrl,
                    hint: 'Douala, Akwa',
                    icon: Icons.place_outlined,
                  ),
                  const SizedBox(height: 16),

                  _label(tr('salonPhone')),
                  const SizedBox(height: 8),
                  _field(
                    controller: _phoneCtrl,
                    hint: '+237 6XX XXX XXX',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),

                  _label(tr('salonDescription')),
                  const SizedBox(height: 8),
                  _field(
                    controller: _descCtrl,
                    hint: tr('salonDescriptionOptional'),
                    icon: Icons.description_outlined,
                    maxLines: 4,
                  ),
                  const SizedBox(height: 32),

                  GestureDetector(
                    onTap: _saving ? null : _save,
                    child: Container(
                      height: 54,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _saving
                              ? [Colors.grey.shade400, Colors.grey.shade400]
                              : [AppTheme.navy, AppTheme.navyLight],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: _saving
                            ? []
                            : [
                                BoxShadow(
                                  color: AppTheme.navy.withValues(alpha: 0.3),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                      ),
                      child: Center(
                        child: _saving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                tr('saveChanges'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildLogo() {
    final hasNew = _newLogoBytes != null;
    final fullExistingUrl = ApiClient.getImageUrl(_existingLogoUrl);
    final hasExisting = !hasNew && fullExistingUrl.isNotEmpty;

    return GestureDetector(
      onTap: _pickLogo,
      child: Container(
        width: 130,
        height: 130,
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          shape: BoxShape.circle,
          border: Border.all(
            color: hasNew
                ? AppTheme.teal.withValues(alpha: 0.6)
                : Colors.grey.shade300,
            width: 2,
          ),
        ),
        child: ClipOval(
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hasNew)
                Image.memory(_newLogoBytes!, fit: BoxFit.cover)
              else if (hasExisting)
                Image.network(
                  fullExistingUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _placeholder(),
                )
              else
                _placeholder(),
              Positioned(
                right: 6,
                bottom: 6,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.navy,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.edit, size: 14, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_a_photo_outlined, size: 34, color: Colors.grey.shade400),
          const SizedBox(height: 6),
          Text(
            tr('tapToAddLogo'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppTheme.getTextSecondary(context),
        letterSpacing: 0.2,
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    bool required = false,
    bool capitalize = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.getBgSecondary(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.getBorder(context)),
      ),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        textCapitalization:
            capitalize ? TextCapitalization.words : TextCapitalization.none,
        style: TextStyle(color: AppTheme.getTextPrimary(context), fontSize: 15),
        validator: (v) {
          if (!required) return null;
          if (v == null || v.trim().isEmpty) return tr('fieldRequired');
          return null;
        },
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: AppTheme.getTextTertiary(context)),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 14, right: 10),
            child: Icon(icon, color: AppTheme.getTextTertiary(context), size: 20),
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
