import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_type.dart';

/// Bordered surface used by every panel in the app. Tapping is optional and
/// uses an InkWell so feedback stays inside the card radius.
class DpCard extends StatelessWidget {
  const DpCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Insets.lg),
    this.onTap,
    this.onLongPress,
    this.color,
    this.borderColor,
    this.radius = Radii.card,
    this.elevated = true,
    this.clip = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color? color;
  final Color? borderColor;
  final double radius;
  final bool elevated;
  final bool clip;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final Widget content = Padding(padding: padding, child: child);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? c.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? c.border),
        boxShadow: elevated
            ? <BoxShadow>[
                BoxShadow(
                  color: c.shadow,
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: clip ? Clip.antiAlias : Clip.none,
        child: onTap == null && onLongPress == null
            ? content
            : InkWell(
                onTap: onTap,
                onLongPress: onLongPress,
                borderRadius: BorderRadius.circular(radius),
                child: content,
              ),
      ),
    );
  }
}

/// Compact secondary surface for chips, inset fields and sub-cards.
class DpPanel extends StatelessWidget {
  const DpPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Insets.md),
    this.radius = Radii.md,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? c.surfaceAlt,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: c.border),
      ),
      child: child,
    );
  }
}

/// Section heading with an optional counter and trailing action, matching the
/// `Recent Files 7 ... By Date` rails in the design.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.count,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
    this.padding = const EdgeInsets.only(bottom: Insets.md),
  });

  final String title;
  final int? count;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return Padding(
      padding: padding,
      child: Row(
        children: <Widget>[
          Expanded(
            child: Row(
              children: <Widget>[
                Flexible(
                  child: Text(
                    title,
                    style: AppType.headlineSmall(c.text),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (count != null) ...<Widget>[
                  const SizedBox(width: Insets.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: c.surfaceSunken,
                      borderRadius: BorderRadius.circular(Radii.pill),
                    ),
                    child: Text(
                      '$count',
                      style: AppType.monoSmall(c.textMuted)
                          .copyWith(fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onAction != null)
            TextButton.icon(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: c.textMuted,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: actionIcon == null
                  ? const SizedBox.shrink()
                  : Icon(actionIcon, size: 16),
              label: Text(
                actionLabel ?? '',
                style: AppType.bodySmall(c.textMuted)
                    .copyWith(fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }
}

/// Full-width primary action with loading state. Used for destructive and
/// transfer confirmations.
class DpPrimaryButton extends StatelessWidget {
  const DpPrimaryButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.loading = false,
    this.destructive = false,
    this.expanded = true,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;
  final bool destructive;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final Widget child = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        if (loading)
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: c.onPrimary,
            ),
          )
        else if (icon != null)
          Icon(icon, size: 20),
        if (loading || icon != null) const SizedBox(width: Insets.sm),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppType.labelLarge(c.onPrimary),
          ),
        ),
      ],
    );

    final Widget button = FilledButton(
      onPressed: loading ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: destructive ? c.danger : c.primary,
      ),
      child: child,
    );

    return expanded ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// Neutral outlined action that never competes with the crimson primary.
class DpSecondaryButton extends StatelessWidget {
  const DpSecondaryButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.expanded = true,
    this.foreground,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool expanded;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final Widget button = OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: foreground ?? c.text,
        side: BorderSide(color: c.borderStrong),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 18),
            const SizedBox(width: Insets.sm),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppType.labelLarge(foreground ?? c.text),
            ),
          ),
        ],
      ),
    );
    return expanded ? SizedBox(width: double.infinity, child: button) : button;
  }
}
