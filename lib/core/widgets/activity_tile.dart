import 'package:flutter/material.dart';

import '../../data/models/activity_event.dart';
import '../theme/app_colors.dart';
import '../theme/app_type.dart';
import '../utils/byte_format.dart';
import '../utils/date_x.dart';
import 'dp_pill.dart';

/// Shared activity row used on the dashboard preview and the history screen.
class ActivityTile extends StatelessWidget {
  const ActivityTile({
    super.key,
    required this.event,
    this.onTap,
    this.showStatus = true,
    this.padding = const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
  });

  final ActivityEvent event;
  final VoidCallback? onTap;
  final bool showStatus;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final Color tint = event.isFailure ? c.danger : event.type.tint(c);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.md),
        child: Padding(
          padding: padding,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              IconTile(
                icon: event.type.icon,
                tint: tint,
                size: 38,
                radius: 12,
                iconSize: 18,
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      event.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.bodyMedium(c.text).copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      event.metaLine.isEmpty ? event.subtitle : event.metaLine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.monoSmall(c.textFaint).copyWith(fontSize: 10.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Insets.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    DateX.relative(event.timestamp),
                    style: AppType.bodySmall(c.textFaint).copyWith(fontSize: 10.5),
                  ),
                  if (showStatus) ...<Widget>[
                    const SizedBox(height: 4),
                    DpPill(
                      label: event.resolvedStatus,
                      tone: event.isFailure
                          ? PillTone.danger
                          : (event.type == ActivityType.eject ||
                                  event.type == ActivityType.cleanup
                              ? PillTone.success
                              : PillTone.neutral),
                      dense: true,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact telemetry cell used by the history summary strip.
class TelemetryCell extends StatelessWidget {
  const TelemetryCell({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.tint,
    this.caption,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color? tint;
  final String? caption;

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
              Icon(icon, size: 12, color: tint ?? c.textFaint),
              const SizedBox(width: 4),
            ],
            Text(
              label.toUpperCase(),
              style: AppType.labelCaps(c.textFaint).copyWith(fontSize: 9),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppType.metricMedium(tint ?? c.text).copyWith(fontSize: 17),
        ),
        if (caption != null)
          Text(
            caption!,
            style: AppType.bodySmall(c.textFaint).copyWith(fontSize: 9.5),
          ),
      ],
    );
  }
}

/// Small labelled size pair used in breakdown lists.
class BreakdownRow extends StatelessWidget {
  const BreakdownRow({
    super.key,
    required this.label,
    required this.bytes,
    required this.totalBytes,
    required this.color,
    this.icon,
    this.caption,
    this.onTap,
  });

  final String label;
  final int bytes;
  final int totalBytes;
  final Color color;
  final IconData? icon;
  final String? caption;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final double fraction = totalBytes <= 0 ? 0 : bytes / totalBytes;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: 15, color: color),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppType.bodySmall(c.text).copyWith(fontSize: 12.5),
                          ),
                        ),
                        Text(
                          ByteFormat.format(bytes),
                          style: AppType.monoSmall(c.textMuted).copyWith(fontSize: 11),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 34,
                          child: Text(
                            ByteFormat.percent(fraction),
                            textAlign: TextAlign.right,
                            style: AppType.monoSmall(c.textFaint).copyWith(fontSize: 10),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: fraction,
                        minHeight: 4,
                        backgroundColor: c.surfaceSunken,
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    ),
                    if (caption != null) ...<Widget>[
                      const SizedBox(height: 3),
                      Text(
                        caption!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.bodySmall(c.textFaint).copyWith(fontSize: 9.5),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
