import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_type.dart';
import '../../core/utils/byte_format.dart';
import '../../core/utils/date_x.dart';
import '../../core/widgets/dialogs.dart';
import '../../core/widgets/dp_card.dart';
import '../../core/widgets/dp_pill.dart';
import '../../core/widgets/drive_cards.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/page_header.dart';
import '../../data/models/transfer_task.dart';
import '../../data/services/transfer_controller.dart';
import '../../data/state/app_state.dart';

class TransfersScreen extends StatelessWidget {
  const TransfersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final TransferController transfers = context.watch<TransferController>();
    final AppState app = context.watch<AppState>();
    final TransferTask? active = transfers.activeTask;
    final List<TransferTask> queued = transfers.tasks
        .where((TransferTask t) => t.isActive && t.id != active?.id)
        .toList(growable: false);
    final List<TransferTask> history = transfers.recent;

    return Scaffold(
      backgroundColor: c.canvas,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            ScreenBody(
              maxWidth: 820,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  PageHeader(
                    title: 'Transfers',
                    subtitle: app.currentVolume == null
                        ? 'No drive selected'
                        : 'Destination ${app.currentVolume!.label}',
                    showBack: true,
                    padding: const EdgeInsets.fromLTRB(0, Insets.md, 0, Insets.md),
                    actions: <Widget>[
                      HeaderAction(
                        icon: Icons.clear_all_rounded,
                        tooltip: 'Clear finished',
                        onTap: history.isEmpty
                            ? () {}
                            : () {
                                transfers.clearFinished();
                                showAppToast(context, 'Finished transfers cleared');
                              },
                      ),
                    ],
                  ),
                  if (active != null) ...<Widget>[
                    const SectionHeader(title: 'In progress'),
                    TransferBanner(
                      task: active,
                      onPause: () => transfers.pause(active.id),
                      onResume: () => transfers.resume(active.id),
                      onCancel: () async {
                        final bool confirmed = await showConfirmDialog(
                          context,
                          title: 'Cancel this transfer?',
                          message:
                              'Files already copied stay on the destination. The rest '
                              'of the queue for this job is skipped.',
                          confirmLabel: 'Cancel transfer',
                          cancelLabel: 'Keep going',
                          destructive: true,
                          icon: Icons.close_rounded,
                        );
                        if (confirmed) await transfers.cancel(active.id);
                      },
                    ),
                    const SizedBox(height: Insets.xl),
                  ],
                  if (queued.isNotEmpty) ...<Widget>[
                    SectionHeader(title: 'Queued', count: queued.length),
                    for (final TransferTask task in queued)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Insets.sm),
                        child: DpCard(
                          padding: const EdgeInsets.all(Insets.md),
                          child: Row(
                            children: <Widget>[
                              IconTile(
                                icon: Icons.schedule_rounded,
                                tint: c.warning,
                                size: 36,
                                radius: 12,
                              ),
                              const SizedBox(width: Insets.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      task.label,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppType.bodyMedium(c.text)
                                          .copyWith(fontWeight: FontWeight.w600),
                                    ),
                                    Text(
                                      task.routeLabel,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppType.bodySmall(c.textMuted)
                                          .copyWith(fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              DpPill(
                                label: task.status.label,
                                tone: PillTone.neutral,
                                dense: true,
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: Insets.xl),
                  ],
                  if (active == null && queued.isEmpty && history.isEmpty)
                    const DpCard(
                      child: EmptyState(
                        icon: Icons.swap_horiz_rounded,
                        title: 'No transfers yet',
                        message:
                            'Copy or move files between drives, or start a folder backup '
                            'from the dashboard. Jobs run one at a time for drive safety.',
                        compact: true,
                      ),
                    ),
                  if (history.isNotEmpty) ...<Widget>[
                    SectionHeader(title: 'Recent', count: history.length),
                    DpCard(
                      padding: const EdgeInsets.symmetric(horizontal: Insets.sm, vertical: 4),
                      child: Column(
                        children: <Widget>[
                          for (int i = 0; i < history.length; i++) ...<Widget>[
                            _HistoryRow(
                              task: history[i],
                              onRemove: () => transfers.remove(history[i].id),
                            ),
                            if (i != history.length - 1)
                              Divider(
                                height: 1,
                                color: c.border.withValues(alpha: 0.6),
                              ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: Insets.md),
                  ],
                  const SizedBox(height: Insets.lg),
                  const InfoBanner(
                    message:
                        'Transfers are sequential and copy in the foreground, so you can '
                        'always see what is touching the drive. Pausing takes effect at the '
                        'next file boundary.',
                    tone: BannerTone.neutral,
                    icon: Icons.info_outline_rounded,
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

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.task, required this.onRemove});

  final TransferTask task;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final bool done = task.status == TransferStatus.completed;
    final bool failed = task.status == TransferStatus.failed;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
      child: Row(
        children: <Widget>[
          IconTile(
            icon: done
                ? Icons.check_rounded
                : (failed ? Icons.error_outline_rounded : Icons.close_rounded),
            tint: done ? c.success : (failed ? c.danger : c.textMuted),
            size: 34,
            radius: 11,
            iconSize: 17,
          ),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  task.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.bodyMedium(c.text).copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                Text(
                  '${ByteFormat.format(task.totalBytes)} • ${task.routeLabel} • ${DateX.relative(task.finishedAt ?? task.createdAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.monoSmall(c.textFaint).copyWith(fontSize: 9.5),
                ),
                if (failed && task.error != null)
                  Text(
                    task.error!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.bodySmall(c.danger).copyWith(fontSize: 10),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          DpPill(
            label: task.status.label,
            tone: done
                ? PillTone.success
                : (failed ? PillTone.danger : PillTone.neutral),
            dense: true,
          ),
          IconButton(
            onPressed: onRemove,
            tooltip: 'Remove from list',
            icon: const Icon(Icons.close_rounded, size: 15),
            color: c.textFaint,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}
