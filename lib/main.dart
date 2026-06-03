import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';
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
import 'screens/onboarding_screen.dart';
import 'screens/admin/admin_shell.dart';
import 'screens/guest/guest_shell.dart';
import 'services/storage_service.dart';
import 'services/api_client.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Web: use clean `/c/...` URLs instead of `/#/c/...`. No-op on other
  // platforms.
  usePathUrlStrategy();
  await StorageService.instance.init();

  // Restore saved language
  final savedLang = StorageService.instance.savedLanguage;
  if (savedLang != null) {
    AppLocale.instance.setLanguage(savedLang);
  }

  runApp(const FitApp());
}

/// Single source of truth for app routes.
GoRouter buildRouter() {
  return GoRouter(
    navigatorKey: ApiClient.navigatorKey,
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const _RootGate(),
      ),
      // First-run onboarding carousel. Reached from the language screen and,
      // on completion, routes back to the root gate.
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      // Guest entry — salon shares this link with a client.
      GoRoute(
        path: '/c/:salonId',
        builder: (context, state) {
          final salonId = state.pathParameters['salonId'] ?? '';
          return _GuestEntry(salonId: salonId);
        },
      ),
      // Salon-owner login. Kept under /admin so customer login can't be reached
      // by accident.
      GoRoute(
        path: '/admin',
        builder: (context, state) {
          if (StorageService.instance.isLoggedIn &&
              StorageService.instance.isAdmin) {
            return const AdminShell();
          }
          return const LoginScreen();
        },
      ),
      // Legacy alias — ApiClient's 401 redirect uses this on older builds.
      GoRoute(
        path: '/login',
        redirect: (_, _) => '/admin',
      ),
    ],
  );
}

class FitApp extends StatefulWidget {
  const FitApp({super.key});

  @override
  State<FitApp> createState() => _FitAppState();
}

class _FitAppState extends State<FitApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = buildRouter();
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

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'LIS Beauty',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: AppLocale.instance.themeMode,
      routerConfig: _router,
    );
  }
}

/// Root landing — decides where to send the user when they hit `/`.
/// Onboarding first; otherwise a small landing page explaining how to enter.
class _RootGate extends StatelessWidget {
  const _RootGate();

  @override
  Widget build(BuildContext context) {
    final storage = StorageService.instance;
    debugPrint('[App] Root gate — onboarding: ${storage.hasCompletedOnboarding}, '
        'isLoggedIn: ${storage.isLoggedIn}, userType: ${storage.userType}');

    if (!storage.hasCompletedOnboarding) {
      return const LanguageScreen();
    }
    if (storage.isLoggedIn && storage.isAdmin) {
      return const AdminShell();
    }
    return const _GuestLanding();
  }
}

/// Resolves /c/:salonId — persists the salon id, then mounts the guest shell.
/// We persist before mounting so the shell's children can read salonId from
/// [StorageService] without prop drilling.
class _GuestEntry extends StatefulWidget {
  final String salonId;
  const _GuestEntry({required this.salonId});

  @override
  State<_GuestEntry> createState() => _GuestEntryState();
}

class _GuestEntryState extends State<_GuestEntry> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _persistSalonId();
  }

  Future<void> _persistSalonId() async {
    final storage = StorageService.instance;
    // Mark onboarding as done so a returning guest doesn't see it again.
    if (!storage.hasCompletedOnboarding) {
      await storage.setOnboardingComplete();
    }
    if (storage.selectedSalonId != widget.salonId) {
      // The catalogue load will replace name/logo with the real values.
      await storage.saveSelectedSalon(id: widget.salonId, name: '');
    }
    if (mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return Scaffold(
        backgroundColor: AppTheme.getBgPrimary(context),
        body: Center(
          child: CircularProgressIndicator(
            color: AppTheme.getGold(context),
            strokeWidth: 2,
          ),
        ),
      );
    }
    return const GuestShell();
  }
}

/// What `/` shows once onboarding is done and the user isn't an admin —
/// a short "you need a salon link" explainer with a discreet admin entry.
class _GuestLanding extends StatelessWidget {
  const _GuestLanding();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.getBgPrimary(context),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('assets/logo.png', width: 120, height: 120),
                const SizedBox(height: 12),
                Text('LIS Beauty',
                    style: AppTheme.displayFont.copyWith(
                      fontSize: 28,
                      color: AppTheme.getTextPrimary(context),
                    )),
                const SizedBox(height: 8),
                Text(
                  'Open a salon catalogue link to browse styles, book, or try a look on.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.getTextSecondary(context),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 40),
                TextButton(
                  onPressed: () => context.go('/admin'),
                  child: Text(
                    'Salon owner? Sign in →',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.getGold(context),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Authenticated customer shell. Kept reachable in case a customer token still
/// exists; not wired to a route by default in salon-first mode.
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
