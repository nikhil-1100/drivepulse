import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_type.dart';

enum PillTone { neutral, primary, success, warning, danger, dark }

/// Status chip used for protocol tags, health, read-only flags and file types.
class DpPill extends StatelessWidget {
  const DpPill({
    super.key,
    required this.label,
    this.icon,
    this.tone = PillTone.neutral,
    this.dot = false,
    this.monospace = false,
    this.dense = false,
  });

  final String label;
  final IconData? icon;
  final PillTone tone;
  final bool dot;
  final bool monospace;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final (Color bg, Color fg, Color border) = switch (tone) {
      PillTone.primary => (c.primarySoft, c.primary, c.primary.withValues(alpha: 0.35)),
      PillTone.success => (c.successSoft, c.success, c.success.withValues(alpha: 0.3)),
      PillTone.warning => (c.warningSoft, c.warning, c.warning.withValues(alpha: 0.3)),
      PillTone.danger => (c.dangerSoft, c.danger, c.danger.withValues(alpha: 0.35)),
      PillTone.dark => (c.obsidian, c.onObsidian, c.obsidian),
      PillTone.neutral => (c.surfaceAlt, c.textMuted, c.border),
    };

    final TextStyle style = monospace
        ? AppType.labelCaps(fg).copyWith(fontSize: dense ? 9.5 : 10.5)
        : AppType.bodySmall(fg).copyWith(
            fontSize: dense ? 10.5 : 12,
            fontWeight: FontWeight.w600,
          );

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 7 : 9,
        vertical: dense ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(Radii.pill),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (dot) ...<Widget>[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
          ],
          if (icon != null) ...<Widget>[
            Icon(icon, size: dense ? 11 : 13, color: fg),
            const SizedBox(width: 4),
          ],
          Text(label, style: style),
        ],
      ),
    );
  }
}

/// Square icon tile with a soft tint, used on quick actions and file chips.
class IconTile extends StatelessWidget {
  const IconTile({
    super.key,
    required this.icon,
    this.tint,
    this.size = 40,
    this.iconSize = 20,
    this.radius = 14,
    this.filled = false,
  });

  final IconData icon;
  final Color? tint;
  final double size;
  final double iconSize;
  final double radius;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final Color color = tint ?? c.textMuted;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: filled ? color : color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Icon(icon, size: iconSize, color: filled ? Colors.white : color),
    );
  }
}

/// Tactile icon key used by the dashboard's quick-action grid.
class QuickActionTile extends StatelessWidget {
  const QuickActionTile({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.accent,
    this.emphasized = false,
    this.badge,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color? accent;
  final bool emphasized;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final Color color = accent ?? (emphasized ? c.primary : c.textMuted);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.card),
        child: Ink(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(Radii.card),
            border: Border.all(color: c.border),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Insets.sm,
              vertical: Insets.md,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                IconTile(
                  icon: icon,
                  tint: color,
                  size: 42,
                  radius: 15,
                  iconSize: 21,
                ),
                const SizedBox(height: Insets.sm),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.bodySmall(c.text).copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                if (badge != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(badge!, style: AppType.labelCaps(c.textFaint)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Uppercase monospace caption used above metrics.
class MicroLabel extends StatelessWidget {
  const MicroLabel(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: AppType.labelCaps(color ?? context.colors.textMuted),
    );
  }
}
