import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'data/services/settings_store.dart';
import 'data/state/app_state.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/shell/app_shell.dart';

class DrivePulseApp extends StatelessWidget {
  const DrivePulseApp({super.key});

  @override
  Widget build(BuildContext context) {
    final SettingsController settings = context.watch<SettingsController>();
    final bool previewShell =
        kIsWeb && Uri.base.queryParameters['skipIntro'] == '1';

    return MaterialApp(
      title: 'DrivePulse',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: settings.themeMode,
      home: settings.onboarded || previewShell
          ? const AppNoticeBridge(child: AppShell())
          : const OnboardingScreen(),
      builder: (BuildContext context, Widget? child) {
        final MediaQueryData media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: media.textScaler.clamp(
              minScaleFactor: 0.9,
              maxScaleFactor: 1.25,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}

/// Shows app-level one-shot notices (transfer finished, space freed) as
/// snackbars, so individual screens do not each need a listener.
class AppNoticeBridge extends StatefulWidget {
  const AppNoticeBridge({super.key, required this.child});

  final Widget child;

  @override
  State<AppNoticeBridge> createState() => _AppNoticeBridgeState();
}

class _AppNoticeBridgeState extends State<AppNoticeBridge> {
  AppState? _appState;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final AppState state = context.read<AppState>();
    if (identical(_appState, state)) return;
    _appState?.noticeFeed.removeListener(_onNotice);
    _appState = state;
    _appState!.noticeFeed.addListener(_onNotice);
  }

  void _onNotice() {
    final String? message = _appState?.noticeFeed.value;
    if (message == null || !mounted) return;
    _appState?.noticeFeed.value = null;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: <Widget>[
            const Icon(
              Icons.check_circle_rounded,
              size: 18,
              color: Color(0xFF34D399),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        action: SnackBarAction(
          label: 'History',
          onPressed: () => AppShell.goToTab(context, 2),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _appState?.noticeFeed.removeListener(_onNotice);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
