import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_type.dart';
import 'dp_card.dart';

/// Friendly, actionable empty state. Every list in the app has one so a fresh
/// install never looks broken.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: Insets.xl,
            vertical: compact ? Insets.xl : Insets.xxl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: c.surfaceAlt,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: c.border),
                ),
                child: Icon(icon, size: 28, color: c.textMuted),
              ),
              const SizedBox(height: Insets.lg),
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppType.headlineSmall(c.text),
              ),
              const SizedBox(height: Insets.xs),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppType.bodyMedium(c.textMuted),
              ),
              if (actionLabel != null && onAction != null) ...<Widget>[
                const SizedBox(height: Insets.lg),
                SizedBox(
                  width: 220,
                  child: DpPrimaryButton(label: actionLabel!, onPressed: onAction),
                ),
              ],
              if (secondaryLabel != null && onSecondary != null) ...<Widget>[
                const SizedBox(height: Insets.sm),
                TextButton(
                  onPressed: onSecondary,
                  child: Text(secondaryLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Small inline banner for permission hints, demo mode and recoverable errors.
class InfoBanner extends StatelessWidget {
  const InfoBanner({
    super.key,
    required this.message,
    this.icon = Icons.info_outline_rounded,
    this.tone = BannerTone.neutral,
    this.actionLabel,
    this.onAction,
    this.onDismiss,
  });

  final String message;
  final IconData icon;
  final BannerTone tone;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final Color color = switch (tone) {
      BannerTone.neutral => c.textMuted,
      BannerTone.success => c.success,
      BannerTone.warning => c.warning,
      BannerTone.primary => c.primary,
      BannerTone.danger => c.danger,
    };
    final Color background = switch (tone) {
      BannerTone.neutral => c.surfaceAlt,
      BannerTone.success => c.successSoft,
      BannerTone.warning => c.warningSoft,
      BannerTone.primary => c.primarySoft,
      BannerTone.danger => c.dangerSoft,
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 17, color: color),
          const SizedBox(width: Insets.sm),
          Expanded(
            child: Text(
              message,
              style: AppType.bodySmall(c.text).copyWith(height: 1.35),
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: color,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 28),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(actionLabel!, style: AppType.bodySmall(color).copyWith(fontWeight: FontWeight.w700)),
            ),
          if (onDismiss != null)
            IconButton(
              onPressed: onDismiss,
              icon: const Icon(Icons.close_rounded, size: 16),
              color: color,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              padding: EdgeInsets.zero,
            ),
        ],
      ),
    );
  }
}

enum BannerTone { neutral, success, warning, primary, danger }
