import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_type.dart';

/// Shared modal sheet with grabber, title row and safe-area padding.
Future<T?> showDpSheet<T>(
  BuildContext context, {
  required Widget child,
  bool isScrollControlled = true,
  bool padded = true,
}) {
  final AppColors c = context.colors;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    backgroundColor: Colors.transparent,
    barrierColor: c.obsidian.withValues(alpha: 0.38),
    builder: (BuildContext ctx) => Padding(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        bottom: 12,
        top: MediaQuery.viewInsetsOf(ctx).top,
      ),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 560,
            maxHeight: MediaQuery.sizeOf(ctx).height * 0.88,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(Radii.sheet),
              border: Border.all(color: c.border),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: c.shadow,
                  blurRadius: 32,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const SizedBox(height: 8),
                Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: c.borderStrong,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Flexible(
                  child: padded
                      ? Padding(
                          padding: const EdgeInsets.fromLTRB(
                            Insets.lg,
                            Insets.md,
                            Insets.lg,
                            Insets.lg,
                          ),
                          child: child,
                        )
                      : child,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class SheetHeader extends StatelessWidget {
  const SheetHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.padding = const EdgeInsets.only(bottom: Insets.md),
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(title, style: AppType.headlineMedium(c.text)),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: AppType.bodySmall(c.textMuted)),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// One row inside an actions sheet: icon, label, optional helper text and a
/// destructive tint.
class SheetAction extends StatelessWidget {
  const SheetAction({
    super.key,
    required this.icon,
    required this.label,
    this.description,
    this.onTap,
    this.destructive = false,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String? description;
  final VoidCallback? onTap;
  final bool destructive;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final Color color = destructive ? c.danger : c.text;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Insets.sm,
            vertical: 10,
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: destructive ? c.dangerSoft : c.surfaceAlt,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                    color: destructive
                        ? c.danger.withValues(alpha: 0.25)
                        : c.border,
                  ),
                ),
                child: Icon(icon, size: 18, color: destructive ? c.danger : c.textMuted),
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      label,
                      style: AppType.bodyMedium(color).copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    if (description != null)
                      Text(
                        description!,
                        style: AppType.bodySmall(c.textFaint).copyWith(fontSize: 11.5),
                      ),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}

/// Metric block used inside detail sheets: label above, tabular value below.
class DetailMetric extends StatelessWidget {
  const DetailMetric({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.valueColor,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: 12, color: c.textFaint),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                label.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.labelCaps(c.textFaint).copyWith(fontSize: 9.5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppType.monoSmall(valueColor ?? c.text).copyWith(fontSize: 12.5),
        ),
      ],
    );
  }
}
