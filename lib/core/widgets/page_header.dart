import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_type.dart';

/// App wordmark: crimson squircle holding a drive glyph plus a pulse tick.
/// Drawn in code so it stays sharp at any density and needs no asset pipeline.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 34, this.showWordmark = true});

  final double size;
  final bool showWordmark;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[c.primary, c.primaryDeep],
            ),
            borderRadius: BorderRadius.circular(size * 0.32),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: c.primary.withValues(alpha: 0.28),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              Icon(
                Icons.storage_rounded,
                color: c.onPrimary,
                size: size * 0.52,
              ),
              Positioned(
                right: size * 0.16,
                top: size * 0.18,
                child: Container(
                  width: size * 0.16,
                  height: size * 0.16,
                  decoration: BoxDecoration(
                    color: c.onPrimary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showWordmark) ...<Widget>[
          const SizedBox(width: 9),
          Text(
            'DrivePulse',
            style: AppType.headlineMedium(c.text).copyWith(
              fontSize: 19,
              letterSpacing: -0.4,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }
}

/// Shared page header: optional back affordance, title block and actions.
/// Also the place where the "local only" promise is quietly reinforced by the
/// offline shield on the dashboard.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.showBack = false,
    this.onBack,
    this.actions = const <Widget>[],
    this.leading,
    this.padding = const EdgeInsets.fromLTRB(
      Insets.screen,
      Insets.sm,
      Insets.screen,
      Insets.md,
    ),
  });

  final String title;
  final String? subtitle;
  final bool showBack;
  final VoidCallback? onBack;
  final List<Widget> actions;
  final Widget? leading;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return Padding(
      padding: padding,
      child: Row(
        children: <Widget>[
          if (showBack) ...<Widget>[
            _HeaderIcon(
              icon: Icons.arrow_back_rounded,
              onTap: onBack ?? () => Navigator.of(context).maybePop(),
              tooltip: 'Back',
            ),
            const SizedBox(width: Insets.sm),
          ],
          if (leading != null) ...<Widget>[
            leading!,
            const SizedBox(width: Insets.sm),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.headlineLarge(c.text).copyWith(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.bodySmall(c.textMuted),
                  ),
              ],
            ),
          ),
          for (final Widget action in actions) ...<Widget>[
            const SizedBox(width: Insets.sm),
            action,
          ],
        ],
      ),
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({required this.icon, required this.onTap, this.tooltip});

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(13),
          child: Ink(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: c.border),
            ),
            child: Icon(icon, size: 19, color: c.text),
          ),
        ),
      ),
    );
  }
}

/// Circular bordered header action used on every screen.
class HeaderAction extends StatelessWidget {
  const HeaderAction({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.badge = false,
    this.color,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final bool badge;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(13),
          child: Ink(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: c.border),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                Icon(icon, size: 19, color: color ?? c.text),
                if (badge)
                  Positioned(
                    right: 9,
                    top: 9,
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: c.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Caps content width on tablets/desktop so forms never stretch edge to edge.
class ScreenBody extends StatelessWidget {
  const ScreenBody({
    super.key,
    required this.child,
    this.maxWidth = Insets.maxContent,
    this.padding = const EdgeInsets.symmetric(horizontal: Insets.screen),
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Responsive column count helper used by card grids.
int responsiveColumns(double width) {
  if (width >= 1000) return 4;
  if (width >= 760) return 3;
  if (width >= 520) return 3;
  return 2;
}
