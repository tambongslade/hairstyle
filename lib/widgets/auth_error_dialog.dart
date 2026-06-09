import 'package:flutter/material.dart';
import '../l10n/app_locale.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import 'gold_button.dart';

/// A blocking modal that surfaces sign-up / sign-in failures so the user
/// actually sees them — most importantly the "email already registered"
/// case, where a fleeting snackbar would leave the user confused.
///
/// Handles both NestJS error shapes routed through [ApiException]:
///   • 409 Conflict  → friendly "email taken" copy + optional "Log in instead".
///   • 400 Bad Request → the validation message(s) (already newline-joined).
///   • anything else / network → a generic "please try again" message.
class AuthErrorDialog {
  /// Show the modal for [error]. When the failure is an already-registered
  /// email (409) and [onLoginInstead] is provided, the modal offers a
  /// shortcut that closes itself and runs the callback (e.g. switch to login).
  static Future<void> show(
    BuildContext context,
    Object error, {
    VoidCallback? onLoginInstead,
  }) {
    final info = _resolve(error);
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _AuthErrorDialogBody(
        info: info,
        onLoginInstead: info.isEmailTaken ? onLoginInstead : null,
      ),
    );
  }

  static _ErrorInfo _resolve(Object error) {
    if (error is ApiException) {
      if (error.statusCode == 409) {
        return _ErrorInfo(
          title: tr('signUpFailedTitle'),
          message: tr('emailAlreadyRegistered'),
          isEmailTaken: true,
        );
      }
      if (error.statusCode == 400) {
        final msg = error.message.trim();
        return _ErrorInfo(
          title: tr('signUpFailedTitle'),
          message: msg.isEmpty ? tr('genericSignupError') : msg,
        );
      }
      // 401 / 403 / 404 / 5xx — don't leak raw server internals; keep it generic.
      return _ErrorInfo(
        title: tr('signUpFailedTitle'),
        message: tr('genericSignupError'),
      );
    }
    // Network failure, JSON decode error, etc.
    return _ErrorInfo(
      title: tr('signUpFailedTitle'),
      message: tr('genericSignupError'),
    );
  }
}

class _ErrorInfo {
  final String title;
  final String message;
  final bool isEmailTaken;
  const _ErrorInfo({
    required this.title,
    required this.message,
    this.isEmailTaken = false,
  });
}

class _AuthErrorDialogBody extends StatelessWidget {
  final _ErrorInfo info;
  final VoidCallback? onLoginInstead;

  const _AuthErrorDialogBody({required this.info, this.onLoginInstead});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.getBgPrimary(context),
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppTheme.accentRed.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                info.isEmailTaken
                    ? Icons.mark_email_unread_outlined
                    : Icons.error_outline_rounded,
                color: AppTheme.accentRed,
                size: 28,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              info.title,
              textAlign: TextAlign.center,
              style: AppTheme.displayFont.copyWith(
                fontSize: 20,
                color: AppTheme.getTextPrimary(context),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              info.message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: AppTheme.getTextSecondary(context),
              ),
            ),
            const SizedBox(height: 24),
            if (onLoginInstead != null) ...[
              GoldButton(
                text: tr('logInInstead'),
                expanded: true,
                onPressed: () {
                  Navigator.of(context).pop();
                  onLoginInstead!.call();
                },
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  tr('dismiss'),
                  style: TextStyle(color: AppTheme.getTextSecondary(context)),
                ),
              ),
            ] else
              GoldButton(
                text: tr('ok'),
                expanded: true,
                onPressed: () => Navigator.of(context).pop(),
              ),
          ],
        ),
      ),
    );
  }
}
