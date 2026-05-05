import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum ToastType { success, info, booking, error }

/// Professional animated toast overlay — replaces default SnackBar.
/// Slides in from the top with a blurred glass background, icon, and auto-dismiss.
class AppToast {
  static OverlayEntry? _currentEntry;

  static void show(
    BuildContext context, {
    required String message,
    String? subtitle,
    ToastType type = ToastType.success,
    Duration duration = const Duration(seconds: 3),
    VoidCallback? onTap,
  }) {
    // Dismiss any existing toast
    _currentEntry?.remove();
    _currentEntry = null;

    final overlay = Overlay.of(context);
    final topPadding = MediaQuery.of(context).padding.top;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _ToastWidget(
        message: message,
        subtitle: subtitle,
        type: type,
        duration: duration,
        topPadding: topPadding,
        onTap: onTap,
        onDismiss: () {
          entry.remove();
          if (_currentEntry == entry) _currentEntry = null;
        },
      ),
    );

    _currentEntry = entry;
    overlay.insert(entry);
  }
}

class _ToastWidget extends StatefulWidget {
  final String message;
  final String? subtitle;
  final ToastType type;
  final Duration duration;
  final double topPadding;
  final VoidCallback? onTap;
  final VoidCallback onDismiss;

  const _ToastWidget({
    required this.message,
    this.subtitle,
    required this.type,
    required this.duration,
    required this.topPadding,
    this.onTap,
    required this.onDismiss,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
      reverseDuration: const Duration(milliseconds: 300),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeIn,
    ));

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward();

    // Auto-dismiss
    Future.delayed(widget.duration, () {
      if (mounted) _dismiss();
    });
  }

  void _dismiss() {
    _controller.reverse().then((_) {
      if (mounted) widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = _getTypeConfig();

    return Positioned(
      top: widget.topPadding + 8,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: GestureDetector(
            onTap: () {
              widget.onTap?.call();
              _dismiss();
            },
            onVerticalDragUpdate: (details) {
              if (details.primaryDelta != null && details.primaryDelta! < -4) {
                _dismiss();
              }
            },
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: config.bgColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: config.borderColor, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: config.shadowColor,
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                      spreadRadius: -2,
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Icon container
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: config.iconBgColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(config.icon,
                          color: config.iconColor, size: 20),
                    ),
                    const SizedBox(width: 14),
                    // Text content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.message,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: config.textColor,
                              height: 1.2,
                            ),
                          ),
                          if (widget.subtitle != null) ...[
                            const SizedBox(height: 3),
                            Text(
                              widget.subtitle!,
                              style: TextStyle(
                                fontSize: 12,
                                color: config.subtextColor,
                                height: 1.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Dismiss hint
                    Icon(Icons.close_rounded,
                        size: 16, color: config.subtextColor),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  _ToastConfig _getTypeConfig() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    switch (widget.type) {
      case ToastType.success:
        return _ToastConfig(
          icon: Icons.check_circle_rounded,
          iconColor: const Color(0xFF34C759),
          iconBgColor: const Color(0xFF34C759).withValues(alpha: 0.15),
          bgColor: isDark
              ? const Color(0xFF1A2E1A)
              : Colors.white,
          borderColor: const Color(0xFF34C759).withValues(alpha: isDark ? 0.3 : 0.2),
          shadowColor: const Color(0xFF34C759).withValues(alpha: 0.15),
          textColor: isDark ? Colors.white : const Color(0xFF1A1A1A),
          subtextColor: isDark
              ? Colors.white.withValues(alpha: 0.6)
              : const Color(0xFF666666),
        );
      case ToastType.info:
        return _ToastConfig(
          icon: Icons.info_rounded,
          iconColor: AppTheme.accentBlue,
          iconBgColor: AppTheme.accentBlue.withValues(alpha: 0.15),
          bgColor: isDark
              ? const Color(0xFF1A1E2E)
              : Colors.white,
          borderColor: AppTheme.accentBlue.withValues(alpha: isDark ? 0.3 : 0.2),
          shadowColor: AppTheme.accentBlue.withValues(alpha: 0.15),
          textColor: isDark ? Colors.white : const Color(0xFF1A1A1A),
          subtextColor: isDark
              ? Colors.white.withValues(alpha: 0.6)
              : const Color(0xFF666666),
        );
      case ToastType.booking:
        return _ToastConfig(
          icon: Icons.calendar_today_rounded,
          iconColor: AppTheme.teal,
          iconBgColor: AppTheme.teal.withValues(alpha: 0.15),
          bgColor: isDark
              ? const Color(0xFF1A2E2A)
              : Colors.white,
          borderColor: AppTheme.teal.withValues(alpha: isDark ? 0.3 : 0.2),
          shadowColor: AppTheme.teal.withValues(alpha: 0.2),
          textColor: isDark ? Colors.white : const Color(0xFF1A1A1A),
          subtextColor: isDark
              ? Colors.white.withValues(alpha: 0.6)
              : const Color(0xFF666666),
        );
      case ToastType.error:
        return _ToastConfig(
          icon: Icons.error_rounded,
          iconColor: AppTheme.accentRed,
          iconBgColor: AppTheme.accentRed.withValues(alpha: 0.15),
          bgColor: isDark
              ? const Color(0xFF2E1A1A)
              : Colors.white,
          borderColor: AppTheme.accentRed.withValues(alpha: isDark ? 0.3 : 0.2),
          shadowColor: AppTheme.accentRed.withValues(alpha: 0.15),
          textColor: isDark ? Colors.white : const Color(0xFF1A1A1A),
          subtextColor: isDark
              ? Colors.white.withValues(alpha: 0.6)
              : const Color(0xFF666666),
        );
    }
  }
}

class _ToastConfig {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final Color bgColor;
  final Color borderColor;
  final Color shadowColor;
  final Color textColor;
  final Color subtextColor;

  const _ToastConfig({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.bgColor,
    required this.borderColor,
    required this.shadowColor,
    required this.textColor,
    required this.subtextColor,
  });
}
