import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_type.dart';

/// Radial capacity gauge from the design system.
///
/// Starts at 12 o'clock and sweeps clockwise with rounded caps. When the value
/// crosses into the warning band the caller passes a crimson [color]; the
/// optional [glow] adds the instrument-panel bloom seen on hardware cards.
class DpGauge extends StatelessWidget {
  const DpGauge({
    super.key,
    required this.value,
    required this.size,
    required this.color,
    this.trackColor,
    this.strokeWidth = 7,
    this.child,
    this.glow = false,
    this.semanticLabel,
  });

  final double value;
  final double size;
  final Color color;
  final Color? trackColor;
  final double strokeWidth;
  final Widget? child;
  final bool glow;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return Semantics(
      label: semanticLabel,
      value: '${(value.clamp(0.0, 1.0) * 100).round()} percent',
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            CustomPaint(
              size: Size.square(size),
              painter: _GaugePainter(
                value: value.clamp(0.0, 1.0),
                color: color,
                trackColor: trackColor ?? c.gaugeTrack,
                strokeWidth: strokeWidth,
                glow: glow,
              ),
            ),
            ?child,
          ],
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter({
    required this.value,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
    required this.glow,
  });

  final double value;
  final Color color;
  final Color trackColor;
  final double strokeWidth;
  final bool glow;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double radius = (size.shortestSide - strokeWidth) / 2;

    final Paint track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, track);

    if (value <= 0) return;

    final Paint progress = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final double sweep = 2 * math.pi * value;
    final Rect rect = Rect.fromCircle(center: center, radius: radius);

    if (glow) {
      final Paint bloom = Paint()
        ..color = color.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth + 4
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawArc(rect, -math.pi / 2, sweep, false, bloom);
    }

    canvas.drawArc(rect, -math.pi / 2, sweep, false, progress);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) =>
      old.value != value ||
      old.color != color ||
      old.trackColor != trackColor ||
      old.strokeWidth != strokeWidth ||
      old.glow != glow;
}

/// Linear meter shared by transfer banners and partition split bars.
class LinearMeter extends StatelessWidget {
  const LinearMeter({
    super.key,
    required this.value,
    required this.color,
    this.height = 6,
    this.trackColor,
    this.radius,
    this.glow = false,
  });

  final double value;
  final Color color;
  final double height;
  final Color? trackColor;
  final double? radius;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final double r = radius ?? height / 2;
    return ClipRRect(
      borderRadius: BorderRadius.circular(r),
      child: SizedBox(
        height: height,
        child: Stack(
          children: <Widget>[
            Container(color: trackColor ?? c.gaugeTrack),
            FractionallySizedBox(
              widthFactor: value.clamp(0.0, 1.0),
              child: AnimatedContainer(
                duration: DpDurations.base,
                decoration: BoxDecoration(
                  color: color,
                  boxShadow: glow
                      ? <BoxShadow>[
                          BoxShadow(
                            color: color.withValues(alpha: 0.4),
                            blurRadius: 8,
                          ),
                        ]
                      : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Multi-segment meter used for used / system / free splits.
class SegmentMeter extends StatelessWidget {
  const SegmentMeter({
    super.key,
    required this.segments,
    this.height = 8,
    this.gap = 2,
  });

  final List<(double, Color)> segments;
  final double height;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final List<(double, Color)> visible =
        segments.where(((double, Color) s) => s.$1 > 0).toList(growable: false);
    if (visible.isEmpty) {
      return Container(
        height: height,
        decoration: BoxDecoration(
          color: c.gaugeTrack,
          borderRadius: BorderRadius.circular(height / 2),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: SizedBox(
        height: height,
        child: Row(
          children: <Widget>[
            for (int i = 0; i < visible.length; i++) ...<Widget>[
              if (i > 0) SizedBox(width: gap),
              Expanded(
                flex: math.max(1, (visible[i].$1 * 1000).round()),
                child: ColoredBox(color: visible[i].$2),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Centre label for gauges: big tabular percentage plus a small caption.
class GaugeLabel extends StatelessWidget {
  const GaugeLabel({
    super.key,
    required this.percent,
    this.caption = 'used',
    this.color,
    this.percentSize = 22,
  });

  final String percent;
  final String caption;
  final Color? color;
  final double percentSize;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          percent,
          style: AppType.headlineLarge(color ?? c.text).copyWith(
            fontSize: percentSize,
            height: 1.1,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          caption,
          style: AppType.bodySmall(c.textFaint).copyWith(fontSize: 10.5),
        ),
      ],
    );
  }
}
