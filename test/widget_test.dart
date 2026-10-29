import 'package:drivepulse/core/theme/app_theme.dart';
import 'package:drivepulse/data/models/volume.dart';
import 'package:drivepulse/data/services/activity_store.dart';
import 'package:drivepulse/data/services/demo_storage_service.dart';
import 'package:drivepulse/data/services/encryption_service.dart';
import 'package:drivepulse/data/services/settings_store.dart';
import 'package:drivepulse/data/services/transfer_controller.dart';
import 'package:drivepulse/data/state/app_state.dart';
import 'package:drivepulse/features/browse/browse_screen.dart';
import 'package:drivepulse/features/dashboard/dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppState> _buildState() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SettingsController settings = await SettingsController.load();
  final AppState state = AppState(
    storage: DemoStorageService(),
    settings: settings,
    activityStore: ActivityStore(),
    encryption: EncryptionService(iterations: 1000),
  );
  await state.init();
  return state;
}

Widget _wrap(AppState state, Widget child) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<SettingsController>.value(value: state.settings),
      ChangeNotifierProvider<AppState>.value(value: state),
      ChangeNotifierProvider<TransferController>.value(value: state.transfers),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      home: child,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('dashboard renders storage, gauges and quick actions',
      (WidgetTester tester) async {
    final AppState state = (await tester.runAsync(_buildState))!;
    addTearDown(state.dispose);

    await tester.pumpWidget(_wrap(state, const DashboardScreen()));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('DrivePulse'), findsWidgets);
    expect(find.text('Storage'), findsOneWidget);
    expect(find.text('Quick actions'), findsOneWidget);
    expect(find.text('SanDisk Ultra Luxe'), findsWidgets);
    expect(find.text('Drive health'), findsOneWidget);
    expect(find.textContaining('Preview mode'), findsOneWidget);
  });

  testWidgets('file browser lists seeded folders and files',
      (WidgetTester tester) async {
    final AppState state = (await tester.runAsync(_buildState))!;
    addTearDown(state.dispose);
    final Volume sandisk = state.connectedVolumes
        .firstWhere((Volume v) => v.id == 'sandisk-ultra');

    await tester.pumpWidget(_wrap(state, BrowseScreen(volume: sandisk)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Camera_RAW'), findsOneWidget);
    expect(find.text('Client_Deliverables'), findsOneWidget);
    expect(find.text('Folders'), findsOneWidget);
    expect(find.text('Files'), findsOneWidget);
    expect(find.text('IMG_2024_Hero.raw'), findsOneWidget);
  });

  testWidgets('search filters the browser and shows results',
      (WidgetTester tester) async {
    final AppState state = (await tester.runAsync(_buildState))!;
    addTearDown(state.dispose);
    final Volume sandisk = state.connectedVolumes
        .firstWhere((Volume v) => v.id == 'sandisk-ultra');

    await tester.pumpWidget(_wrap(state, BrowseScreen(volume: sandisk)));
    await tester.pump(const Duration(milliseconds: 400));

    await tester.enterText(find.byType(TextField).first, 'Hero');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Results'), findsOneWidget);
    expect(find.textContaining('IMG_2024_Hero'), findsWidgets);
  });
}
