import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../l10n/app_locale.dart';
import '../../widgets/liquid_glass_navbar.dart';
import '../tryon_screen.dart';
import 'admin_dashboard.dart';
import 'admin_bookings.dart';
import 'admin_catalog.dart';
import 'admin_analytics.dart';
import 'admin_settings.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _currentIndex = 0;

  static const _outlinedIcons = [
    Icons.space_dashboard_outlined,
    Icons.event_note_outlined,
    Icons.style_outlined,
    Icons.analytics_outlined,
    Icons.tune_outlined,
  ];

  static const _filledIcons = [
    Icons.space_dashboard_rounded,
    Icons.event_note_rounded,
    Icons.style_rounded,
    Icons.analytics_rounded,
    Icons.tune_rounded,
  ];

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

  List<String> get _labels => [
    tr('adminDashboard'),
    tr('adminBookings'),
    tr('adminCatalog'),
    tr('adminAnalytics'),
    tr('adminSettings'),
  ];

  @override
  Widget build(BuildContext context) {
    final labels = _labels;
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
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => Scaffold(
                      backgroundColor: AppTheme.getBgPrimary(context),
                      appBar: AppBar(
                        backgroundColor: Colors.transparent,
                        elevation: 0,
                        leading: IconButton(
                          icon: Icon(Icons.arrow_back, color: AppTheme.getTextPrimary(context)),
                          onPressed: () => Navigator.pop(context),
                        ),
                        title: Text(tr('virtualTryOn'),
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.getTextPrimary(context))),
                        centerTitle: true,
                      ),
                      body: const SafeArea(child: TryOnScreen()),
                    ),
                  ),
                );
              },
              backgroundColor: AppTheme.getGold(context),
              elevation: 4,
              child: const Icon(Icons.content_cut_rounded, color: Colors.white, size: 24),
            )
          : null,
      bottomNavigationBar: LiquidGlassNavBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        tabs: List.generate(5, (i) => LiquidGlassTab(
          icon: _outlinedIcons[i],
          activeIcon: _filledIcons[i],
          label: labels[i],
        )),
      ),
    );
  }

  Widget _buildScreen() {
    switch (_currentIndex) {
      case 0:
        return const AdminDashboard(key: ValueKey('admin-dash'));
      case 1:
        return const AdminBookings(key: ValueKey('admin-book'));
      case 2:
        return const AdminCatalog(key: ValueKey('admin-catalog'));
      case 3:
        return const AdminAnalytics(key: ValueKey('admin-analytics'));
      case 4:
        return const AdminSettings(key: ValueKey('admin-settings'));
      default:
        return const AdminDashboard(key: ValueKey('admin-dash'));
    }
  }

}
