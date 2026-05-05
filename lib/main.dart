import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'l10n/app_locale.dart';
import 'screens/home_screen.dart';
import 'screens/tryon_screen.dart';
import 'screens/booking_screen.dart';
import 'screens/loyalty_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/language_screen.dart';
import 'widgets/liquid_glass_navbar.dart';
import 'screens/login_screen.dart';
import 'screens/admin/admin_shell.dart';
import 'services/storage_service.dart';
import 'services/api_client.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StorageService.instance.init();

  // Restore saved language
  final savedLang = StorageService.instance.savedLanguage;
  if (savedLang != null) {
    AppLocale.instance.setLanguage(savedLang);
  }

  runApp(const FitApp());
}

class FitApp extends StatefulWidget {
  const FitApp({super.key});

  @override
  State<FitApp> createState() => _FitAppState();
}

class _FitAppState extends State<FitApp> {
  @override
  void initState() {
    super.initState();
    AppLocale.instance.addListener(_onLocaleChanged);
  }

  @override
  void dispose() {
    AppLocale.instance.removeListener(_onLocaleChanged);
    super.dispose();
  }

  void _onLocaleChanged() {
    setState(() {});
  }

  Widget _getStartScreen() {
    final storage = StorageService.instance;

    debugPrint('[App] Startup check — onboarding: ${storage.hasCompletedOnboarding}, '
        'isLoggedIn: ${storage.isLoggedIn}, userType: ${storage.userType}, '
        'hasToken: ${storage.accessToken != null}');

    // First time: show language picker + onboarding
    if (!storage.hasCompletedOnboarding) {
      debugPrint('[App] → Showing LanguageScreen (first time)');
      return const LanguageScreen();
    }

    // Already logged in: go straight to the right shell
    if (storage.isLoggedIn) {
      return storage.isAdmin ? const AdminShell() : const MainShell();
    }

    // Onboarding done but not logged in: show login
    return const LoginScreen();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LIS Beauty',
      navigatorKey: ApiClient.navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: AppLocale.instance.themeMode,
      home: _getStartScreen(),
      routes: {
        '/login': (_) => const LoginScreen(),
      },
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  void _switchTab(int index) {
    if (index != _currentIndex) {
      setState(() => _currentIndex = index);
    }
  }

  @override
  void initState() {
    super.initState();
    AppLocale.instance.addListener(_rebuild);
  }

  @override
  void dispose() {
    AppLocale.instance.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.getBgPrimary(context),
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.03),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          child: _buildScreen(),
        ),
      ),
      bottomNavigationBar: LiquidGlassNavBar(
        currentIndex: _currentIndex,
        onTap: _switchTab,
        tabs: [
          LiquidGlassTab(icon: Icons.cottage_outlined, activeIcon: Icons.cottage_rounded, label: tr('tabHome')),
          LiquidGlassTab(icon: Icons.auto_fix_high_outlined, activeIcon: Icons.auto_fix_high_rounded, label: tr('tabTryOn')),
          LiquidGlassTab(icon: Icons.event_note_outlined, activeIcon: Icons.event_note_rounded, label: tr('tabBook')),
          LiquidGlassTab(icon: Icons.workspace_premium_outlined, activeIcon: Icons.workspace_premium_rounded, label: tr('tabLoyalty')),
          LiquidGlassTab(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: tr('tabProfile')),
        ],
      ),
    );
  }

  Widget _buildScreen() {
    switch (_currentIndex) {
      case 0:
        return HomeScreen(key: const ValueKey('home'), onTabSwitch: _switchTab);
      case 1:
        return const TryOnScreen(key: ValueKey('tryon'));
      case 2:
        return const BookingScreen(key: ValueKey('book'));
      case 3:
        return const LoyaltyScreen(key: ValueKey('loyalty'));
      case 4:
        return const ProfileScreen(key: ValueKey('profile'));
      default:
        return HomeScreen(key: const ValueKey('home'), onTabSwitch: _switchTab);
    }
  }

}
