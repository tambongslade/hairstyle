import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class GoldButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool expanded;
  final IconData? icon;
  final bool enabled;

  const GoldButton({
    super.key,
    required this.text,
    this.onPressed,
    this.expanded = false,
    this.icon,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final button = GestureDetector(
      onTap: enabled ? onPressed : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: enabled
                ? (isDark
                    ? [AppTheme.teal, AppTheme.tealLight]
                    : [AppTheme.navy, AppTheme.navyLight])
                : (isDark
                    ? [AppTheme.teal.withValues(alpha: 0.3), AppTheme.tealLight.withValues(alpha: 0.3)]
                    : [AppTheme.navy.withValues(alpha: 0.3), AppTheme.navyLight.withValues(alpha: 0.3)]),
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: enabled ? AppTheme.goldShadow : [],
        ),
        child: Row(
          mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 8),
            ],
            Text(
              text,
              style: TextStyle(
                color: enabled ? Colors.white : Colors.white.withValues(alpha: 0.5),
                fontWeight: FontWeight.w600,
                fontSize: 15,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );

    return button;
  }
}
