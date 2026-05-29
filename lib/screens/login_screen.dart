import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../l10n/app_locale.dart';
import '../services/auth_service.dart';
import '../services/api_client.dart';
import 'admin/admin_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _obscurePassword = true;
  bool _isLoading = false;
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await AuthService.instance.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        userType: 'admin',
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const AdminShell(),
          transitionsBuilder: (_, anim, _, child) {
            return FadeTransition(opacity: anim, child: child);
          },
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red.shade700),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('loginFailed')), backgroundColor: Colors.red.shade700),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _register() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _RegisterSheet(
        onRegistered: () {
          Navigator.of(ctx).pop();
          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  const AdminShell(),
              transitionsBuilder: (_, anim, _, child) =>
                  FadeTransition(opacity: anim, child: child),
              transitionDuration: const Duration(milliseconds: 400),
            ),
          );
        },
      ),
    );
  }

  void _showForgotPassword() {
    final resetEmailCtrl = TextEditingController();
    final resetFormKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) {
        bool isSending = false;
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(tr('forgotPasswordTitle'), style: const TextStyle(color: Colors.black87)),
              content: Form(
                key: resetFormKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(tr('forgotPasswordMsg'), style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: resetEmailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        hintText: tr('email'),
                        prefixIcon: Icon(Icons.mail_outline, color: Colors.grey.shade400, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return tr('fieldRequired');
                        if (!v.contains('@')) return tr('invalidEmail');
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(tr('cancel'), style: TextStyle(color: Colors.grey.shade600)),
                ),
                TextButton(
                  onPressed: isSending ? null : () async {
                    if (!resetFormKey.currentState!.validate()) return;
                    setDialogState(() => isSending = true);
                    try {
                      await AuthService.instance.forgotPassword(email: resetEmailCtrl.text.trim());
                      if (!ctx.mounted) return;
                      Navigator.of(ctx).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(tr('resetLinkSent')), backgroundColor: Colors.green.shade700),
                      );
                    } on ApiException catch (e) {
                      if (!ctx.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(e.message), backgroundColor: Colors.red.shade700),
                      );
                    } catch (e) {
                      if (!ctx.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(tr('resetFailed')), backgroundColor: Colors.red.shade700),
                      );
                    } finally {
                      if (ctx.mounted) setDialogState(() => isSending = false);
                    }
                  },
                  child: isSending
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(tr('sendResetLink'), style: const TextStyle(color: AppTheme.teal, fontWeight: FontWeight.w600)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 50),
              // Logo
              Center(
                child: Image.asset(
                  'assets/logo.png',
                  width: 130,
                  height: 130,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  tr('appTagline'),
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // Welcome text
              Text(
                tr('merchantLogin'),
                style: AppTheme.displayFont.copyWith(
                  fontSize: 26,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                tr('merchantSub'),
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 28),

              // Email field
              _buildLabel(tr('email')),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _emailController,
                hint: 'salon@business.com',
                icon: Icons.mail_outline,
                isEmail: true,
              ),
              const SizedBox(height: 20),

              // Password field
              _buildLabel(tr('password')),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _passwordController,
                hint: '••••••••',
                icon: Icons.lock_outline,
                isPassword: true,
              ),
              const SizedBox(height: 12),

              // Forgot password
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: _showForgotPassword,
                  child: Text(tr('forgotPassword'),
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.teal,
                          fontWeight: FontWeight.w500)),
                ),
              ),
              const SizedBox(height: 28),

              // Login button
              GestureDetector(
                onTap: _isLoading ? null : _login,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.navy, AppTheme.navyLight],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(color: AppTheme.navy.withValues(alpha: 0.25), blurRadius: 16, offset: const Offset(0, 4))],
                  ),
                  child: Center(
                    child: _isLoading
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(
                            tr('signInDashboard'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              const SizedBox(height: 8),

              // Sign up — shown to both customers and salon admins;
              // the registration sheet itself asks the user which type
              // of account to create.
              Center(
                child: GestureDetector(
                  onTap: _register,
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                      children: [
                        TextSpan(text: tr('noAccount')),
                        TextSpan(
                          text: tr('signUp'),
                          style: const TextStyle(
                              color: AppTheme.teal, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(text,
        style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w500, color: Colors.grey.shade700));
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    bool isEmail = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword && _obscurePassword,
        keyboardType: isEmail ? TextInputType.emailAddress : TextInputType.text,
        style: const TextStyle(color: Colors.black87, fontSize: 14),
        validator: (value) {
          if (value == null || value.trim().isEmpty) return tr('fieldRequired');
          if (isEmail && !value.contains('@')) return tr('invalidEmail');
          return null;
        },
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade400),
          prefixIcon: Icon(icon, color: Colors.grey.shade400, size: 20),
          suffixIcon: isPassword
              ? GestureDetector(
                  onTap: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  child: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: Colors.grey.shade400,
                    size: 20,
                  ),
                )
              : null,
          border: InputBorder.none,
          errorBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  Salon Registration Sheet
// ═══════════════════════════════════════════════════════

class _RegisterSheet extends StatefulWidget {
  /// Called when salon registration succeeds (caller routes to AdminShell).
  final VoidCallback onRegistered;
  const _RegisterSheet({required this.onRegistered});

  @override
  State<_RegisterSheet> createState() => _RegisterSheetState();
}

class _RegisterSheetState extends State<_RegisterSheet> {
  final _formKey = GlobalKey<FormState>();

  // Personal info
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  // Salon info
  final _salonNameCtrl = TextEditingController();
  final _salonLocationCtrl = TextEditingController();
  final _salonPhoneCtrl = TextEditingController();
  final _salonDescCtrl = TextEditingController();

  // Security
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  final _picker = ImagePicker();
  XFile? _logoFile;
  Uint8List? _logoBytes;

  int _currentStep = 1; // 1 = personal, 2 = salon, 3 = security
  bool _isLoading = false;
  bool _obscurePass = true;
  bool _obscureConfirm = true;

  static const _steps = [1, 2, 3];

  bool get _isLastStep => _currentStep == _steps.last;

  String get _ctaLabel {
    if (_isLastStep) return tr('registerBtn');
    return tr('continueBtn');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _salonNameCtrl.dispose();
    _salonLocationCtrl.dispose();
    _salonPhoneCtrl.dispose();
    _salonDescCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
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
      _logoFile = picked;
      _logoBytes = bytes;
    });
  }

  void _snack(String msg, {Color? color}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color ?? AppTheme.accentRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  bool _validatePersonalStep() {
    if (_nameCtrl.text.trim().isEmpty ||
        _emailCtrl.text.trim().isEmpty ||
        _phoneCtrl.text.trim().isEmpty) {
      _formKey.currentState!.validate();
      return false;
    }
    if (!_emailCtrl.text.contains('@')) {
      _formKey.currentState!.validate();
      return false;
    }
    return true;
  }

  bool _validateSalonStep() {
    if (_salonNameCtrl.text.trim().isEmpty) {
      _formKey.currentState!.validate();
      return false;
    }
    return true;
  }

  bool _validateSecurityStep() {
    if (_passCtrl.text.isEmpty || _confirmCtrl.text.isEmpty) {
      _formKey.currentState!.validate();
      return false;
    }
    if (_passCtrl.text.length < 8) {
      _snack(tr('min8chars'));
      return false;
    }
    if (_passCtrl.text != _confirmCtrl.text) {
      _snack(tr('passwordsDoNotMatch'));
      return false;
    }
    return true;
  }

  void _goNext() {
    if (_currentStep == 1) {
      if (!_validatePersonalStep()) return;
      setState(() => _currentStep = 2);
      return;
    }
    if (_currentStep == 2) {
      if (!_validateSalonStep()) return;
      setState(() => _currentStep = 3);
      return;
    }
    if (_currentStep == 3) {
      _submit();
    }
  }

  void _goBack() {
    if (_currentStep <= 1) return;
    setState(() => _currentStep = _currentStep - 1);
  }

  Future<void> _submit() async {
    if (!_validateSecurityStep()) return;

    setState(() => _isLoading = true);
    try {
      await AuthService.instance.registerAdmin(
        name: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
        phone: _phoneCtrl.text.trim(),
        salonName: _salonNameCtrl.text.trim(),
        salonLocation: _salonLocationCtrl.text.trim(),
        salonPhone: _salonPhoneCtrl.text.trim(),
        salonDescription: _salonDescCtrl.text.trim(),
        logo: _logoFile,
      );
      if (!mounted) return;
      widget.onRegistered();
    } on ApiException catch (e) {
      if (!mounted) return;
      _snack(e.message);
    } catch (_) {
      if (!mounted) return;
      _snack(tr('registerFailed'));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 4),
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tr('registerTitle'),
                              style: AppTheme.displayFont.copyWith(
                                fontSize: 24,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              tr('signInSub'),
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.close, size: 20, color: Colors.grey.shade600),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _buildStepIndicator(),
                ),

                const SizedBox(height: 24),

                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: EdgeInsets.fromLTRB(24, 0, 24, bottomInset + 24),
                    children: [
                      _buildStepContent(),

                      const SizedBox(height: 28),

                      GestureDetector(
                        onTap: _isLoading ? null : _goNext,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          width: double.infinity,
                          height: 54,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: _isLoading
                                  ? [Colors.grey.shade400, Colors.grey.shade400]
                                  : [AppTheme.navy, AppTheme.navyLight],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: _isLoading
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
                            child: _isLoading
                                ? const SizedBox(
                                    width: 22, height: 22,
                                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                                  )
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _ctaLabel,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                      if (!_isLastStep) ...[
                                        const SizedBox(width: 8),
                                        const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                                      ],
                                    ],
                                  ),
                          ),
                        ),
                      ),

                      if (_currentStep > 1) ...[
                        const SizedBox(height: 14),
                        Center(
                          child: GestureDetector(
                            onTap: _isLoading ? null : _goBack,
                            child: Text(
                              tr('back'),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 20),

                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            tr('termsNotice'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade400,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 1:
        return _buildPersonalStep();
      case 2:
        return _buildSalonStep();
      case 3:
        return _buildSecurityStep();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStepIndicator() {
    final entries = <_StepInfo>[
      _StepInfo(1, tr('personalInfo')),
      _StepInfo(2, tr('salonInfo')),
      _StepInfo(3, tr('security')),
    ];

    final widgets = <Widget>[];
    for (var i = 0; i < entries.length; i++) {
      final e = entries[i];
      widgets.add(_buildStepDot(e.step, e.label));
      if (i < entries.length - 1) {
        widgets.add(
          Expanded(
            child: Container(
              height: 2,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              color: _currentStep > e.step ? AppTheme.teal : Colors.grey.shade200,
            ),
          ),
        );
      }
    }
    return Row(children: widgets);
  }

  Widget _buildPersonalStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.teal.withValues(alpha: 0.15), AppTheme.navy.withValues(alpha: 0.08)],
              ),
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.teal.withValues(alpha: 0.3), width: 2),
            ),
            child: Icon(Icons.person_add_alt_1_rounded, size: 36, color: AppTheme.teal.withValues(alpha: 0.7)),
          ),
        ),
        const SizedBox(height: 28),

        _buildFieldLabel(tr('fullName')),
        const SizedBox(height: 8),
        _buildField(
          controller: _nameCtrl,
          hint: 'Amara Nkembe',
          icon: Icons.person_outline_rounded,
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 18),

        _buildFieldLabel(tr('email')),
        const SizedBox(height: 8),
        _buildField(
          controller: _emailCtrl,
          hint: 'amara@email.com',
          icon: Icons.mail_outline_rounded,
          keyboardType: TextInputType.emailAddress,
          isEmail: true,
        ),
        const SizedBox(height: 18),

        _buildFieldLabel(tr('phone')),
        const SizedBox(height: 8),
        _buildField(
          controller: _phoneCtrl,
          hint: '+237 6XX XXX XXX',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
        ),
      ],
    );
  }

  Widget _buildSalonStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(child: _buildLogoPicker()),
        const SizedBox(height: 24),

        _buildFieldLabel(tr('salonName')),
        const SizedBox(height: 8),
        _buildField(
          controller: _salonNameCtrl,
          hint: 'LIS Beauty',
          icon: Icons.storefront_outlined,
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 18),

        _buildFieldLabel('${tr('salonLocation')}  ·  ${tr('optional')}'),
        const SizedBox(height: 8),
        _buildField(
          controller: _salonLocationCtrl,
          hint: 'Douala, Akwa',
          icon: Icons.place_outlined,
          optional: true,
        ),
        const SizedBox(height: 18),

        _buildFieldLabel('${tr('salonPhone')}  ·  ${tr('optional')}'),
        const SizedBox(height: 8),
        _buildField(
          controller: _salonPhoneCtrl,
          hint: '+237 6XX XXX XXX',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
          optional: true,
        ),
        const SizedBox(height: 18),

        _buildFieldLabel('${tr('salonDescription')}  ·  ${tr('optional')}'),
        const SizedBox(height: 8),
        _buildField(
          controller: _salonDescCtrl,
          hint: tr('salonDescriptionOptional'),
          icon: Icons.description_outlined,
          optional: true,
          maxLines: 3,
        ),
      ],
    );
  }

  Widget _buildLogoPicker() {
    return GestureDetector(
      onTap: _pickLogo,
      child: Container(
        width: 110, height: 110,
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          shape: BoxShape.circle,
          border: Border.all(
            color: _logoBytes != null
                ? AppTheme.teal.withValues(alpha: 0.5)
                : Colors.grey.shade300,
            width: 2,
          ),
        ),
        child: ClipOval(
          child: _logoBytes != null
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.memory(_logoBytes!, fit: BoxFit.cover),
                    Positioned(
                      right: 4, bottom: 4,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppTheme.navy,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.edit, size: 12, color: Colors.white),
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_a_photo_outlined,
                        size: 30, color: Colors.grey.shade400),
                    const SizedBox(height: 6),
                    Text(
                      tr('tapToAddLogo'),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildSecurityStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.navy.withValues(alpha: 0.1), AppTheme.teal.withValues(alpha: 0.08)],
              ),
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.navy.withValues(alpha: 0.2), width: 2),
            ),
            child: Icon(Icons.shield_outlined, size: 36, color: AppTheme.navy.withValues(alpha: 0.6)),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            tr('secureYourAccount'),
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey.shade600),
          ),
        ),
        const SizedBox(height: 28),

        _buildFieldLabel(tr('password')),
        const SizedBox(height: 8),
        _buildField(
          controller: _passCtrl,
          hint: '8+ characters',
          icon: Icons.lock_outline_rounded,
          isPassword: true,
          obscure: _obscurePass,
          onToggleObscure: () => setState(() => _obscurePass = !_obscurePass),
        ),
        const SizedBox(height: 18),

        _buildFieldLabel(tr('confirmPassword')),
        const SizedBox(height: 8),
        _buildField(
          controller: _confirmCtrl,
          hint: 'Re-enter password',
          icon: Icons.lock_outline_rounded,
          isPassword: true,
          obscure: _obscureConfirm,
          onToggleObscure: () => setState(() => _obscureConfirm = !_obscureConfirm),
        ),

        const SizedBox(height: 16),

        _buildPasswordHint(tr('min8chars'), _passCtrl.text.length >= 8),
        _buildPasswordHint(tr('passwordsMatch'),
            _passCtrl.text.isNotEmpty && _passCtrl.text == _confirmCtrl.text),
      ],
    );
  }

  Widget _buildStepDot(int step, String label) {
    final isActive = _currentStep >= step;
    final isDone = _currentStep > step;
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: isActive ? AppTheme.teal : Colors.grey.shade100,
            shape: BoxShape.circle,
            border: Border.all(
              color: isActive ? AppTheme.teal : Colors.grey.shade300,
              width: 2,
            ),
          ),
          child: Center(
            child: isActive
                ? Icon(
                    isDone ? Icons.check_rounded : Icons.circle,
                    size: isDone ? 16 : 8,
                    color: Colors.white,
                  )
                : Text('$step', style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade400)),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: isActive ? AppTheme.teal : Colors.grey.shade400,
        )),
      ],
    );
  }

  Widget _buildFieldLabel(String text) {
    return Text(text, style: TextStyle(
      fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700, letterSpacing: 0.2,
    ));
  }

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isEmail = false,
    bool isPassword = false,
    bool obscure = false,
    bool optional = false,
    int maxLines = 1,
    VoidCallback? onToggleObscure,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword && obscure,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        maxLines: isPassword ? 1 : maxLines,
        onChanged: isPassword ? (_) => setState(() {}) : null,
        style: const TextStyle(color: Colors.black87, fontSize: 15),
        validator: (v) {
          if (optional) return null;
          if (v == null || v.trim().isEmpty) return tr('fieldRequired');
          if (isEmail && !v.contains('@')) return tr('invalidEmail');
          return null;
        },
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade400),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 14, right: 10),
            child: Icon(icon, color: Colors.grey.shade400, size: 20),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
          suffixIcon: isPassword
              ? GestureDetector(
                  onTap: onToggleObscure,
                  child: Icon(
                    obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: Colors.grey.shade400, size: 20,
                  ),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildPasswordHint(String text, bool satisfied) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(
            satisfied ? Icons.check_circle_rounded : Icons.circle_outlined,
            size: 16,
            color: satisfied ? AppTheme.accentGreen : Colors.grey.shade300,
          ),
          const SizedBox(width: 8),
          Text(text, style: TextStyle(
            fontSize: 12,
            color: satisfied ? AppTheme.accentGreen : Colors.grey.shade400,
          )),
        ],
      ),
    );
  }
}

class _StepInfo {
  final int step;
  final String label;
  const _StepInfo(this.step, this.label);
}

