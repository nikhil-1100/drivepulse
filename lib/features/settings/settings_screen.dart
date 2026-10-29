import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_type.dart';
import '../../core/utils/byte_format.dart';
import '../../core/widgets/dialogs.dart';
import '../../core/widgets/dp_card.dart';
import '../../core/widgets/dp_pill.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/sheets.dart';
import '../../data/services/settings_store.dart';
import '../../data/state/app_state.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Map<String, String>? _deviceInfo;

  @override
  void initState() {
    super.initState();
    context.read<AppState>().deviceInfo().then((Map<String, String> info) {
      if (mounted) setState(() => _deviceInfo = info);
    }).catchError((Object _) {});
  }

  Future<void> _resetPreferences() async {
    final bool confirmed = await showConfirmDialog(
      context,
      title: 'Reset preferences?',
      message:
          'Theme, default view, sorting and alert settings return to their defaults. '
          'Your files, favourites and activity history are kept.',
      confirmLabel: 'Reset',
      destructive: true,
      icon: Icons.restart_alt_rounded,
    );
    if (!confirmed || !mounted) return;
    await context.read<SettingsController>().resetPreferences();
    if (!mounted) return;
    showAppToast(context, 'Preferences reset to defaults');
  }

  Future<void> _clearHistory() async {
    final bool confirmed = await showConfirmDialog(
      context,
      title: 'Clear activity history?',
      message: 'The local activity log is removed. Files are untouched.',
      confirmLabel: 'Clear',
      destructive: true,
      icon: Icons.delete_sweep_outlined,
    );
    if (!confirmed || !mounted) return;
    await context.read<AppState>().clearHistory();
    if (!mounted) return;
    showAppToast(context, 'Activity history cleared');
  }

  Future<void> _privacySheet() {
    return showDpSheet<void>(
      context,
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SheetHeader(
            title: 'Privacy by architecture',
            subtitle: 'Not just a policy — there is no network code path',
          ),
          _PolicyPoint(
            icon: Icons.wifi_off_rounded,
            title: 'No network permission',
            body:
                'The release Android manifest omits INTERNET. The app cannot open a '
                'socket even if a third-party library tried to.',
          ),
          _PolicyPoint(
            icon: Icons.person_off_outlined,
            title: 'No account or identifier',
            body:
                'There is no sign-in, no device fingerprint and no analytics SDK. '
                'DrivePulse never asks who you are.',
          ),
          _PolicyPoint(
            icon: Icons.folder_outlined,
            title: 'Files stay where they are',
            body:
                'Browsing, hashing, benchmarking and encryption all run on-device. '
                'History is a local JSON log capped at 400 entries.',
          ),
          _PolicyPoint(
            icon: Icons.key_outlined,
            title: 'You hold the keys',
            body:
                'Vault passphrases are never stored. Losing a passphrase means the '
                'encrypted file cannot be recovered — that is the point.',
          ),
          SizedBox(height: Insets.sm),
        ],
      ),
    );
  }

  Future<void> _termsSheet() {
    return showDpSheet<void>(
      context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SheetHeader(title: 'Terms of use', subtitle: 'Short, because the app is local'),
          Text(
            'DrivePulse is a file-management utility. You are responsible for the '
            'files you copy, move or delete, and for keeping backups of anything '
            'important. Removable media can fail without warning; the health '
            'estimate is a local benchmark, not a manufacturer S.M.A.R.T. report. '
            'Formatting is delegated to the operating system.',
            style: AppType.bodyMedium(context.colors.textMuted).copyWith(height: 1.55),
          ),
          const SizedBox(height: Insets.md),
          Text(
            'Encrypted files use AES-256-GCM with PBKDF2-HMAC-SHA256 (120,000 rounds). '
            'No recovery mechanism exists. The software is provided “as is”, without '
            'warranty of any kind.',
            style: AppType.bodyMedium(context.colors.textMuted).copyWith(height: 1.55),
          ),
          const SizedBox(height: Insets.sm),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final SettingsController settings = context.watch<SettingsController>();
    final AppState app = context.watch<AppState>();

    return Scaffold(
      backgroundColor: c.canvas,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            ScreenBody(
              maxWidth: 760,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  PageHeader(
                    title: 'Settings',
                    subtitle: app.isDemo ? 'Preview build' : 'On-device configuration',
                    showBack: true,
                    padding: const EdgeInsets.fromLTRB(0, Insets.md, 0, Insets.md),
                    actions: <Widget>[
                      TextButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        child: Text(
                          'Done',
                          style: AppType.labelLarge(c.primary),
                        ),
                      ),
                    ],
                  ),
                  const _SectionLabel('Appearance'),
                  DpCard(
                    child: Column(
                      children: <Widget>[
                        const _ChoiceTitle(
                          icon: Icons.palette_outlined,
                          title: 'Theme',
                          subtitle: 'Applies instantly across the app',
                        ),
                        const SizedBox(height: Insets.sm),
                        _ChoiceRow<ThemeMode>(
                          values: const <ThemeMode>[
                            ThemeMode.system,
                            ThemeMode.light,
                            ThemeMode.dark,
                          ],
                          selected: settings.themeMode,
                          labelOf: (ThemeMode mode) => switch (mode) {
                            ThemeMode.system => 'System',
                            ThemeMode.light => 'Light',
                            ThemeMode.dark => 'Dark',
                          },
                          onSelected: settings.setThemeMode,
                        ),
                        const Divider(height: Insets.xl),
                        _SwitchRow(
                          icon: Icons.vertical_align_bottom_rounded,
                          title: 'Auto-hide navigation',
                          subtitle: 'Tuck the nav bar away while scrolling down',
                          value: settings.autoHideNav,
                          onChanged: settings.setAutoHideNav,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Insets.lg),
                  const _SectionLabel('Library'),
                  DpCard(
                    child: Column(
                      children: <Widget>[
                        const _ChoiceTitle(
                          icon: Icons.view_agenda_outlined,
                          title: 'Default view',
                          subtitle: 'File browser layout',
                        ),
                        const SizedBox(height: Insets.sm),
                        _ChoiceRow<LibraryView>(
                          values: LibraryView.values,
                          selected: settings.view,
                          labelOf: (LibraryView view) =>
                              view == LibraryView.list ? 'List' : 'Grid',
                          onSelected: settings.setView,
                        ),
                        const Divider(height: Insets.xl),
                        const _ChoiceTitle(
                          icon: Icons.sort_rounded,
                          title: 'Sort by',
                          subtitle: 'Folders always appear first',
                        ),
                        const SizedBox(height: Insets.sm),
                        _ChoiceRow<SortField>(
                          values: SortField.values,
                          selected: settings.sortField,
                          labelOf: (SortField field) => field.label,
                          onSelected: (SortField field) => settings.setSort(field),
                        ),
                        const Divider(height: Insets.xl),
                        const _ChoiceTitle(
                          icon: Icons.sd_storage_outlined,
                          title: 'Large-file threshold',
                          subtitle: 'Used by the storage analyzer',
                        ),
                        const SizedBox(height: Insets.sm),
                        _ChoiceRow<int>(
                          values: const <int>[50, 100, 250, 500],
                          selected: settings.largeFileThresholdMb,
                          labelOf: (int mb) => '$mb MB',
                          onSelected: settings.setLargeFileThreshold,
                        ),
                        const Divider(height: Insets.xl),
                        _SwitchRow(
                          icon: Icons.visibility_outlined,
                          title: 'Show hidden files',
                          subtitle: 'Includes dot-files and system folders',
                          value: settings.showHidden,
                          onChanged: settings.setShowHidden,
                        ),
                        const Divider(height: Insets.xl),
                        _SwitchRow(
                          icon: Icons.warning_amber_rounded,
                          title: 'Confirm destructive actions',
                          subtitle: 'Ask before deleting or ejecting',
                          value: settings.confirmDestructive,
                          onChanged: settings.setConfirmDestructive,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Insets.lg),
                  const _SectionLabel('Alerts & feedback'),
                  DpCard(
                    child: Column(
                      children: <Widget>[
                        _SwitchRow(
                          icon: Icons.notifications_none_rounded,
                          title: 'In-app alerts',
                          subtitle: 'Transfer completion and safe-eject notices',
                          value: settings.alertsEnabled,
                          onChanged: settings.setAlerts,
                        ),
                        const Divider(height: Insets.xl),
                        _SwitchRow(
                          icon: Icons.vibration_rounded,
                          title: 'Haptics',
                          subtitle: 'Tactile feedback on eject and transfers',
                          value: settings.haptics,
                          onChanged: settings.setHaptics,
                        ),
                        const Divider(height: Insets.xl),
                        const _ChoiceTitle(
                          icon: Icons.pie_chart_outline_rounded,
                          title: 'Low storage alert',
                          subtitle: 'Warn when a drive has less free space than',
                        ),
                        const SizedBox(height: Insets.sm),
                        _ChoiceRow<int>(
                          values: const <int>[5, 15, 30],
                          selected: settings.lowStoragePercent,
                          labelOf: (int percent) => '$percent%',
                          onSelected: settings.setLowStoragePercent,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Insets.lg),
                  const _SectionLabel('Privacy & data'),
                  DpCard(
                    color: c.surface,
                    child: Column(
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            IconTile(
                              icon: Icons.shield_outlined,
                              tint: c.success,
                              size: 40,
                            ),
                            const SizedBox(width: Insets.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    'Offline by design',
                                    style: AppType.headlineSmall(c.text)
                                        .copyWith(fontSize: 14),
                                  ),
                                  Text(
                                    'No account, no servers, no telemetry.',
                                    style: AppType.bodySmall(c.textMuted)
                                        .copyWith(fontSize: 11.5),
                                  ),
                                ],
                              ),
                            ),
                            const DpPill(
                              label: 'LOCAL',
                              tone: PillTone.success,
                              dense: true,
                              monospace: true,
                            ),
                          ],
                        ),
                        const SizedBox(height: Insets.md),
                        _LinkRow(
                          icon: Icons.privacy_tip_outlined,
                          label: 'How privacy works',
                          onTap: _privacySheet,
                        ),
                        const Divider(height: Insets.md),
                        _LinkRow(
                          icon: Icons.delete_sweep_outlined,
                          label: 'Clear activity history (${app.activity.length})',
                          onTap: app.activity.isEmpty ? null : _clearHistory,
                        ),
                        const Divider(height: Insets.md),
                        _LinkRow(
                          icon: Icons.restart_alt_rounded,
                          label: 'Reset preferences',
                          onTap: _resetPreferences,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Insets.lg),
                  const _SectionLabel('Device & storage'),
                  DpCard(
                    child: Column(
                      children: <Widget>[
                        _InfoRow(
                          label: 'Storage engine',
                          value: app.platformName,
                        ),
                        _InfoRow(
                          label: 'Platform',
                          value: _deviceInfo?['platform'] ?? 'Reading…',
                        ),
                        _InfoRow(
                          label: 'Device',
                          value: _deviceInfo?['model'] ?? '—',
                        ),
                        _InfoRow(
                          label: 'System',
                          value: _deviceInfo?['os'] ?? '—',
                        ),
                        _InfoRow(
                          label: 'Drives connected',
                          value: '${app.connectedVolumes.length}',
                        ),
                        _InfoRow(
                          label: 'Free on active drive',
                          value: app.currentVolume == null
                              ? '—'
                              : ByteFormat.format(app.currentVolume!.freeBytes),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Insets.lg),
                  const _SectionLabel('About'),
                  DpCard(
                    child: Column(
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: <Color>[c.primary, c.primaryDeep],
                                ),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(Icons.storage_rounded,
                                  color: c.onPrimary, size: 23),
                            ),
                            const SizedBox(width: Insets.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    'DrivePulse',
                                    style: AppType.headlineSmall(c.text),
                                  ),
                                  Text(
                                    'External drive manager • v1.0.0 (1)',
                                    style: AppType.bodySmall(c.textMuted)
                                        .copyWith(fontSize: 11.5),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: Insets.md),
                        _LinkRow(
                          icon: Icons.description_outlined,
                          label: 'Terms of use',
                          onTap: _termsSheet,
                        ),
                        const Divider(height: Insets.md),
                        _LinkRow(
                          icon: Icons.code_rounded,
                          label: 'Open-source licences',
                          onTap: () => showLicensePage(
                            context: context,
                            applicationName: 'DrivePulse',
                            applicationVersion: '1.0.0',
                            applicationLegalese: 'Offline drive manager for Android and iOS',
                          ),
                        ),
                        const SizedBox(height: Insets.md),
                        Text(
                          'Android and iOS do not expose raw block devices to third-party '
                          'apps. DrivePulse works inside the scoped access the OS grants '
                          '(SAF on Android, authorised folders on iOS) and never claims '
                          'capabilities the platform withholds.',
                          style: AppType.bodySmall(c.textFaint)
                              .copyWith(fontSize: 10.5, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Insets.xxl),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: Insets.sm),
      child: Text(
        label.toUpperCase(),
        style: AppType.labelCaps(context.colors.textFaint),
      ),
    );
  }
}

class _ChoiceTitle extends StatelessWidget {
  const _ChoiceTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return Row(
      children: <Widget>[
        Icon(icon, size: 17, color: c.textMuted),
        const SizedBox(width: Insets.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: AppType.bodyMedium(c.text).copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 13.5,
                ),
              ),
              Text(
                subtitle,
                style: AppType.bodySmall(c.textMuted).copyWith(fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChoiceRow<T> extends StatelessWidget {
  const _ChoiceRow({
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
  });

  final List<T> values;
  final T selected;
  final String Function(T value) labelOf;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        for (final T value in values)
          ChoiceChip(
            selected: value == selected,
            onSelected: (_) => onSelected(value),
            label: Text(labelOf(value)),
            labelStyle: AppType.bodySmall(c.text).copyWith(
              fontSize: 12,
              fontWeight: value == selected ? FontWeight.w700 : FontWeight.w500,
              color: value == selected ? c.onPrimary : c.text,
            ),
            selectedColor: c.primary,
            backgroundColor: c.surfaceAlt,
            side: BorderSide(color: c.border),
            showCheckmark: false,
          ),
      ],
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return Row(
      children: <Widget>[
        Icon(icon, size: 17, color: c.textMuted),
        const SizedBox(width: Insets.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: AppType.bodyMedium(c.text).copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 13.5,
                ),
              ),
              Text(
                subtitle,
                style: AppType.bodySmall(c.textMuted).copyWith(fontSize: 11),
              ),
            ],
          ),
        ),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 17, color: onTap == null ? c.textFaint : c.textMuted),
            const SizedBox(width: Insets.sm),
            Expanded(
              child: Text(
                label,
                style: AppType.bodyMedium(onTap == null ? c.textFaint : c.text)
                    .copyWith(fontSize: 13),
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 17, color: c.textFaint),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: AppType.bodySmall(c.textMuted).copyWith(fontSize: 12.5),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppType.monoSmall(c.text).copyWith(fontSize: 10.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _PolicyPoint extends StatelessWidget {
  const _PolicyPoint({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          IconTile(icon: icon, tint: c.success, size: 34, radius: 11, iconSize: 17),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: AppType.bodyMedium(c.text).copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: AppType.bodySmall(c.textMuted).copyWith(height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
