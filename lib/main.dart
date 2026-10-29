import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'app.dart';
import 'data/services/activity_store.dart';
import 'data/services/encryption_service.dart';
import 'data/services/settings_store.dart';
import 'data/services/storage_factory.dart';
import 'data/services/transfer_controller.dart';
import 'data/state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final SettingsController settings = await SettingsController.load();

  // Preview-only URL switches used by the web build, screenshots and design QA.
  // They never exist on Android/iOS and never touch network code.
  if (kIsWeb) {
    final Uri base = Uri.base;
    switch (base.queryParameters['theme']) {
      case 'dark':
        await settings.setThemeMode(ThemeMode.dark);
      case 'light':
        await settings.setThemeMode(ThemeMode.light);
    }
  }

  final AppState appState = AppState(
    storage: createStorageService(),
    settings: settings,
    activityStore: ActivityStore(),
    encryption: EncryptionService(),
  );
  await appState.init();

  runApp(
    MultiProvider(
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<SettingsController>.value(value: settings),
        ChangeNotifierProvider<AppState>.value(value: appState),
        ChangeNotifierProvider<TransferController>.value(value: appState.transfers),
      ],
      child: const DrivePulseApp(),
    ),
  );
}
