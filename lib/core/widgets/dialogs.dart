import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_type.dart';

/// Confirmation dialog. Destructive actions get a crimson confirm button and a
/// short explanation of what cannot be undone.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool destructive = false,
  IconData? icon,
}) async {
  final AppColors c = context.colors;
  final bool? result = await showDialog<bool>(
    context: context,
    builder: (BuildContext ctx) => AlertDialog(
      icon: icon == null
          ? null
          : Icon(icon, color: destructive ? c.danger : c.primary, size: 26),
      title: Text(title),
      content: Text(message, style: AppType.bodyMedium(c.textMuted)),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: destructive ? c.danger : c.primary,
          ),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Single-field prompt used for rename and new-folder. Returns null on cancel.
Future<String?> showTextPrompt(
  BuildContext context, {
  required String title,
  required String message,
  String initialValue = '',
  String hint = '',
  String confirmLabel = 'Save',
  String? Function(String value)? validator,
  IconData? icon,
  bool selectBaseName = false,
}) async {
  final AppColors c = context.colors;
  final TextEditingController controller = TextEditingController(text: initialValue);
  if (selectBaseName && initialValue.isNotEmpty) {
    final int dot = initialValue.lastIndexOf('.');
    controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: dot > 0 ? dot : initialValue.length,
    );
  }
  String? error;
  final String? result = await showDialog<String>(
    context: context,
    builder: (BuildContext ctx) => StatefulBuilder(
      builder: (BuildContext ctx, void Function(VoidCallback) setState) {
        void submit() {
          final String? problem =
              validator?.call(controller.text) ??
                  (controller.text.trim().isEmpty ? 'Enter a name' : null);
          if (problem != null) {
            setState(() => error = problem);
            return;
          }
          Navigator.of(ctx).pop(controller.text.trim());
        }

        return AlertDialog(
          icon: icon == null ? null : Icon(icon, color: c.primary, size: 26),
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (message.isNotEmpty) ...<Widget>[
                Text(message, style: AppType.bodyMedium(c.textMuted)),
                const SizedBox(height: Insets.md),
              ],
              TextField(
                controller: controller,
                autofocus: true,
                onSubmitted: (_) => submit(),
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  hintText: hint,
                  errorText: error,
                  prefixIcon: icon == null ? null : const Icon(Icons.drive_file_rename_outline_rounded, size: 18),
                ),
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(onPressed: submit, child: Text(confirmLabel)),
          ],
        );
      },
    ),
  );
  controller.dispose();
  return result;
}

/// Password prompt for the encryption vault. Kept separate so the value is
/// never logged or kept in app state.
Future<String?> showPassphrasePrompt(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Encrypt',
  bool confirmTwice = false,
  bool destructive = false,
}) async {
  final AppColors c = context.colors;
  final TextEditingController first = TextEditingController();
  final TextEditingController second = TextEditingController();
  bool obscure = true;
  String? error;

  final String? result = await showDialog<String>(
    context: context,
    builder: (BuildContext ctx) => StatefulBuilder(
      builder: (BuildContext ctx, void Function(VoidCallback) setState) {
        void submit() {
          final String value = first.text;
          if (value.length < 8) {
            setState(() => error = 'Use at least 8 characters');
            return;
          }
          if (confirmTwice && second.text != value) {
            setState(() => error = 'Passphrases do not match');
            return;
          }
          Navigator.of(ctx).pop(value);
        }

        return AlertDialog(
          icon: Icon(Icons.lock_outline_rounded, color: c.primary, size: 26),
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(message, style: AppType.bodyMedium(c.textMuted)),
              const SizedBox(height: Insets.md),
              TextField(
                controller: first,
                autofocus: true,
                obscureText: obscure,
                decoration: InputDecoration(
                  hintText: 'Passphrase',
                  errorText: error,
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => obscure = !obscure),
                    icon: Icon(
                      obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                      size: 18,
                    ),
                  ),
                ),
              ),
              if (confirmTwice) ...<Widget>[
                const SizedBox(height: Insets.sm),
                TextField(
                  controller: second,
                  obscureText: obscure,
                  onSubmitted: (_) => submit(),
                  decoration: const InputDecoration(hintText: 'Repeat passphrase'),
                ),
              ],
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: submit,
              style: FilledButton.styleFrom(
                backgroundColor: destructive ? c.danger : c.primary,
              ),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    ),
  );

  first.dispose();
  second.dispose();
  return result;
}

/// Floating, icon-led confirmation. Used after every completed local action.
void showAppToast(
  BuildContext context,
  String message, {
  IconData icon = Icons.check_circle_rounded,
  Color? iconColor,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final AppColors c = context.colors;
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      duration: const Duration(seconds: 3),
      content: Row(
        children: <Widget>[
          Icon(icon, size: 18, color: iconColor ?? c.success),
          const SizedBox(width: Insets.sm),
          Expanded(
            child: Text(
              message,
              style: AppType.bodySmall(c.onObsidian).copyWith(fontSize: 13),
            ),
          ),
        ],
      ),
      action: actionLabel == null || onAction == null
          ? null
          : SnackBarAction(label: actionLabel, onPressed: onAction),
    ),
  );
}
