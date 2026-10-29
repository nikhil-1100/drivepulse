import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
import '../../core/widgets/file_row.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/sheets.dart';
import '../../data/models/clean_up_report.dart';
import '../../data/models/file_entry.dart';
import '../../data/models/storage_breakdown.dart';
import '../../data/models/volume.dart';
import '../../data/state/app_state.dart';

class CleanupScreen extends StatefulWidget {
  const CleanupScreen({super.key, this.volume});

  final Volume? volume;

  @override
  State<CleanupScreen> createState() => _CleanupScreenState();
}

class _CleanupScreenState extends State<CleanupScreen> {
  Volume? _volume;
  CleanUpReport? _report;
  bool _scanning = false;
  String? _error;

  AppState get _app => context.read<AppState>();

  @override
  void initState() {
    super.initState();
    final AppState app = context.read<AppState>();
    _volume = widget.volume ?? app.currentVolume;
    if (_volume != null && app.cleanUpVolumeId == _volume!.id) {
      _report = app.cleanUpReport;
    }
  }

  Future<void> _scan() async {
    final Volume? volume = _volume;
    if (volume == null) return;
    setState(() {
      _scanning = true;
      _error = null;
    });
    try {
      final CleanUpReport? report = await _app.scanCleanUp(volume);
      if (!mounted) return;
      setState(() => _report = report);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _cleanEntries({
    required List<FileEntry> entries,
    required String actionLabel,
    required String message,
  }) async {
    final Volume? volume = _volume;
    if (volume == null || entries.isEmpty) return;
    final int bytes = entries.fold<int>(
      0,
      (int sum, FileEntry e) => sum + (e.isDirectory ? 0 : e.sizeBytes),
    );
    final bool confirmed = await showConfirmDialog(
      context,
      title: actionLabel,
      message:
          '$message\n\n${entries.length} item${entries.length == 1 ? '' : 's'}'
          '${bytes > 0 ? ' • ${ByteFormat.format(bytes)}' : ''}. '
          'This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
      icon: Icons.delete_sweep_outlined,
    );
    if (!confirmed || !mounted) return;
    try {
      await _app.deleteFromCleanup(entries: entries, volume: volume);
      await _scan();
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

  Future<void> _reviewDuplicates(DuplicateGroup group) async {
    if (!mounted) return;
    final Set<String> toDelete = <String>{
      for (final FileEntry file in group.files.skip(1)) file.path,
    };
    final Set<String>? chosen = await showDpSheet<Set<String>>(
      context,
      child: StatefulBuilder(
        builder: (BuildContext ctx, void Function(VoidCallback) setSheetState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SheetHeader(
                title: 'Duplicate group',
                subtitle:
                    '${group.count} copies • ${ByteFormat.format(group.sizeBytes)} each • '
                    'keep one to free ${ByteFormat.format(group.redundantBytes)}',
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: <Widget>[
                    for (final FileEntry file in group.files)
                      CheckboxListTile(
                        value: toDelete.contains(file.path),
                        onChanged: (bool? value) {
                          setSheetState(() {
                            if (value == true) {
                              if (toDelete.length < group.files.length - 1) {
                                toDelete.add(file.path);
                              }
                            } else {
                              toDelete.remove(file.path);
                            }
                          });
                        },
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(
                          file.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.bodyMedium(ctx.colors.text).copyWith(fontSize: 13),
                        ),
                        subtitle: Text(
                          '${DateX.fileStamp(file.modifiedAt)} • ${file.parentPath}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.bodySmall(ctx.colors.textFaint).copyWith(fontSize: 10.5),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: Insets.sm),
              const InfoBanner(
                message: 'At least one copy must remain. Keep the newest copy for '
                    'the safest result.',
                tone: BannerTone.neutral,
              ),
              const SizedBox(height: Insets.md),
              DpPrimaryButton(
                label: toDelete.isEmpty
                    ? 'Keep all copies'
                    : 'Delete ${toDelete.length} copies',
                destructive: true,
                onPressed: toDelete.isEmpty
                    ? null
                    : () => Navigator.of(ctx).pop(<String>{...toDelete}),
              ),
            ],
          );
        },
      ),
    );
    if (chosen == null || chosen.isEmpty || !mounted) return;
    final List<FileEntry> entries = group.files
        .where((FileEntry file) => chosen.contains(file.path))
        .toList(growable: false);
    await _cleanEntries(
      entries: entries,
      actionLabel: 'Delete duplicate copies?',
      message: 'DrivePulse keeps the remaining copy and removes the selected duplicates.',
    );
  }

  Future<void> _largeFileSheet(FileEntry file) async {
    final Volume? volume = _volume;
    if (volume == null) return;
    final bool? remove = await showDpSheet<bool>(
      context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SheetHeader(title: file.name, subtitle: file.kind.label),
          _KeyValue(label: 'Size', value: ByteFormat.format(file.sizeBytes)),
          _KeyValue(label: 'Modified', value: DateX.full(file.modifiedAt)),
          _KeyValue(label: 'Folder', value: file.parentPath),
          const SizedBox(height: Insets.md),
          Row(
            children: <Widget>[
              Expanded(
                child: DpSecondaryButton(
                  label: 'Close',
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ),
              const SizedBox(width: Insets.sm),
              Expanded(
                child: DpPrimaryButton(
                  label: 'Delete',
                  icon: Icons.delete_outline_rounded,
                  destructive: true,
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (remove != true || !mounted) return;
    await _cleanEntries(
      entries: <FileEntry>[file],
      actionLabel: 'Delete “${file.name}”?',
      message: 'The file is removed from ${volume.label}.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final AppState app = context.watch<AppState>();
    final Volume? volume = _volume;
    final CleanUpReport? report = _report;
    final bool busy = _scanning || app.scanning;

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
                    title: 'Clean up space',
                    subtitle: volume == null ? 'No drive selected' : volume.label,
                    showBack: true,
                    padding: const EdgeInsets.fromLTRB(0, Insets.md, 0, Insets.md),
                    actions: <Widget>[
                      HeaderAction(
                        icon: Icons.refresh_rounded,
                        tooltip: 'Rescan',
                        onTap: busy ? () {} : _scan,
                      ),
                    ],
                  ),
                  if (volume == null)
                    const DpCard(
                      child: EmptyState(
                        icon: Icons.usb_off_rounded,
                        title: 'No drive to scan',
                        message: 'Connect a drive, then open Clean up again.',
                        compact: true,
                      ),
                    )
                  else ...<Widget>[
                    _VolumeStrip(
                      volume: volume,
                      report: report,
                      onScan: busy ? null : _scan,
                      scanning: busy,
                      scanned: app.scanProgress,
                    ),
                    if (_error != null) ...<Widget>[
                      const SizedBox(height: Insets.md),
                      InfoBanner(
                        message: _error!,
                        tone: BannerTone.danger,
                        icon: Icons.warning_amber_rounded,
                        actionLabel: 'Retry',
                        onAction: _scan,
                      ),
                    ],
                    const SizedBox(height: Insets.xl),
                    if (report == null) ...<Widget>[
                      _ScanIntro(volume: volume, onScan: busy ? null : _scan),
                    ] else ...<Widget>[
                      _ReclaimHero(
                        report: report,
                        onCleanJunk: report.junkFiles.isEmpty
                            ? null
                            : () => _cleanEntries(
                                  entries: report.junkFiles,
                                  actionLabel: 'Remove junk files?',
                                  message:
                                      'Cache, temp, log and trash files identified by the scan.',
                                ),
                        onReviewDuplicates: report.duplicates.isEmpty
                            ? null
                            : () => _reviewDuplicates(report.duplicates.first),
                      ),
                      const SizedBox(height: Insets.xl),
                      const SectionHeader(title: 'What uses space'),
                      _BreakdownCard(report: report, volume: volume),
                      const SizedBox(height: Insets.xl),
                      SectionHeader(
                        title: 'Duplicates',
                        count: report.duplicates.length,
                        actionLabel: report.duplicates.isEmpty ? null : 'Largest first',
                      ),
                      if (report.duplicates.isEmpty)
                        const _NothingFound(
                          icon: Icons.content_copy_rounded,
                          message:
                              'No byte-identical duplicates above 1 MB were found.',
                        )
                      else
                        for (final DuplicateGroup group in report.duplicates.take(4))
                          Padding(
                            padding: const EdgeInsets.only(bottom: Insets.sm),
                            child: DpCard(
                              onTap: () => _reviewDuplicates(group),
                              padding: const EdgeInsets.all(Insets.md),
                              child: Row(
                                children: <Widget>[
                                  IconTile(
                                    icon: Icons.content_copy_rounded,
                                    tint: c.warning,
                                    size: 38,
                                    radius: 12,
                                  ),
                                  const SizedBox(width: Insets.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Text(
                                          '${group.count} copies of ${group.files.first.name}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppType.bodyMedium(c.text)
                                              .copyWith(fontWeight: FontWeight.w600),
                                        ),
                                        Text(
                                          '${ByteFormat.format(group.sizeBytes)} each • ${ByteFormat.format(group.redundantBytes)} recoverable',
                                          style: AppType.monoSmall(c.textMuted)
                                              .copyWith(fontSize: 10.5),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    'Review',
                                    style: AppType.bodySmall(c.primary).copyWith(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      const SizedBox(height: Insets.xl),
                      SectionHeader(
                        title: 'Junk & temp files',
                        count: report.junkFiles.length,
                        actionLabel: report.junkFiles.isEmpty ? null : 'Remove all',
                        onAction: report.junkFiles.isEmpty
                            ? null
                            : () => _cleanEntries(
                                  entries: report.junkFiles,
                                  actionLabel: 'Remove junk files?',
                                  message:
                                      'Cache, temp, log and trash files identified by the scan.',
                                ),
                      ),
                      if (report.junkFiles.isEmpty)
                        const _NothingFound(
                          icon: Icons.auto_awesome_rounded,
                          message: 'No cache, temp or trash files found.',
                        )
                      else
                        DpCard(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: Column(
                            children: <Widget>[
                              for (final FileEntry file in report.junkFiles.take(6))
                                FileRow(
                                  entry: file,
                                  subtitle:
                                      '${ByteFormat.format(file.sizeBytes)} • ${file.parentPath}',
                                  onTap: () => _largeFileSheet(file),
                                  showChevron: false,
                                ),
                            ],
                          ),
                        ),
                      const SizedBox(height: Insets.xl),
                      SectionHeader(
                        title: 'Large files',
                        count: report.largeFiles.length,
                        actionLabel: 'Threshold: ${app.settings.largeFileThresholdMb} MB',
                      ),
                      if (report.largeFiles.isEmpty)
                        const _NothingFound(
                          icon: Icons.insert_drive_file_outlined,
                          message: 'No file above the size threshold.',
                        )
                      else
                        DpCard(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: Column(
                            children: <Widget>[
                              for (final FileEntry file in report.largeFiles.take(6))
                                FileRow(
                                  entry: file,
                                  onTap: () => _largeFileSheet(file),
                                  showChevron: true,
                                ),
                            ],
                          ),
                        ),
                      const SizedBox(height: Insets.xl),
                      SectionHeader(
                        title: 'Empty folders',
                        count: report.emptyFolders.length,
                        actionLabel:
                            report.emptyFolders.isEmpty ? null : 'Remove all',
                        onAction: report.emptyFolders.isEmpty
                            ? null
                            : () => _cleanEntries(
                                  entries: report.emptyFolders,
                                  actionLabel: 'Remove empty folders?',
                                  message:
                                      'Folders with no files or sub-folders are removed.',
                                ),
                      ),
                      if (report.emptyFolders.isEmpty)
                        const _NothingFound(
                          icon: Icons.folder_open_rounded,
                          message: 'No empty folders found.',
                        )
                      else
                        DpCard(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: Column(
                            children: <Widget>[
                              for (final FileEntry file in report.emptyFolders.take(5))
                                FileRow(
                                  entry: file,
                                  subtitle: file.path,
                                  onTap: () => _cleanEntries(
                                    entries: <FileEntry>[file],
                                    actionLabel: 'Remove empty folder?',
                                    message: file.path,
                                  ),
                                  showChevron: false,
                                ),
                            ],
                          ),
                        ),
                      const SizedBox(height: Insets.xl),
                      SectionHeader(
                        title: 'Untouched for 180+ days',
                        count: report.staleFiles.length,
                      ),
                      if (report.staleFiles.isEmpty)
                        const _NothingFound(
                          icon: Icons.schedule_rounded,
                          message: 'Every file has been used in the last six months.',
                        )
                      else
                        DpCard(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: Column(
                            children: <Widget>[
                              for (final FileEntry file in report.staleFiles.take(6))
                                FileRow(
                                  entry: file,
                                  onTap: () => _largeFileSheet(file),
                                  showChevron: true,
                                ),
                            ],
                          ),
                        ),
                      const SizedBox(height: Insets.xl),
                      InfoBanner(
                        message:
                            'Scans run entirely on-device and stop at ${ByteFormat.count(24000)} '
                            'entries to protect battery. Nothing is deleted without your confirmation.',
                        tone: BannerTone.neutral,
                        icon: Icons.shield_outlined,
                      ),
                      if (report.truncated) ...<Widget>[
                        const SizedBox(height: Insets.sm),
                        const InfoBanner(
                          message:
                              'This drive is large: the scan hit its safety limit, so totals are partial.',
                          tone: BannerTone.warning,
                          icon: Icons.info_outline_rounded,
                        ),
                      ],
                    ],
                  ],
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

class _VolumeStrip extends StatelessWidget {
  const _VolumeStrip({
    required this.volume,
    required this.report,
    required this.onScan,
    required this.scanning,
    required this.scanned,
  });

  final Volume volume;
  final CleanUpReport? report;
  final VoidCallback? onScan;
  final bool scanning;
  final int scanned;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return DpCard(
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              DpGauge(
                value: volume.usedFraction,
                size: 62,
                color: volume.isCritical ? c.danger : c.primary,
                strokeWidth: 6,
                child: Text(
                  ByteFormat.percent(volume.usedFraction),
                  style: AppType.monoSmall(c.text)
                      .copyWith(fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      volume.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.headlineSmall(c.text).copyWith(fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${ByteFormat.format(volume.freeBytes)} free of ${ByteFormat.format(volume.totalBytes)}',
                      style: AppType.monoSmall(c.textMuted).copyWith(fontSize: 11),
                    ),
                    const SizedBox(height: 4),
                    if (scanning)
                      Text(
                        'Scanning… ${scanned > 0 ? '${ByteFormat.count(scanned)} entries' : ''}',
                        style: AppType.bodySmall(c.warning).copyWith(fontSize: 10.5),
                      )
                    else if (report != null)
                      Text(
                        'Last scan ${DateX.relative(report!.scannedAt)} • ${ByteFormat.count(report!.breakdown.filesScanned)} files',
                        style: AppType.bodySmall(c.textFaint).copyWith(fontSize: 10.5),
                      ),
                  ],
                ),
              ),
              if (onScan != null)
                OutlinedButton(
                  onPressed: onScan,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    minimumSize: const Size(0, 34),
                  ),
                  child: Text(
                    report == null ? 'Scan' : 'Rescan',
                    style: AppType.bodySmall(c.text).copyWith(fontSize: 11.5),
                  ),
                ),
            ],
          ),
          if (scanning) ...<Widget>[
            const SizedBox(height: Insets.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                minHeight: 5,
                backgroundColor: c.surfaceSunken,
                valueColor: AlwaysStoppedAnimation<Color>(c.primary),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ScanIntro extends StatelessWidget {
  const _ScanIntro({required this.volume, required this.onScan});

  final Volume volume;
  final VoidCallback? onScan;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return DpCard(
      child: Column(
        children: <Widget>[
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: c.primarySoft,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: c.primary.withValues(alpha: 0.2)),
            ),
            child: Icon(Icons.radar_rounded, color: c.primary, size: 26),
          ),
          const SizedBox(height: Insets.md),
          Text(
            'Find space you can reclaim',
            style: AppType.headlineSmall(c.text),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'DrivePulse scans ${volume.label} locally for junk, duplicates, large files '
            'and empty folders. It takes a few seconds and changes nothing.',
            textAlign: TextAlign.center,
            style: AppType.bodySmall(c.textMuted).copyWith(height: 1.5),
          ),
          const SizedBox(height: Insets.lg),
          const _ScanPoint(
            icon: Icons.cleaning_services_rounded,
            title: 'Cache, temp, log & trash',
            caption: 'Safe to remove',
          ),
          const SizedBox(height: Insets.sm),
          const _ScanPoint(
            icon: Icons.content_copy_rounded,
            title: 'Byte-identical duplicates',
            caption: 'Verified with SHA-256',
          ),
          const SizedBox(height: Insets.sm),
          const _ScanPoint(
            icon: Icons.speed_rounded,
            title: 'Large & untouched files',
            caption: 'Review before deleting',
          ),
          const SizedBox(height: Insets.lg),
          DpPrimaryButton(
            label: 'Start scan',
            icon: Icons.radar_rounded,
            onPressed: onScan,
          ),
        ],
      ),
    );
  }
}

class _ScanPoint extends StatelessWidget {
  const _ScanPoint({required this.icon, required this.title, required this.caption});

  final IconData icon;
  final String title;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return Row(
      children: <Widget>[
        Icon(icon, size: 16, color: c.textMuted),
        const SizedBox(width: Insets.sm),
        Expanded(
          child: Text(
            title,
            style: AppType.bodySmall(c.text).copyWith(fontSize: 12),
          ),
        ),
        Text(
          caption,
          style: AppType.labelCaps(c.textFaint).copyWith(fontSize: 8.5),
        ),
      ],
    );
  }
}

class _ReclaimHero extends StatelessWidget {
  const _ReclaimHero({
    required this.report,
    required this.onCleanJunk,
    required this.onReviewDuplicates,
  });

  final CleanUpReport report;
  final VoidCallback? onCleanJunk;
  final VoidCallback? onReviewDuplicates;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final bool hasSpace = report.reclaimableBytes > 0;

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
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(Radii.pill),
                ),
                child: Text(
                  'RECLAIMABLE',
                  style: AppType.labelCaps(Colors.white.withValues(alpha: 0.65))
                      .copyWith(fontSize: 8.5),
                ),
              ),
              const Spacer(),
              Icon(Icons.auto_awesome_rounded,
                  size: 16, color: Colors.white.withValues(alpha: 0.6)),
            ],
          ),
          const SizedBox(height: Insets.md),
          Text(
            hasSpace ? ByteFormat.format(report.reclaimableBytes) : 'Nothing to clean',
            style: AppType.metricLarge(Colors.white).copyWith(
              fontSize: 34,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            hasSpace
                ? '${report.junkFiles.length} junk files • ${report.duplicates.length} duplicate groups'
                : 'Your drive is already tidy. Large files are listed below.',
            style: AppType.bodySmall(Colors.white.withValues(alpha: 0.6)),
          ),
          if (hasSpace) ...<Widget>[
            const SizedBox(height: Insets.lg),
            Row(
              children: <Widget>[
                if (onCleanJunk != null)
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onCleanJunk,
                      style: FilledButton.styleFrom(
                        backgroundColor: c.primary,
                        foregroundColor: c.onPrimary,
                      ),
                      icon: const Icon(Icons.cleaning_services_rounded, size: 17),
                      label: Text(
                        'Clean junk',
                        style: AppType.labelLarge(c.onPrimary).copyWith(fontSize: 12.5),
                      ),
                    ),
                  ),
                if (onCleanJunk != null && onReviewDuplicates != null)
                  const SizedBox(width: Insets.sm),
                if (onReviewDuplicates != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onReviewDuplicates,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.25),
                        ),
                      ),
                      icon: const Icon(Icons.content_copy_rounded, size: 16),
                      label: Text(
                        'Duplicates',
                        style: AppType.labelLarge(Colors.white).copyWith(fontSize: 12.5),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard({required this.report, required this.volume});

  final CleanUpReport report;
  final Volume volume;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final StorageBreakdown breakdown = report.breakdown;
    final List<CategoryUsage> categories = breakdown.nonEmpty;

    return DpCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SegmentMeter(
            height: 10,
            segments: <(double, Color)>[
              for (final CategoryUsage usage in categories)
                (
                  breakdown.totalBytes <= 0 ? 0 : usage.bytes / breakdown.totalBytes,
                  usage.category.tint(c)
                ),
              (breakdown.freeFraction, c.gaugeTrack),
            ],
          ),
          const SizedBox(height: Insets.md),
          for (final CategoryUsage usage in categories)
            BreakdownRow(
              label: usage.category.plural,
              bytes: usage.bytes,
              totalBytes: breakdown.totalBytes,
              color: usage.category.tint(c),
              icon: usage.category.icon,
              caption: '${ByteFormat.count(usage.itemCount)} items',
            ),
          const SizedBox(height: Insets.sm),
          Row(
            children: <Widget>[
              Icon(Icons.circle, size: 7, color: c.gaugeTrack),
              const SizedBox(width: 5),
              Text(
                'Free ${ByteFormat.format(breakdown.freeBytes)}',
                style: AppType.bodySmall(c.textMuted).copyWith(fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NothingFound extends StatelessWidget {
  const _NothingFound({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return DpCard(
      padding: const EdgeInsets.all(Insets.md),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 16, color: c.success),
          const SizedBox(width: Insets.sm),
          Expanded(
            child: Text(
              message,
              style: AppType.bodySmall(c.textMuted).copyWith(fontSize: 11.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _KeyValue extends StatelessWidget {
  const _KeyValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: AppType.bodySmall(c.textMuted).copyWith(fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppType.bodySmall(c.text).copyWith(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
