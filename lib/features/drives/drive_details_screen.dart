import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routing.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_type.dart';
import '../../core/utils/byte_format.dart';
import '../../core/utils/date_x.dart';
import '../../core/utils/file_kind.dart';
import '../../core/widgets/activity_tile.dart';
import '../../core/widgets/dialogs.dart';
import '../../core/widgets/dp_card.dart';
import '../../core/widgets/dp_gauge.dart';
import '../../core/widgets/dp_pill.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/page_header.dart';
import '../../data/models/clean_up_report.dart';
import '../../data/models/drive_health.dart';
import '../../data/models/storage_breakdown.dart';
import '../../data/models/transfer_task.dart';
import '../../data/models/volume.dart';
import '../../data/services/transfer_controller.dart';
import '../../data/state/app_state.dart';

class DriveDetailsScreen extends StatefulWidget {
  const DriveDetailsScreen({super.key, required this.volume});

  final Volume volume;

  @override
  State<DriveDetailsScreen> createState() => _DriveDetailsScreenState();
}

class _DriveDetailsScreenState extends State<DriveDetailsScreen> {
  bool _benchmarking = false;
  bool _scanning = false;
  CleanUpReport? _report;

  Volume get _volume {
    final AppState app = context.read<AppState>();
    for (final Volume volume in app.volumes) {
      if (volume.id == widget.volume.id) return volume;
    }
    return widget.volume;
  }

  Future<void> _benchmark() async {
    setState(() => _benchmarking = true);
    try {
      final DriveHealth health =
          await context.read<AppState>().benchmark(_volume);
      if (!mounted) return;
      showAppToast(
        context,
        'Read ${health.readLabel} • write ${health.writeLabel}',
        icon: Icons.speed_rounded,
      );
    } catch (error) {
      if (!mounted) return;
      showAppToast(
        context,
        '$error',
        icon: Icons.error_outline_rounded,
        iconColor: context.colors.danger,
      );
    } finally {
      if (mounted) setState(() => _benchmarking = false);
    }
  }

  Future<void> _scanStorage() async {
    setState(() => _scanning = true);
    try {
      final CleanUpReport? report =
          await context.read<AppState>().scanCleanUp(_volume);
      if (!mounted) return;
      setState(() => _report = report);
      if (report != null && report.truncated) {
        showAppToast(
          context,
          'Scan stopped at the safety limit; totals are partial.',
          icon: Icons.info_outline_rounded,
        );
      }
    } catch (error) {
      if (!mounted) return;
      showAppToast(
        context,
        '$error',
        icon: Icons.error_outline_rounded,
        iconColor: context.colors.danger,
      );
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _eject() async {
    if (!_volume.isRemovable) {
      showAppToast(
        context,
        'Internal storage cannot be ejected.',
        icon: Icons.info_outline_rounded,
      );
      return;
    }
    final bool confirmed = await showConfirmDialog(
      context,
      title: 'Safely remove ${_volume.label}?',
      message: 'Make sure no transfer is running and no other app is using this drive.',
      confirmLabel: 'Eject drive',
      destructive: true,
      icon: Icons.eject_rounded,
    );
    if (!confirmed || !mounted) return;
    try {
      await context.read<AppState>().eject(_volume);
      if (!mounted) return;
      Navigator.of(context).pop();
      showAppToast(context, '${_volume.label} safely removed');
    } catch (error) {
      if (!mounted) return;
      showAppToast(
        context,
        '$error',
        icon: Icons.error_outline_rounded,
        iconColor: context.colors.danger,
      );
    }
  }

  Future<void> _formatInfo() async {
    await showConfirmDialog(
      context,
      title: 'Format is handled by the system',
      message:
          'Android and iOS do not allow third-party apps to format removable media. '
          'Open the system storage settings to format this drive. DrivePulse will pick '
          'it up again as soon as it is remounted.',
      confirmLabel: 'Got it',
      cancelLabel: 'Close',
      icon: Icons.info_outline_rounded,
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final AppState app = context.watch<AppState>();
    final TransferController transfers = context.watch<TransferController>();
    final Volume volume = _volume;
    final DriveHealth health = app.healthOf(volume);
    final bool tested = health.status != HealthStatus.unknown;
    final List<TransferTask> related = transfers.tasks
        .where((TransferTask t) =>
            t.targetLabel == volume.label || t.sourceLabel == volume.label)
        .take(3)
        .toList(growable: false);

    return Scaffold(
      backgroundColor: c.canvas,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            ScreenBody(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  PageHeader(
                    title: 'Drive details',
                    subtitle: volume.kind.label,
                    showBack: true,
                    padding: const EdgeInsets.fromLTRB(0, Insets.md, 0, Insets.md),
                    actions: <Widget>[
                      HeaderAction(
                        icon: Icons.settings_rounded,
                        tooltip: 'Settings',
                        onTap: () => AppRoutes.settings(context),
                      ),
                    ],
                  ),
                  _HeroPanel(volume: volume, health: health, tested: tested),
                  const SizedBox(height: Insets.lg),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: QuickActionTile(
                          label: 'Browse',
                          icon: Icons.folder_open_rounded,
                          onTap: () => AppRoutes.browse(context, volume: volume),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: QuickActionTile(
                          label: _benchmarking ? 'Testing' : 'Benchmark',
                          icon: Icons.speed_rounded,
                          onTap: _benchmarking ? () {} : _benchmark,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: QuickActionTile(
                          label: 'Clean up',
                          icon: Icons.cleaning_services_rounded,
                          onTap: () => AppRoutes.cleanup(context, volume: volume),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: QuickActionTile(
                          label: 'Eject',
                          icon: Icons.eject_rounded,
                          accent: c.danger,
                          onTap: _eject,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Insets.xl),
                  SectionHeader(
                    title: 'Storage breakdown',
                    actionLabel: _report == null ? 'Scan' : 'Clean up',
                    actionIcon: _report == null
                        ? Icons.radar_rounded
                        : Icons.cleaning_services_rounded,
                    onAction: _scanning
                        ? null
                        : () {
                            if (_report == null) {
                              _scanStorage();
                            } else {
                              AppRoutes.cleanup(context, volume: volume);
                            }
                          },
                  ),
                  DpCard(
                    child: _scanning
                        ? Column(
                            children: <Widget>[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  minHeight: 6,
                                  backgroundColor: c.surfaceSunken,
                                  valueColor: AlwaysStoppedAnimation<Color>(c.primary),
                                ),
                              ),
                              const SizedBox(height: Insets.md),
                              Text(
                                'Scanning ${volume.label}… ${app.scanProgress > 0 ? '${app.scanProgress} items' : ''}',
                                style: AppType.bodySmall(c.textMuted),
                              ),
                            ],
                          )
                        : _report == null
                            ? Column(
                                children: <Widget>[
                                  Icon(Icons.pie_chart_outline_rounded,
                                      size: 28, color: c.textFaint),
                                  const SizedBox(height: Insets.sm),
                                  Text(
                                    'Scan this drive to see exactly what is using space.',
                                    textAlign: TextAlign.center,
                                    style: AppType.bodySmall(c.textMuted),
                                  ),
                                  const SizedBox(height: Insets.md),
                                  DpSecondaryButton(
                                    label: 'Scan storage',
                                    icon: Icons.radar_rounded,
                                    onPressed: _scanStorage,
                                  ),
                                ],
                              )
                            : _Breakdown(report: _report!, volume: volume),
                  ),
                  const SizedBox(height: Insets.xl),
                  SectionHeader(
                    title: 'Health & specs',
                    actionLabel: _benchmarking ? 'Testing…' : 'Re-test',
                    actionIcon: Icons.speed_rounded,
                    onAction: _benchmarking ? null : _benchmark,
                  ),
                  DpCard(
                    child: Column(
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            IconTile(
                              icon: Icons.monitor_heart_outlined,
                              tint: tested
                                  ? (health.status == HealthStatus.healthy
                                      ? c.success
                                      : (health.status == HealthStatus.warning
                                          ? c.warning
                                          : c.danger))
                                  : c.textMuted,
                              size: 38,
                              radius: 12,
                            ),
                            const SizedBox(width: Insets.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    tested ? health.status.label : 'Not tested',
                                    style: AppType.headlineSmall(c.text)
                                        .copyWith(fontSize: 14),
                                  ),
                                  Text(
                                    tested
                                        ? 'Measured ${DateX.relative(health.checkedAt)}'
                                        : 'Run a local benchmark to estimate drive health',
                                    style: AppType.bodySmall(c.textMuted)
                                        .copyWith(fontSize: 11.5),
                                  ),
                                ],
                              ),
                            ),
                            if (tested)
                              DpPill(
                                label: '${health.healthPercent}%',
                                tone: health.status == HealthStatus.healthy
                                    ? PillTone.success
                                    : (health.status == HealthStatus.warning
                                        ? PillTone.warning
                                        : PillTone.danger),
                                dense: true,
                                monospace: true,
                              ),
                          ],
                        ),
                        const SizedBox(height: Insets.md),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: _Spec(
                                label: 'Read peak',
                                value: tested ? health.readLabel : '—',
                              ),
                            ),
                            Expanded(
                              child: _Spec(
                                label: 'Write peak',
                                value: tested ? health.writeLabel : '—',
                              ),
                            ),
                            Expanded(
                              child: _Spec(
                                label: 'Latency',
                                value: tested
                                    ? '${health.latencyMs.toStringAsFixed(1)} ms'
                                    : '—',
                              ),
                            ),
                          ],
                        ),
                        if (tested && health.notes.isNotEmpty) ...<Widget>[
                          const SizedBox(height: Insets.md),
                          InfoBanner(
                            message: health.notes.join(' '),
                            tone: BannerTone.neutral,
                            icon: Icons.science_outlined,
                          ),
                        ],
                        const SizedBox(height: Insets.lg),
                        _SpecRow(label: 'Volume label', value: volume.label),
                        _SpecRow(label: 'File system', value: volume.fileSystemLabel),
                        _SpecRow(label: 'Interface', value: volume.protocolOrBus),
                        _SpecRow(
                          label: 'Serial number',
                          value: volume.serial.isEmpty ? 'Not exposed' : volume.serial,
                          mono: true,
                        ),
                        _SpecRow(label: 'Mount point', value: volume.mountLabel, mono: true),
                        _SpecRow(
                          label: 'Capacity',
                          value:
                              '${ByteFormat.format(volume.totalBytes)} • ${ByteFormat.format(volume.freeBytes)} free',
                        ),
                        _SpecRow(
                          label: 'Last seen',
                          value: volume.lastSeen == null
                              ? 'Connected now'
                              : DateX.full(volume.lastSeen!),
                        ),
                        if (volume.isReadOnly)
                          const Padding(
                            padding: EdgeInsets.only(top: Insets.md),
                            child: InfoBanner(
                              message:
                                  'This volume is mounted read-only. Copy operations '
                                  'will fail until the write-protect switch or system '
                                  'permission is changed.',
                              tone: BannerTone.warning,
                              icon: Icons.lock_outline_rounded,
                            ),
                          ),
                        const SizedBox(height: Insets.lg),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: DpSecondaryButton(
                                label: 'Format',
                                icon: Icons.restart_alt_rounded,
                                onPressed: _formatInfo,
                              ),
                            ),
                            const SizedBox(width: Insets.sm),
                            Expanded(
                              child: DpSecondaryButton(
                                label: 'Eject',
                                icon: Icons.eject_rounded,
                                onPressed: volume.isRemovable ? _eject : null,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Insets.xl),
                  if (related.isNotEmpty) ...<Widget>[
                    SectionHeader(
                      title: 'Recent transfers',
                      actionLabel: 'View all',
                      onAction: () => AppRoutes.transfers(context),
                    ),
                    DpCard(
                      padding: const EdgeInsets.symmetric(horizontal: Insets.sm),
                      child: Column(
                        children: <Widget>[
                          for (final TransferTask task in related)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: <Widget>[
                                  IconTile(
                                    icon: task.direction == TransferDirection.move
                                        ? Icons.drive_file_move_outline
                                        : Icons.swap_horiz_rounded,
                                    tint: c.primary,
                                    size: 34,
                                    radius: 11,
                                    iconSize: 17,
                                  ),
                                  const SizedBox(width: Insets.sm),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Text(
                                          task.label,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppType.bodyMedium(c.text)
                                              .copyWith(fontSize: 12.5),
                                        ),
                                        Text(
                                          '${ByteFormat.format(task.totalBytes)} • ${DateX.relative(task.createdAt)}',
                                          style: AppType.monoSmall(c.textFaint)
                                              .copyWith(fontSize: 10),
                                        ),
                                      ],
                                    ),
                                  ),
                                  DpPill(
                                    label: task.status.label,
                                    tone: task.status == TransferStatus.completed
                                        ? PillTone.success
                                        : PillTone.neutral,
                                    dense: true,
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Insets.xl),
                  ],
                  const SizedBox(height: Insets.lg),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({
    required this.volume,
    required this.health,
    required this.tested,
  });

  final Volume volume;
  final DriveHealth health;
  final bool tested;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final Color gaugeColor = volume.isCritical
        ? c.danger
        : (volume.isLow ? c.warning : c.primary);

    return Container(
      padding: const EdgeInsets.all(Insets.xl),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF141414), Color(0xFF0A0A0A)],
        ),
        borderRadius: BorderRadius.circular(Radii.lg),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Icon(
                  volume.isInternal ? Icons.smartphone_rounded : Icons.usb_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      volume.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.headlineMedium(Colors.white).copyWith(fontSize: 18),
                    ),
                    Text(
                      '${volume.fileSystemLabel} • ${volume.protocolOrBus}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.labelCaps(Colors.white.withValues(alpha: 0.55))
                          .copyWith(fontSize: 9.5),
                    ),
                  ],
                ),
              ),
              DpPill(
                label: volume.isConnected ? 'Connected' : 'Offline',
                tone: volume.isConnected ? PillTone.success : PillTone.neutral,
                dot: volume.isConnected,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: Insets.lg),
          Row(
            children: <Widget>[
              DpGauge(
                value: volume.usedFraction,
                size: 132,
                color: gaugeColor,
                trackColor: Colors.white.withValues(alpha: 0.1),
                strokeWidth: 10,
                glow: true,
                child: GaugeLabel(
                  percent: ByteFormat.percent(volume.usedFraction),
                  caption: 'used',
                  color: Colors.white,
                  percentSize: 30,
                ),
              ),
              const SizedBox(width: Insets.xl),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _HeroMetric(label: 'Used', value: ByteFormat.format(volume.usedBytes)),
                    const SizedBox(height: 10),
                    _HeroMetric(label: 'Free', value: ByteFormat.format(volume.freeBytes)),
                    const SizedBox(height: 10),
                    _HeroMetric(
                      label: 'Capacity',
                      value: ByteFormat.format(volume.totalBytes),
                      accent: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.lg),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              _DarkPill(label: volume.fileSystemLabel),
              _DarkPill(label: volume.protocolOrBus),
              if (volume.serial.isNotEmpty) _DarkPill(label: 'SN ${volume.serial}'),
              if (volume.isReadOnly)
                const _DarkPill(label: 'READ-ONLY', warning: true),
            ],
          ),
        ],
      ),
    );
  }
}

class _DarkPill extends StatelessWidget {
  const _DarkPill({required this.label, this.warning = false});

  final String label;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: warning
            ? const Color(0xFFF59E0B).withValues(alpha: 0.16)
            : Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(Radii.pill),
        border: Border.all(
          color: warning
              ? const Color(0xFFF59E0B).withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Text(
        label,
        style: AppType.labelCaps(
          warning ? const Color(0xFFFBBF24) : Colors.white.withValues(alpha: 0.7),
        ).copyWith(fontSize: 9),
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({required this.label, required this.value, this.accent = false});

  final String label;
  final String value;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label.toUpperCase(),
          style: AppType.labelCaps(Colors.white.withValues(alpha: 0.45))
              .copyWith(fontSize: 8.5),
        ),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppType.metricSmall(
            accent ? const Color(0xFFFCA5A5) : Colors.white,
          ).copyWith(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _Breakdown extends StatelessWidget {
  const _Breakdown({required this.report, required this.volume});

  final CleanUpReport report;
  final Volume volume;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final StorageBreakdown breakdown = report.breakdown;
    final List<CategoryUsage> categories = breakdown.nonEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(
              ByteFormat.format(breakdown.usedBytes),
              style: AppType.metricMedium(c.text).copyWith(fontSize: 20),
            ),
            const SizedBox(width: 6),
            Text(
              'used of ${ByteFormat.format(volume.totalBytes)}',
              style: AppType.bodySmall(c.textMuted),
            ),
            const Spacer(),
            Text(
              '${ByteFormat.format(breakdown.freeBytes)} free',
              style: AppType.labelCaps(c.success).copyWith(fontSize: 9.5),
            ),
          ],
        ),
        const SizedBox(height: Insets.md),
        SegmentMeter(
          height: 9,
          segments: <(double, Color)>[
            for (final CategoryUsage usage in categories)
              (breakdown.totalBytes <= 0 ? 0 : usage.bytes / breakdown.totalBytes, usage.category.tint(c)),
            (breakdown.freeFraction, c.gaugeTrack),
          ],
        ),
        const SizedBox(height: Insets.md),
        if (categories.isEmpty)
          Text('No categorised files found.', style: AppType.bodySmall(c.textMuted)),
        for (final CategoryUsage usage in categories)
          BreakdownRow(
            label: usage.category.plural,
            bytes: usage.bytes,
            totalBytes: breakdown.totalBytes,
            color: usage.category.tint(c),
            icon: usage.category.icon,
            caption:
                '${ByteFormat.count(usage.itemCount)} items • ${ByteFormat.percent(breakdown.fractionOf(usage.category))} of capacity',
          ),
        const SizedBox(height: Insets.sm),
        Text(
          report.truncated
              ? 'Scan stopped at the safety limit — totals are partial.'
              : 'Scanned ${ByteFormat.count(breakdown.filesScanned)} files in ${ByteFormat.count(breakdown.foldersScanned)} folders.',
          style: AppType.bodySmall(c.textFaint).copyWith(fontSize: 10.5),
        ),
      ],
    );
  }
}

class _SpecRow extends StatelessWidget {
  const _SpecRow({required this.label, required this.value, this.mono = false});

  final String label;
  final String value;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 118,
            child: Text(
              label,
              style: AppType.bodySmall(c.textMuted).copyWith(fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: mono
                  ? AppType.monoSmall(c.text).copyWith(fontSize: 11.5)
                  : AppType.bodySmall(c.text).copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Spec extends StatelessWidget {
  const _Spec({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label.toUpperCase(), style: AppType.labelCaps(c.textFaint).copyWith(fontSize: 8.5)),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppType.monoSmall(c.text).copyWith(fontSize: 12),
        ),
      ],
    );
  }
}
