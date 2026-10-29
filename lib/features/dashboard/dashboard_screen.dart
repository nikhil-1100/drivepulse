import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routing.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_type.dart';
import '../../core/utils/byte_format.dart';
import '../../core/widgets/activity_tile.dart';
import '../../core/widgets/dialogs.dart';
import '../../core/widgets/dp_card.dart';
import '../../core/widgets/dp_pill.dart';
import '../../core/widgets/drive_cards.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/sheets.dart';
import '../../data/models/activity_event.dart';
import '../../data/models/drive_health.dart';
import '../../data/models/file_entry.dart';
import '../../data/models/transfer_task.dart';
import '../../data/models/volume.dart';
import '../../data/services/transfer_controller.dart';
import '../../data/state/app_state.dart';
import '../shell/app_shell.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _benchmarking = false;

  Future<void> _refresh() async {
    await context.read<AppState>().refreshVolumes();
  }

  Future<void> _runBenchmark(Volume volume) async {
    setState(() => _benchmarking = true);
    try {
      final DriveHealth health = await context.read<AppState>().benchmark(volume);
      if (!mounted) return;
      showAppToast(
        context,
        '${volume.label}: ${health.readLabel} read, ${health.writeLabel} write',
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

  Future<void> _ejectFlow() async {
    final AppState app = context.read<AppState>();
    final List<Volume> removable = app.connectedVolumes
        .where((Volume v) => v.isRemovable)
        .toList(growable: false);
    if (removable.isEmpty) {
      showAppToast(
        context,
        'No removable drive is connected.',
        icon: Icons.usb_off_rounded,
      );
      return;
    }

    final Volume? choice = await showDpSheet<Volume>(
      context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SheetHeader(
            title: 'Safe eject',
            subtitle: 'Close any transfers and apps using the drive first.',
          ),
          for (final Volume volume in removable)
            SheetAction(
              icon: Icons.eject_rounded,
              label: volume.label,
              description:
                  '${volume.protocolOrBus} • ${ByteFormat.format(volume.freeBytes)} free',
              onTap: () => Navigator.of(context).pop(volume),
            ),
          const SizedBox(height: Insets.sm),
          Text(
            'Ejecting unmounts the volume from DrivePulse. Android may still keep '
            'the USB session open until you detach the cable.',
            style: AppType.bodySmall(context.colors.textFaint),
          ),
        ],
      ),
    );
    if (choice == null || !mounted) return;
    final bool confirmed = await showConfirmDialog(
      context,
      title: 'Safely remove ${choice.label}?',
      message:
          'Make sure no file is being copied and no other app is reading from the drive.',
      confirmLabel: 'Eject drive',
      icon: Icons.eject_rounded,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    try {
      await context.read<AppState>().eject(choice);
      if (!mounted) return;
      showAppToast(context, '${choice.label} safely removed');
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

  Future<void> _backupFlow() async {
    final AppState app = context.read<AppState>();
    final Volume? source = app.currentVolume;
    if (source == null) {
      showAppToast(context, 'No drive selected yet.');
      return;
    }
    final List<Volume> targets = app.connectedVolumes
        .where((Volume v) => v.isRemovable && v.id != source.id)
        .toList(growable: false);
    if (targets.isEmpty) {
      showAppToast(
        context,
        'Connect a USB drive to back up to.',
        icon: Icons.usb_rounded,
      );
      return;
    }

    List<FileEntry> folders = const <FileEntry>[];
    try {
      folders = (await app.listDirectory(app.rootFor(source)))
          .where((FileEntry e) => e.isDirectory)
          .toList(growable: false);
    } catch (_) {
      folders = const <FileEntry>[];
    }
    if (!mounted) return;
    if (folders.isEmpty) {
      showAppToast(context, 'No folders found on ${source.label}.');
      return;
    }

    final (Volume, List<FileEntry>)? result =
        await showDpSheet<(Volume, List<FileEntry>)>(
      context,
      child: _BackupSheet(source: source, targets: targets, folders: folders),
    );
    if (result == null || !mounted) return;
    await app.transferFiles(
      sources: result.$2,
      destination: result.$1,
      destinationPath: app.rootFor(result.$1),
      sourceLabel: source.label,
      direction: TransferDirection.backup,
      label: 'Backup from ${source.label}',
    );
  }

  Future<void> _quickAction(String key) async {
    final AppState app = context.read<AppState>();
    switch (key) {
      case 'backup':
        await _backupFlow();
      case 'transfer':
        await AppRoutes.browse(context, volume: app.currentVolume, selectMode: true);
      case 'encrypt':
        await AppRoutes.vault(context, volume: app.currentVolume);
      case 'favorites':
        await AppRoutes.favorites(context, volume: app.currentVolume);
      case 'eject':
        await _ejectFlow();
      case 'cleanup':
        await AppRoutes.cleanup(context, volume: app.currentVolume);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final AppState app = context.watch<AppState>();
    final TransferController transfers = context.watch<TransferController>();
    final Volume? active = app.currentVolume;
    final List<Volume> drives = app.connectedVolumes;
    final double width = MediaQuery.sizeOf(context).width;

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: _refresh,
        color: c.primary,
        backgroundColor: c.surface,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: <Widget>[
            ScreenBody(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  PageHeader(
                    title: 'DrivePulse',
                    subtitle: 'Offline drive manager',
                    leading: const BrandMark(showWordmark: false, size: 36),
                    padding: const EdgeInsets.fromLTRB(0, Insets.md, 0, Insets.md),
                    actions: <Widget>[
                      HeaderAction(
                        icon: Icons.swap_horiz_rounded,
                        tooltip: 'Transfer queue',
                        badge: transfers.hasActive,
                        onTap: () => AppRoutes.transfers(context),
                      ),
                      HeaderAction(
                        icon: Icons.settings_rounded,
                        tooltip: 'Settings',
                        onTap: () => AppRoutes.settings(context),
                      ),
                    ],
                  ),
                  if (app.isDemo) ...<Widget>[
                    const InfoBanner(
                      message:
                          'Preview mode: showing a demo drive. On Android and iOS '
                          'DrivePulse talks to the real filesystem through the native bridge.',
                      icon: Icons.science_outlined,
                      tone: BannerTone.warning,
                    ),
                    const SizedBox(height: Insets.md),
                  ],
                  if (app.error != null) ...<Widget>[
                    InfoBanner(
                      message: app.error!,
                      icon: Icons.warning_amber_rounded,
                      tone: BannerTone.danger,
                      actionLabel: 'Retry',
                      onAction: _refresh,
                    ),
                    const SizedBox(height: Insets.md),
                  ],
                  SectionHeader(
                    title: 'Storage',
                    count: drives.length,
                    actionLabel: 'All drives',
                    actionIcon: Icons.storage_rounded,
                    onAction: () => AppShell.goToTab(context, 0),
                  ),
                  if (drives.isEmpty)
                    DpCard(
                      child: EmptyState(
                        icon: Icons.usb_off_rounded,
                        title: 'No drive connected',
                        message:
                            'Plug in a USB flash drive, SSD or SD card using an OTG '
                            'adapter, then refresh.',
                        actionLabel: 'Refresh',
                        onAction: _refresh,
                        compact: true,
                      ),
                    )
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.zero,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: responsiveColumns(width),
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        mainAxisExtent: 212,
                      ),
                      itemCount: drives.length > 4 ? 4 : drives.length,
                      itemBuilder: (BuildContext context, int index) {
                        final Volume volume = drives[index];
                        return DriveGaugeCard(
                          volume: volume,
                          selected: volume.id == active?.id,
                          hint: volume.isInternal
                              ? 'Tap to browse files'
                              : (volume.isConnected && volume.isRemovable
                                  ? 'Tap to browse files'
                                  : null),
                          onTap: () => AppRoutes.browse(context, volume: volume),
                        );
                      },
                    ),
                  if (transfers.activeTask != null) ...<Widget>[
                    const SizedBox(height: Insets.md),
                    TransferBanner(
                      task: transfers.activeTask!,
                      onTap: () => AppRoutes.transfers(context),
                      onPause: () => transfers.pause(transfers.activeTask!.id),
                      onResume: () => transfers.resume(transfers.activeTask!.id),
                      onCancel: () => transfers.cancel(transfers.activeTask!.id),
                    ),
                  ] else if (active != null) ...<Widget>[
                    const SizedBox(height: Insets.md),
                    _CleanupSuggestion(
                      reclaimableBytes: app.cleanUpReport?.reclaimableBytes ?? 0,
                      onTap: () => AppRoutes.cleanup(context, volume: active),
                    ),
                  ],
                  const SizedBox(height: Insets.xl),
                  const SectionHeader(title: 'Quick actions'),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    crossAxisCount: width >= 700 ? 6 : 3,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    mainAxisExtent: 92,
                    children: <Widget>[
                      QuickActionTile(
                        label: 'Backup',
                        icon: Icons.backup_rounded,
                        emphasized: true,
                        onTap: () => _quickAction('backup'),
                      ),
                      QuickActionTile(
                        label: 'Transfer',
                        icon: Icons.sync_alt_rounded,
                        onTap: () => _quickAction('transfer'),
                      ),
                      QuickActionTile(
                        label: 'Encrypt',
                        icon: Icons.lock_outline_rounded,
                        onTap: () => _quickAction('encrypt'),
                      ),
                      QuickActionTile(
                        label: 'Favorites',
                        icon: Icons.star_outline_rounded,
                        onTap: () => _quickAction('favorites'),
                      ),
                      QuickActionTile(
                        label: 'Eject',
                        icon: Icons.eject_rounded,
                        onTap: () => _quickAction('eject'),
                      ),
                      QuickActionTile(
                        label: 'Clean up',
                        icon: Icons.cleaning_services_rounded,
                        onTap: () => _quickAction('cleanup'),
                      ),
                    ],
                  ),
                  if (active != null) ...<Widget>[
                    const SizedBox(height: Insets.xl),
                    const SectionHeader(title: 'Drive health'),
                    _HealthCard(
                      volume: active,
                      health: app.healthOf(active),
                      busy: _benchmarking,
                      onBenchmark: () => _runBenchmark(active),
                      onManage: () => AppRoutes.driveDetails(context, active),
                    ),
                  ],
                  const SizedBox(height: Insets.xl),
                  SectionHeader(
                    title: 'Recent activity',
                    count: app.activity.length,
                    actionLabel: 'View all',
                    actionIcon: Icons.arrow_forward_rounded,
                    onAction: () => AppShell.goToTab(context, 2),
                  ),
                  DpCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Insets.sm,
                      vertical: Insets.xs,
                    ),
                    child: app.activity.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(Insets.lg),
                            child: Text(
                              'Your transfers, ejects and cleanups will appear here.',
                              style: AppType.bodySmall(c.textMuted),
                            ),
                          )
                        : Column(
                            children: <Widget>[
                              for (final ActivityEvent event
                                  in app.activity.take(3))
                                ActivityTile(
                                  event: event,
                                  showStatus: false,
                                  onTap: () => AppShell.goToTab(context, 2),
                                ),
                            ],
                          ),
                  ),
                  const SizedBox(height: Insets.lg),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Icon(Icons.shield_outlined, size: 13, color: c.textFaint),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Local-only • no account • no network permission',
                          style: AppType.bodySmall(c.textFaint).copyWith(fontSize: 10.5),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Insets.xl),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CleanupSuggestion extends StatelessWidget {
  const _CleanupSuggestion({required this.reclaimableBytes, required this.onTap});

  final int reclaimableBytes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final bool hasReport = reclaimableBytes > 0;
    return DpCard(
      color: hasReport ? c.primarySoft : c.surface,
      borderColor: hasReport ? c.primary.withValues(alpha: 0.25) : c.border,
      onTap: onTap,
      child: Row(
        children: <Widget>[
          IconTile(
            icon: Icons.auto_awesome_rounded,
            tint: hasReport ? c.primary : c.success,
            size: 40,
          ),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'Clean up space',
                  style: AppType.headlineSmall(c.text).copyWith(fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  hasReport
                      ? '${ByteFormat.format(reclaimableBytes)} of junk and duplicates can be freed'
                      : 'Scan for junk, duplicates and large files',
                  style: AppType.bodySmall(c.textMuted).copyWith(fontSize: 11.5),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onTap,
            child: Text(
              hasReport ? 'Review' : 'Scan',
              style: AppType.bodySmall(c.primary)
                  .copyWith(fontWeight: FontWeight.w700, fontSize: 11.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _HealthCard extends StatelessWidget {
  const _HealthCard({
    required this.volume,
    required this.health,
    required this.busy,
    required this.onBenchmark,
    required this.onManage,
  });

  final Volume volume;
  final DriveHealth health;
  final bool busy;
  final VoidCallback onBenchmark;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final bool tested = health.status != HealthStatus.unknown;
    final Color tone = switch (health.status) {
      HealthStatus.healthy => c.success,
      HealthStatus.warning => c.warning,
      HealthStatus.critical => c.danger,
      HealthStatus.unknown => c.textMuted,
    };

    return DpCard(
      onTap: onManage,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              IconTile(
                icon: Icons.monitor_heart_outlined,
                tint: tone,
                size: 38,
                radius: 12,
                iconSize: 19,
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
                      style: AppType.headlineSmall(c.text).copyWith(fontSize: 14),
                    ),
                    Text(
                      tested
                          ? 'Estimated health from local benchmark'
                          : 'No benchmark yet — run one locally',
                      style: AppType.bodySmall(c.textMuted).copyWith(fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              DpPill(
                label: health.status.label,
                tone: health.status == HealthStatus.healthy
                    ? PillTone.success
                    : (health.status == HealthStatus.warning
                        ? PillTone.warning
                        : (health.status == HealthStatus.critical
                            ? PillTone.danger
                            : PillTone.neutral)),
                dense: true,
                dot: true,
              ),
            ],
          ),
          const SizedBox(height: Insets.md),
          Row(
            children: <Widget>[
              Expanded(
                child: _HealthMetric(
                  label: 'Read',
                  value: tested ? health.readLabel : '—',
                ),
              ),
              Container(width: 1, height: 26, color: c.border),
              Expanded(
                child: _HealthMetric(
                  label: 'Write',
                  value: tested ? health.writeLabel : '—',
                ),
              ),
              Container(width: 1, height: 26, color: c.border),
              Expanded(
                child: _HealthMetric(
                  label: 'Health',
                  value: tested ? '${health.healthPercent}%' : '—',
                  color: tested ? tone : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.md),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Write test creates a temporary 16 MB file on the drive.',
                  style: AppType.bodySmall(c.textFaint).copyWith(fontSize: 10),
                ),
              ),
              const SizedBox(width: Insets.sm),
              SizedBox(
                height: 34,
                child: OutlinedButton.icon(
                  onPressed: busy ? null : onBenchmark,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    minimumSize: const Size(0, 34),
                  ),
                  icon: busy
                      ? SizedBox(
                          width: 13,
                          height: 13,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: c.primary,
                          ),
                        )
                      : const Icon(Icons.speed_rounded, size: 15),
                  label: Text(
                    busy ? 'Testing' : 'Benchmark',
                    style: AppType.bodySmall(c.text).copyWith(fontSize: 11.5),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HealthMetric extends StatelessWidget {
  const _HealthMetric({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return Column(
      children: <Widget>[
        Text(label.toUpperCase(), style: AppType.labelCaps(c.textFaint).copyWith(fontSize: 9)),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppType.monoSmall(color ?? c.text).copyWith(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _BackupSheet extends StatefulWidget {
  const _BackupSheet({
    required this.source,
    required this.targets,
    required this.folders,
  });

  final Volume source;
  final List<Volume> targets;
  final List<FileEntry> folders;

  @override
  State<_BackupSheet> createState() => _BackupSheetState();
}

class _BackupSheetState extends State<_BackupSheet> {
  late final Set<String> _selected = <String>{
    if (widget.folders.isNotEmpty) widget.folders.first.path,
  };
  late Volume _target = widget.targets.first;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SheetHeader(
          title: 'Back up folders',
          subtitle: '${widget.source.label} → ${_target.label}',
        ),
        Text('SOURCE FOLDERS', style: AppType.labelCaps(c.textFaint)),
        const SizedBox(height: Insets.sm),
        Flexible(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 230),
            child: ListView(
              shrinkWrap: true,
              children: <Widget>[
                for (final FileEntry folder in widget.folders)
                  CheckboxListTile(
                    value: _selected.contains(folder.path),
                    onChanged: (bool? value) {
                      setState(() {
                        if (value == true) {
                          _selected.add(folder.path);
                        } else {
                          _selected.remove(folder.path);
                        }
                      });
                    },
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(
                      folder.name,
                      style: AppType.bodyMedium(c.text).copyWith(fontSize: 13.5),
                    ),
                    subtitle: Text(
                      '${folder.childCount ?? 0} items',
                      style: AppType.bodySmall(c.textFaint),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Insets.md),
        Text('DESTINATION DRIVE', style: AppType.labelCaps(c.textFaint)),
        const SizedBox(height: Insets.sm),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final Volume volume in widget.targets)
              ChoiceChip(
                selected: volume.id == _target.id,
                onSelected: (_) => setState(() => _target = volume),
                label: Text('${volume.label} • ${ByteFormat.format(volume.freeBytes)} free'),
                labelStyle: AppType.bodySmall(
                  volume.id == _target.id ? c.onPrimary : c.text,
                ),
                selectedColor: c.primary,
                backgroundColor: c.surfaceAlt,
                side: BorderSide(color: c.border),
              ),
          ],
        ),
        const SizedBox(height: Insets.md),
        const InfoBanner(
          message:
              'Backups copy the selected folders into the drive root. Existing '
              'files with the same name are replaced.',
          tone: BannerTone.neutral,
          icon: Icons.info_outline_rounded,
        ),
        const SizedBox(height: Insets.md),
        DpPrimaryButton(
          label: 'Start backup',
          icon: Icons.backup_rounded,
          onPressed: _selected.isEmpty
              ? null
              : () {
                  final List<FileEntry> selected = widget.folders
                      .where((FileEntry f) => _selected.contains(f.path))
                      .toList(growable: false);
                  Navigator.of(context).pop((_target, selected));
                },
        ),
      ],
    );
  }
}
