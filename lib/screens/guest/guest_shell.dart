import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../l10n/app_locale.dart';
import '../../widgets/liquid_glass_navbar.dart';
import '../booking_screen.dart';
import '../tryon_screen.dart';
import 'catalogue_screen.dart';

/// Bottom-nav shell shown to a guest who entered via /c/:salonId.
/// Slimmer than [MainShell] — no loyalty, no profile.
class GuestShell extends StatefulWidget {
  const GuestShell({super.key});

  @override
  State<GuestShell> createState() => _GuestShellState();
}

class _GuestShellState extends State<GuestShell> {
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
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.03),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          child: _buildScreen(),
        ),
      ),
      bottomNavigationBar: LiquidGlassNavBar(
        currentIndex: _currentIndex,
        onTap: _switchTab,
        tabs: [
          LiquidGlassTab(
            icon: Icons.cottage_outlined,
            activeIcon: Icons.cottage_rounded,
            label: tr('tabHome'),
          ),
          LiquidGlassTab(
            icon: Icons.auto_fix_high_outlined,
            activeIcon: Icons.auto_fix_high_rounded,
            label: tr('tabTryOn'),
          ),
          LiquidGlassTab(
            icon: Icons.event_note_outlined,
            activeIcon: Icons.event_note_rounded,
            label: tr('tabBook'),
          ),
        ],
      ),
    );
  }

  Widget _buildScreen() {
    switch (_currentIndex) {
      case 1:
        return const TryOnScreen(key: ValueKey('g-tryon'), guestMode: true);
      case 2:
        return const BookingScreen(key: ValueKey('g-book'), guestMode: true);
      case 0:
      default:
        return CatalogueScreen(
            key: const ValueKey('g-catalogue'), onTabSwitch: _switchTab);
    }
  }
}
