import 'package:flutter/material.dart';

import '../../data/models/transfer_task.dart';
import '../../data/models/volume.dart';
import '../theme/app_colors.dart';
import '../theme/app_type.dart';
import '../utils/byte_format.dart';
import 'dp_card.dart';
import 'dp_gauge.dart';
import 'dp_pill.dart';

/// Dashboard drive card: label, radial gauge, capacity and a browse hint.
class DriveGaugeCard extends StatelessWidget {
  const DriveGaugeCard({
    super.key,
    required this.volume,
    required this.onTap,
    this.selected = false,
    this.hint,
  });

  final Volume volume;
  final VoidCallback onTap;
  final bool selected;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final Color gaugeColor = volume.isCritical
        ? c.danger
        : (volume.isLow ? c.warning : c.primary);

    return DpCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      color: selected ? c.surface : c.surface,
      borderColor: selected ? c.primary.withValues(alpha: 0.55) : c.border,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                volume.isInternal
                    ? Icons.smartphone_rounded
                    : Icons.usb_rounded,
                size: 15,
                color: volume.isInternal ? c.textMuted : c.primary,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  volume.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.bodySmall(c.textMuted).copyWith(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (!volume.isConnected)
                Icon(Icons.link_off_rounded, size: 14, color: c.textFaint)
              else
                Icon(Icons.chevron_right_rounded, size: 15, color: c.textFaint),
            ],
          ),
          const SizedBox(height: Insets.md),
          DpGauge(
            value: volume.usedFraction,
            size: 88,
            color: gaugeColor,
            strokeWidth: 7,
            glow: selected,
            semanticLabel: '${volume.label} usage',
            child: GaugeLabel(
              percent: ByteFormat.percent(volume.usedFraction),
              caption: 'used',
              percentSize: 23,
            ),
          ),
          const SizedBox(height: Insets.md),
          Text(
            ByteFormat.format(volume.usedBytes),
            style: AppType.bodyMedium(c.text).copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
            ),
          ),
          Text(
            'of ${ByteFormat.format(volume.totalBytes)}',
            style: AppType.bodySmall(c.textFaint).copyWith(fontSize: 11),
          ),
          if (hint != null) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              hint!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppType.bodySmall(c.primary).copyWith(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Wide drive row used on the Drives tab.
class DriveListCard extends StatelessWidget {
  const DriveListCard({
    super.key,
    required this.volume,
    this.onTap,
    this.onEject,
    this.onDetails,
    this.active = false,
  });

  final Volume volume;
  final VoidCallback? onTap;
  final VoidCallback? onEject;
  final VoidCallback? onDetails;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final Color gaugeColor = volume.isCritical
        ? c.danger
        : (volume.isLow ? c.warning : c.primary);

    return DpCard(
      onTap: onTap,
      borderColor: active ? c.primary.withValues(alpha: 0.45) : c.border,
      padding: const EdgeInsets.all(Insets.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              FileTypeChipIcon(
                icon: volume.isInternal ? Icons.smartphone_rounded : Icons.usb_rounded,
                tint: volume.isInternal ? c.textMuted : c.primary,
                label: volume.fileSystemLabel,
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            volume.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppType.headlineSmall(c.text).copyWith(fontSize: 15),
                          ),
                        ),
                        if (volume.isConnected)
                          DpPill(
                            label: active ? 'Active' : 'Connected',
                            tone: PillTone.success,
                            dot: true,
                            dense: true,
                          )
                        else
                          const DpPill(label: 'Last seen', tone: PillTone.neutral, dense: true),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${volume.fileSystemLabel} • ${volume.protocolOrBus}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.labelCaps(c.textFaint).copyWith(fontSize: 10),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${ByteFormat.format(volume.usedBytes)} of ${ByteFormat.format(volume.totalBytes)} used',
                      style: AppType.monoSmall(c.textMuted).copyWith(fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Insets.sm),
              DpGauge(
                value: volume.usedFraction,
                size: 54,
                color: gaugeColor,
                strokeWidth: 5,
                child: Text(
                  ByteFormat.percent(volume.usedFraction),
                  style: AppType.monoSmall(c.text).copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.md),
          LinearMeter(value: volume.usedFraction, color: gaugeColor),
          const SizedBox(height: Insets.md),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  volume.isConnected
                      ? '${ByteFormat.format(volume.freeBytes)} free'
                      : 'Last used ${_lastSeenLabel(volume)}',
                  style: AppType.bodySmall(c.textMuted).copyWith(fontSize: 11.5),
                ),
              ),
              if (volume.isConnected && volume.isRemovable && onEject != null)
                _MiniAction(
                  icon: Icons.eject_rounded,
                  label: 'Eject',
                  onTap: onEject!,
                ),
              if (onDetails != null) ...<Widget>[
                const SizedBox(width: 6),
                _MiniAction(
                  icon: Icons.tune_rounded,
                  label: 'Manage',
                  onTap: onDetails!,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  static String _lastSeenLabel(Volume volume) {
    final DateTime? seen = volume.lastSeen;
    if (seen == null) return 'unknown';
    final Duration diff = DateTime.now().difference(seen);
    if (diff.inDays >= 1) return '${diff.inDays}d ago';
    if (diff.inHours >= 1) return '${diff.inHours}h ago';
    return '${diff.inMinutes}m ago';
  }
}

class FileTypeChipIcon extends StatelessWidget {
  const FileTypeChipIcon({
    super.key,
    required this.icon,
    required this.label,
    this.tint,
    this.size = 44,
  });

  final IconData icon;
  final String label;
  final Color? tint;
  final double size;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final Color color = tint ?? c.textMuted;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(icon, size: size * 0.42, color: color),
          const SizedBox(height: 1),
          Text(
            label,
            style: AppType.labelCaps(color).copyWith(fontSize: size * 0.17),
          ),
        ],
      ),
    );
  }
}

class _MiniAction extends StatelessWidget {
  const _MiniAction({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: <Widget>[
              Icon(icon, size: 14, color: c.textMuted),
              const SizedBox(width: 4),
              Text(
                label,
                style: AppType.bodySmall(c.textMuted)
                    .copyWith(fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Live transfer banner from the dashboard design: pulsing dot, route,
/// percentage, meter and a pause control.
class TransferBanner extends StatelessWidget {
  const TransferBanner({
    super.key,
    required this.task,
    this.onPause,
    this.onResume,
    this.onCancel,
    this.onTap,
  });

  final TransferTask task;
  final VoidCallback? onPause;
  final VoidCallback? onResume;
  final VoidCallback? onCancel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final bool paused = task.isPaused;

    return DpCard(
      onTap: onTap,
      padding: const EdgeInsets.all(Insets.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              _PulseDot(color: paused ? c.warning : c.primary, still: paused),
              const SizedBox(width: Insets.sm),
              Expanded(
                child: Text(
                  paused ? 'Transfer paused' : task.status.label,
                  style: AppType.headlineSmall(c.text).copyWith(fontSize: 14.5),
                ),
              ),
              Text(
                ByteFormat.percent(task.progress),
                style: AppType.monoSmall(c.primary).copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.md),
          LinearMeter(
            value: task.progress,
            color: paused ? c.warning : c.primary,
            height: 7,
            glow: !paused,
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      task.routeLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.bodySmall(c.textMuted).copyWith(fontSize: 12),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      <String>[
                        '${ByteFormat.format(task.doneBytes)} of ${ByteFormat.format(task.totalBytes)}',
                        if (task.bytesPerSecond > 0)
                          ByteFormat.speed(task.bytesPerSecond),
                        if (task.eta != null) '${ByteFormat.eta(task.eta)} left',
                      ].join(' • '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.labelCaps(c.textFaint).copyWith(fontSize: 9.5),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: paused ? onResume : onPause,
                style: TextButton.styleFrom(
                  foregroundColor: c.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  paused ? 'Resume' : 'Pause',
                  style: AppType.bodySmall(c.primary).copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              if (onCancel != null)
                IconButton(
                  onPressed: onCancel,
                  tooltip: 'Cancel transfer',
                  icon: const Icon(Icons.close_rounded, size: 16),
                  color: c.textFaint,
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                  padding: EdgeInsets.zero,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  const _PulseDot({required this.color, this.still = false});

  final Color color;
  final bool still;

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    if (!widget.still) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _PulseDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.still && _controller.isAnimating) {
      _controller.stop();
    } else if (!widget.still && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        final double opacity = widget.still
            ? 1
            : 0.45 + (_controller.value * 0.55);
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: opacity),
            shape: BoxShape.circle,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: widget.color.withValues(alpha: 0.35),
                blurRadius: 6,
                spreadRadius: 1,
              ),
            ],
          ),
        );
      },
    );
  }
}
