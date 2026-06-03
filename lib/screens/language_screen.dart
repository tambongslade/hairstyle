import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../l10n/app_locale.dart';
import '../services/storage_service.dart';

class LanguageScreen extends StatefulWidget {
  const LanguageScreen({super.key});

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen>
    with SingleTickerProviderStateMixin {
  String _selected = 'en';
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    AppLocale.instance.setLanguage(_selected);
    await StorageService.instance.saveLanguage(_selected);
    if (!mounted) return;
    // Onboarding marks itself complete when finished/skipped, then returns to
    // the root gate. Drive this through GoRouter so navigation stays in sync.
    context.go('/onboarding');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const Spacer(flex: 2),
                // Logo
                Image.asset(
                  'assets/logo.png',
                  width: 160,
                  height: 160,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 8),
                Text(
                  _selected == 'fr'
                      ? 'Essayage Virtuel & Réservation'
                      : 'Virtual Try-On & Booking',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(flex: 2),
                // Title
                Text(
                  _selected == 'fr'
                      ? 'Choisissez Votre Langue'
                      : 'Choose Your Language',
                  style: AppTheme.displayFont.copyWith(
                    fontSize: 24,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _selected == 'fr'
                      ? 'Sélectionnez votre langue préférée'
                      : 'Select your preferred language',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 32),
                // English option
                _LanguageOption(
                  code: 'EN',
                  name: 'English',
                  subtitle: 'Continue in English',
                  isSelected: _selected == 'en',
                  onTap: () => setState(() => _selected = 'en'),
                ),
                const SizedBox(height: 12),
                // French option
                _LanguageOption(
                  code: 'FR',
                  name: 'Français',
                  subtitle: 'Continuer en français',
                  isSelected: _selected == 'fr',
                  onTap: () => setState(() => _selected = 'fr'),
                ),
                const Spacer(flex: 3),
                // Continue button
                GestureDetector(
                  onTap: _continue,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.navy, AppTheme.navyLight],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: AppTheme.goldShadow,
                    ),
                    child: Center(
                      child: Text(
                        _selected == 'fr' ? 'Continuer' : 'Continue',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
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
}

class _LanguageOption extends StatelessWidget {
  final String code;
  final String name;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _LanguageOption({
    required this.code,
    required this.name,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.teal.withValues(alpha: 0.12) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppTheme.teal.withValues(alpha: 0.4)
                : Colors.grey.shade300,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.teal.withValues(alpha: 0.15)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? AppTheme.teal.withValues(alpha: 0.3)
                      : Colors.grey.shade300,
                ),
              ),
              child: Center(
                child: Text(
                  code,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? AppTheme.gold : Colors.grey.shade600,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? AppTheme.gold
                          : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppTheme.gold : Colors.transparent,
                border: Border.all(
                  color: isSelected ? AppTheme.gold : Colors.grey.shade400,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 14, color: Colors.black87)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
