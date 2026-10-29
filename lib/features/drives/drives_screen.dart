import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routing.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_type.dart';
import '../../core/utils/byte_format.dart';
import '../../core/widgets/dialogs.dart';
import '../../core/widgets/dp_card.dart';
import '../../core/widgets/dp_pill.dart';
import '../../core/widgets/drive_cards.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/page_header.dart';
import '../../data/models/file_entry.dart';
import '../../data/models/volume.dart';
import '../../data/state/app_state.dart';
import '../shell/app_shell.dart';

class DrivesScreen extends StatefulWidget {
  const DrivesScreen({super.key});

  @override
  State<DrivesScreen> createState() => _DrivesScreenState();
}

class _DrivesScreenState extends State<DrivesScreen> {
  bool _refreshing = false;
  bool _granting = false;

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    await context.read<AppState>().refreshVolumes();
    if (mounted) setState(() => _refreshing = false);
  }

  Future<void> _addFolder() async {
    final AppState app = context.read<AppState>();
    setState(() => _granting = true);
    try {
      final FileEntry? picked = await app.storage.pickDirectory();
      if (!mounted) return;
      if (picked == null) return;
      showAppToast(
        context,
        'Access granted to ${picked.name}.',
        icon: Icons.folder_shared_rounded,
      );
      await app.refreshVolumes();
    } catch (error) {
      if (!mounted) return;
      showAppToast(
        context,
        '$error',
        icon: Icons.error_outline_rounded,
        iconColor: context.colors.danger,
      );
    } finally {
      if (mounted) setState(() => _granting = false);
    }
  }

  Future<void> _eject(Volume volume) async {
    final bool confirmed = await showConfirmDialog(
      context,
      title: 'Safely remove ${volume.label}?',
      message:
          'Stop all transfers and close apps using the drive before ejecting. '
          'On Android you can then unplug the cable.',
      confirmLabel: 'Eject',
      destructive: true,
      icon: Icons.eject_rounded,
    );
    if (!confirmed || !mounted) return;
    try {
      await context.read<AppState>().eject(volume);
      if (!mounted) return;
      showAppToast(context, '${volume.label} safely removed');
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

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final AppState app = context.watch<AppState>();
    final Volume? active = app.currentVolume;
    final List<Volume> connected = app.connectedVolumes;
    final List<Volume> remembered = app.rememberedVolumes;

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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  PageHeader(
                    title: 'Drives',
                    subtitle:
                        '${connected.length} connected • ${remembered.length} remembered',
                    padding: const EdgeInsets.fromLTRB(0, Insets.md, 0, Insets.md),
                    actions: <Widget>[
                      HeaderAction(
                        icon: Icons.add_rounded,
                        tooltip: 'Grant folder access',
                        onTap: _granting ? () {} : _addFolder,
                      ),
                      HeaderAction(
                        icon: Icons.refresh_rounded,
                        tooltip: 'Refresh drives',
                        onTap: _refreshing ? () {} : _refresh,
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
                          'Preview mode. Real volume discovery runs through the '
                          'Android StorageManager/USB host bridge and iOS FileManager.',
                      icon: Icons.science_outlined,
                      tone: BannerTone.warning,
                    ),
                    const SizedBox(height: Insets.md),
                  ],
                  SectionHeader(
                    title: 'Current drive',
                    count: active == null ? null : 1,
                    actionLabel: active == null ? null : 'Details',
                    onAction:
                        active == null ? null : () => AppRoutes.driveDetails(context, active),
                  ),
                  if (active == null)
                    DpCard(
                      child: EmptyState(
                        icon: Icons.usb_off_rounded,
                        title: 'No drive available',
                        message:
                            'Connect a USB flash drive, external SSD or SD card to '
                            'manage its files.',
                        actionLabel: 'Refresh',
                        onAction: _refresh,
                        compact: true,
                      ),
                    )
                  else
                    DriveListCard(
                      volume: active,
                      active: true,
                      onTap: () => AppRoutes.browse(context, volume: active),
                      onDetails: () => AppRoutes.driveDetails(context, active),
                      onEject: active.isRemovable ? () => _eject(active) : null,
                    ),
                  if (connected.length > 1) ...<Widget>[
                    const SizedBox(height: Insets.xl),
                    const SectionHeader(title: 'Also connected'),
                    for (final Volume volume in connected)
                      if (volume.id != active?.id)
                        Padding(
                          padding: const EdgeInsets.only(bottom: Insets.sm),
                          child: DriveListCard(
                            volume: volume,
                            onTap: () {
                              app.selectVolume(volume.id);
                              AppRoutes.browse(context, volume: volume);
                            },
                            onDetails: () => AppRoutes.driveDetails(context, volume),
                            onEject:
                                volume.isRemovable ? () => _eject(volume) : null,
                          ),
                        ),
                  ],
                  const SizedBox(height: Insets.xl),
                  SectionHeader(
                    title: 'Remembered drives',
                    count: remembered.length,
                    actionLabel: remembered.isEmpty ? null : 'History',
                    actionIcon: Icons.receipt_long_rounded,
                    onAction: () => AppShell.goToTab(context, 2),
                  ),
                  if (remembered.isEmpty)
                    DpCard(
                      padding: const EdgeInsets.all(Insets.lg),
                      child: Text(
                        'Drives you use appear here after the first connection, with '
                        'their last known capacity and health.',
                        style: AppType.bodySmall(c.textMuted),
                      ),
                    )
                  else
                    for (final Volume volume in remembered)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Insets.sm),
                        child: DriveListCard(
                          volume: volume,
                          onTap: () => AppRoutes.driveDetails(context, volume),
                          onDetails: () => AppRoutes.driveDetails(context, volume),
                        ),
                      ),
                  const SizedBox(height: Insets.xl),
                  DpCard(
                    color: c.surfaceAlt,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Icon(Icons.usb_rounded, size: 18, color: c.textMuted),
                            const SizedBox(width: Insets.sm),
                            Text(
                              'Connecting a drive',
                              style: AppType.headlineSmall(c.text).copyWith(fontSize: 14),
                            ),
                          ],
                        ),
                        const SizedBox(height: Insets.sm),
                        Text(
                          'Android: use an OTG adapter and allow DrivePulse storage '
                          'access when prompted. iOS: connect through Files and grant '
                          'folder access — iOS does not expose raw USB block devices, so '
                          'the app manages the folders you authorise.',
                          style: AppType.bodySmall(c.textMuted).copyWith(height: 1.5),
                        ),
                        if (active != null) ...<Widget>[
                          const SizedBox(height: Insets.md),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: <Widget>[
                              DpPill(
                                label: active.fileSystemLabel,
                                monospace: true,
                                dense: true,
                              ),
                              DpPill(
                                label: active.protocolOrBus,
                                monospace: true,
                                dense: true,
                              ),
                              if (active.isReadOnly)
                                const DpPill(
                                  label: 'READ-ONLY',
                                  tone: PillTone.warning,
                                  dense: true,
                                  monospace: true,
                                ),
                              DpPill(
                                label: '${ByteFormat.format(active.freeBytes)} free',
                                tone: PillTone.success,
                                dense: true,
                                monospace: true,
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
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
