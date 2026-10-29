import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_type.dart';
import '../../core/widgets/dp_gauge.dart';
import '../../data/models/volume.dart';
import '../../data/services/settings_store.dart';
import '../../data/state/app_state.dart';
import '../dashboard/dashboard_screen.dart';
import '../drives/drives_screen.dart';
import '../history/history_screen.dart';
import '../settings/settings_screen.dart';

/// Root shell: three tabs with a floating instrument-style nav bar on phones and
/// a side rail on tablets/desktop, plus scroll-aware auto-hide.
class AppShell extends StatefulWidget {
  const AppShell({super.key, this.initialIndex = 1});

  final int initialIndex;

  static final ValueNotifier<int?> _tabRequest = ValueNotifier<int?>(null);

  static void goToTab(BuildContext context, int index) {
    _tabRequest.value = index;
  }

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late int _index = widget.initialIndex;
  bool _navVisible = true;

  @override
  void initState() {
    super.initState();
    AppShell._tabRequest.addListener(_consumeTabRequest);
  }

  void _consumeTabRequest() {
    final int? request = AppShell._tabRequest.value;
    if (request == null) return;
    AppShell._tabRequest.value = null;
    if (!mounted) return;
    setState(() {
      _index = request;
      _navVisible = true;
    });
  }

  void _select(int index) {
    if (context.read<SettingsController>().haptics) {
      HapticFeedback.selectionClick();
    }
    setState(() {
      _index = index;
      _navVisible = true;
    });
  }

  bool _handleScroll(ScrollNotification notification) {
    final bool autoHide = context.read<SettingsController>().autoHideNav;
    if (!autoHide || notification.depth != 0) return false;
    if (notification is ScrollUpdateNotification) {
      final double delta = notification.scrollDelta ?? 0;
      if (delta > 8 && _navVisible) {
        setState(() => _navVisible = false);
      } else if (delta < -8 && !_navVisible) {
        setState(() => _navVisible = true);
      }
    }
    if (notification is ScrollEndNotification && !_navVisible) {
      // Reappear when the user stops dragging upward at the top.
      if (notification.metrics.pixels <= 8) {
        setState(() => _navVisible = true);
      }
    }
    return false;
  }

  @override
  void dispose() {
    AppShell._tabRequest.removeListener(_consumeTabRequest);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final double width = MediaQuery.sizeOf(context).width;
    final bool wide = width >= 900;
    final bool keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    final Widget body = NotificationListener<ScrollNotification>(
      onNotification: _handleScroll,
      child: IndexedStack(
        index: _index,
        children: const <Widget>[
          DrivesScreen(),
          DashboardScreen(),
          HistoryScreen(),
        ],
      ),
    );

    if (wide) {
      return Scaffold(
        backgroundColor: c.canvas,
        body: Row(
          children: <Widget>[
            _SideRail(index: _index, onSelect: _select),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: c.canvas,
      extendBody: true,
      body: Padding(
        padding: EdgeInsets.only(bottom: keyboardOpen ? 0 : 84),
        child: body,
      ),
      bottomNavigationBar: keyboardOpen
          ? null
          : AnimatedSlide(
              offset: _navVisible ? Offset.zero : const Offset(0, 1.4),
              duration: DpDurations.base,
              curve: Curves.easeOutCubic,
              child: _BottomNav(
                index: _index,
                onSelect: _select,
              ),
            ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.index, required this.onSelect});

  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final AppState app = context.watch<AppState>();
    final Volume? active = app.currentVolume;

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: SizedBox(
        height: 74,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: <Widget>[
            Container(
              height: 66,
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(Radii.pill),
                border: Border.all(color: c.border),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: c.shadow,
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: _NavItem(
                      icon: Icons.storage_rounded,
                      label: 'Drives',
                      active: index == 0,
                      onTap: () => onSelect(0),
                    ),
                  ),
                  const SizedBox(width: 74),
                  Expanded(
                    child: _NavItem(
                      icon: Icons.receipt_long_rounded,
                      label: 'History',
                      active: index == 2,
                      onTap: () => onSelect(2),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: 14,
              child: _HomeOrb(
                active: index == 1,
                volume: active,
                onTap: () => onSelect(1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return Semantics(
      selected: active,
      button: true,
      label: label,
      child: InkResponse(
        onTap: onTap,
        radius: 34,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 21, color: active ? c.primary : c.textFaint),
            const SizedBox(height: 3),
            Text(
              label,
              style: AppType.labelCaps(active ? c.primary : c.textFaint)
                  .copyWith(fontSize: 9.5),
            ),
          ],
        ),
      ),
    );
  }
}

/// Raised centre control: the ring doubles as live usage telemetry for the
/// active drive.
class _HomeOrb extends StatelessWidget {
  const _HomeOrb({
    required this.active,
    required this.onTap,
    required this.volume,
  });

  final bool active;
  final VoidCallback onTap;
  final Volume? volume;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final double used = volume?.usedFraction ?? 0;
    final bool critical = volume?.isCritical ?? false;

    return Semantics(
      button: true,
      label: 'Home${volume == null ? '' : ', ${volume?.label} ${(used * 100).round()} percent used'}',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 62,
          height: 62,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: c.obsidian,
            border: Border.all(color: c.surface, width: 3),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: c.primary.withValues(alpha: active ? 0.35 : 0.18),
                blurRadius: 18,
                spreadRadius: 1,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              DpGauge(
                value: used,
                size: 50,
                color: critical ? c.danger : c.success,
                trackColor: c.onObsidian.withValues(alpha: 0.16),
                strokeWidth: 3,
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.home_rounded, size: 19, color: c.onObsidian),
                  Text(
                    volume == null ? '—' : '${(used * 100).round()}%',
                    style: AppType.labelCaps(c.onObsidian.withValues(alpha: 0.95))
                        .copyWith(fontSize: 8, height: 1.1),
                  ),
                ],
              ),
              if (volume?.isConnected == true)
                Positioned(
                  right: 4,
                  top: 6,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: c.success,
                      shape: BoxShape.circle,
                      border: Border.all(color: c.obsidian, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SideRail extends StatelessWidget {
  const _SideRail({required this.index, required this.onSelect});

  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return Container(
      width: 92,
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(right: BorderSide(color: c.border)),
      ),
      child: SafeArea(
        child: Column(
          children: <Widget>[
            const SizedBox(height: Insets.md),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: <Color>[c.primary, c.primaryDeep]),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(Icons.storage_rounded, color: c.onPrimary, size: 21),
            ),
            const SizedBox(height: Insets.xl),
            _RailItem(
              icon: Icons.storage_rounded,
              label: 'Drives',
              active: index == 0,
              onTap: () => onSelect(0),
            ),
            _RailItem(
              icon: Icons.home_rounded,
              label: 'Home',
              active: index == 1,
              onTap: () => onSelect(1),
            ),
            _RailItem(
              icon: Icons.receipt_long_rounded,
              label: 'History',
              active: index == 2,
              onTap: () => onSelect(2),
            ),
            const Spacer(),
            _RailItem(
              icon: Icons.settings_rounded,
              label: 'Settings',
              active: false,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
              ),
            ),
            const SizedBox(height: Insets.md),
          ],
        ),
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
      child: Material(
        color: active ? c.primarySoft : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              children: <Widget>[
                Icon(icon, size: 21, color: active ? c.primary : c.textMuted),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: AppType.labelCaps(active ? c.primary : c.textFaint)
                      .copyWith(fontSize: 9),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
