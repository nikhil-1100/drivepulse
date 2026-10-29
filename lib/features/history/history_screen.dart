import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routing.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_type.dart';
import '../../core/utils/byte_format.dart';
import '../../core/utils/date_x.dart';
import '../../core/widgets/activity_tile.dart';
import '../../core/widgets/dialogs.dart';
import '../../core/widgets/dp_card.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/filter_bar.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/sheets.dart';
import '../../data/models/activity_event.dart';
import '../../data/state/app_state.dart';

enum _HistoryFilter { all, transfers, eject, sync, cleanup, security, removed }

extension on _HistoryFilter {
  String get label => switch (this) {
        _HistoryFilter.all => 'All',
        _HistoryFilter.transfers => 'Transfers',
        _HistoryFilter.eject => 'Eject',
        _HistoryFilter.sync => 'Backup',
        _HistoryFilter.cleanup => 'Cleanup',
        _HistoryFilter.security => 'Encrypted',
        _HistoryFilter.removed => 'Deleted',
      };

  bool matches(ActivityEvent event) => switch (this) {
        _HistoryFilter.all => true,
        _HistoryFilter.transfers => event.type == ActivityType.transfer,
        _HistoryFilter.eject => event.type == ActivityType.eject ||
            event.type == ActivityType.connect,
        _HistoryFilter.sync => event.type == ActivityType.backup ||
            event.type == ActivityType.sync,
        _HistoryFilter.cleanup => event.type == ActivityType.cleanup ||
            event.type == ActivityType.benchmark,
        _HistoryFilter.security => event.type == ActivityType.encrypt ||
            event.type == ActivityType.decrypt,
        _HistoryFilter.removed => event.type == ActivityType.delete ||
            event.type == ActivityType.format ||
            event.type == ActivityType.rename ||
            event.type == ActivityType.createFolder,
      };
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  _HistoryFilter _filter = _HistoryFilter.all;
  final TextEditingController _search = TextEditingController();
  bool _searchOpen = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _clear() async {
    final bool confirmed = await showConfirmDialog(
      context,
      title: 'Clear activity history?',
      message:
          'Removes the local activity log from this device. Your files and drives '
          'are not affected.',
      confirmLabel: 'Clear',
      destructive: true,
      icon: Icons.delete_sweep_outlined,
    );
    if (!confirmed || !mounted) return;
    await context.read<AppState>().clearHistory();
    if (!mounted) return;
    showAppToast(context, 'Activity history cleared');
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final AppState app = context.watch<AppState>();
    final String query = _search.text.trim().toLowerCase();
    final List<ActivityEvent> events = app.activity
        .where((ActivityEvent e) => _filter.matches(e))
        .where((ActivityEvent e) =>
            query.isEmpty ||
            e.title.toLowerCase().contains(query) ||
            e.volumeLabel.toLowerCase().contains(query) ||
            e.subtitle.toLowerCase().contains(query))
        .toList(growable: false);

    final Map<String, List<ActivityEvent>> grouped = DateX.groupByDay<ActivityEvent>(
      events,
      (ActivityEvent e) => e.timestamp,
    );

    final DateTime now = DateTime.now();
    final List<ActivityEvent> today = app.activity
        .where((ActivityEvent e) => DateX.sameDay(e.timestamp, now))
        .toList(growable: false);
    final int volumeToday = today
        .where((ActivityEvent e) =>
            e.type == ActivityType.transfer ||
            e.type == ActivityType.backup ||
            e.type == ActivityType.cleanup)
        .fold<int>(0, (int sum, ActivityEvent e) => sum + e.bytes);
    final int tasksToday = today
        .where((ActivityEvent e) => !e.isFailure)
        .length;
    final int errorsToday = today.where((ActivityEvent e) => e.isFailure).length;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          ScreenBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                PageHeader(
                  title: 'History',
                  subtitle: '${app.activity.length} local events',
                  padding: const EdgeInsets.fromLTRB(0, Insets.md, 0, Insets.md),
                  actions: <Widget>[
                    HeaderAction(
                      icon: _searchOpen ? Icons.close_rounded : Icons.search_rounded,
                      tooltip: 'Search history',
                      onTap: () {
                        setState(() {
                          _searchOpen = !_searchOpen;
                          if (!_searchOpen) _search.clear();
                        });
                      },
                    ),
                    HeaderAction(
                      icon: Icons.delete_sweep_outlined,
                      tooltip: 'Clear history',
                      onTap: app.activity.isEmpty ? () {} : _clear,
                    ),
                    HeaderAction(
                      icon: Icons.settings_rounded,
                      tooltip: 'Settings',
                      onTap: () => AppRoutes.settings(context),
                    ),
                  ],
                ),
                if (_searchOpen) ...<Widget>[
                  DpSearchField(
                    controller: _search,
                    hint: 'Search events, drives or files',
                    autofocus: true,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: Insets.md),
                ],
                DpCard(
                  color: c.surface,
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: TelemetryCell(
                          icon: Icons.data_usage_rounded,
                          label: 'Volume',
                          value: ByteFormat.format(volumeToday),
                          caption: 'moved today',
                          tint: c.primary,
                        ),
                      ),
                      _Divider(color: c.border),
                      Expanded(
                        child: TelemetryCell(
                          icon: Icons.task_alt_rounded,
                          label: 'Tasks',
                          value: '$tasksToday',
                          caption: 'completed',
                          tint: c.success,
                        ),
                      ),
                      _Divider(color: c.border),
                      Expanded(
                        child: TelemetryCell(
                          icon: Icons.shield_outlined,
                          label: 'Integrity',
                          value: '$errorsToday',
                          caption: errorsToday == 0 ? 'no errors' : 'failed tasks',
                          tint: errorsToday == 0 ? c.success : c.danger,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Insets.md),
                Builder(
                  builder: (BuildContext context) {
                    return DpFilterBar<_HistoryFilter>(
                      options: <FilterOption<_HistoryFilter>>[
                        for (final _HistoryFilter option in _HistoryFilter.values)
                          FilterOption<_HistoryFilter>(
                            value: option,
                            label: option.label,
                            count: option == _HistoryFilter.all
                                ? app.activity.length
                                : app.activity.where(option.matches).length,
                          ),
                      ],
                      selected: _filter,
                      onSelected: (_HistoryFilter value) =>
                          setState(() => _filter = value),
                    );
                  },
                ),
                const SizedBox(height: Insets.lg),
                if (events.isEmpty)
                  DpCard(
                    child: EmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: app.activity.isEmpty ? 'No activity yet' : 'No matching events',
                      message: app.activity.isEmpty
                          ? 'Transfers, ejects, benchmarks and cleanups are logged here — '
                              'only on this device.'
                          : 'Try a different filter or clear the search.',
                      actionLabel: _filter != _HistoryFilter.all || query.isNotEmpty
                          ? 'Reset filters'
                          : null,
                      onAction: () {
                        _search.clear();
                        setState(() => _filter = _HistoryFilter.all);
                      },
                      compact: true,
                    ),
                  )
                else
                  for (final MapEntry<String, List<ActivityEvent>> group
                      in grouped.entries) ...<Widget>[
                    SectionHeader(
                      title: group.key,
                      count: group.value.length,
                    ),
                    DpCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Insets.sm,
                        vertical: Insets.xs,
                      ),
                      child: Column(
                        children: <Widget>[
                          for (int i = 0; i < group.value.length; i++) ...<Widget>[
                            ActivityTile(
                              event: group.value[i],
                              onTap: () => _eventSheet(group.value[i]),
                            ),
                            if (i != group.value.length - 1)
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
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(Icons.lock_outline_rounded, size: 12, color: c.textFaint),
                      const SizedBox(width: 5),
                      Text(
                        'Stored on this device only',
                        style: AppType.labelCaps(c.textFaint).copyWith(fontSize: 9),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Insets.xl),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _eventSheet(ActivityEvent event) async {
    final AppColors c = context.colors;
    await showDpSheet<void>(
      context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SheetHeader(
            title: event.title,
            subtitle: event.subtitle.isEmpty ? event.type.label : event.subtitle,
          ),
          _Line(label: 'Type', value: event.type.label),
          _Line(label: 'Drive', value: event.volumeLabel.isEmpty ? 'All volumes' : event.volumeLabel),
          if (event.bytes > 0)
            _Line(label: 'Data', value: ByteFormat.format(event.bytes)),
          _Line(label: 'When', value: DateX.full(event.timestamp)),
          _Line(label: 'Status', value: event.resolvedStatus),
          const SizedBox(height: Insets.md),
          Row(
            children: <Widget>[
              Icon(
                event.isFailure ? Icons.error_outline_rounded : Icons.verified_outlined,
                size: 15,
                color: event.isFailure ? c.danger : c.success,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  event.isFailure
                      ? 'This operation reported an error.'
                      : 'Recorded locally. No data was uploaded.',
                  style: AppType.bodySmall(c.textMuted).copyWith(fontSize: 11.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.sm),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 34,
        color: color,
      );
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value});

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
            width: 80,
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
