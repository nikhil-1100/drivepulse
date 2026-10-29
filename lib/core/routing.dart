import 'package:flutter/material.dart';

import '../../data/models/volume.dart';
import '../features/browse/browse_screen.dart';
import '../features/browse/favorites_screen.dart';
import '../features/cleanup/cleanup_screen.dart';
import '../features/drives/drive_details_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/transfers/transfers_screen.dart';
import '../features/vault/vault_screen.dart';

/// Typed navigation helpers. Direct MaterialPageRoute pushes keep argument
/// passing type-safe (no string routes or untyped bags).
abstract final class AppRoutes {
  static Future<T?> _push<T extends Object?>(
    BuildContext context,
    Widget page,
  ) {
    return Navigator.of(context).push<T>(
      MaterialPageRoute<T>(builder: (_) => page),
    );
  }

  static Future<void> browse(
    BuildContext context, {
    Volume? volume,
    String? path,
    bool selectMode = false,
  }) {
    return _push<void>(
      context,
      BrowseScreen(volume: volume, initialPath: path, selectMode: selectMode),
    );
  }

  static Future<void> favorites(BuildContext context, {Volume? volume}) {
    return _push<void>(context, FavoritesScreen(volume: volume));
  }

  static Future<void> driveDetails(BuildContext context, Volume volume) {
    return _push<void>(context, DriveDetailsScreen(volume: volume));
  }

  static Future<void> settings(BuildContext context) {
    return _push<void>(context, const SettingsScreen());
  }

  static Future<void> cleanup(BuildContext context, {Volume? volume}) {
    return _push<void>(context, CleanupScreen(volume: volume));
  }

  static Future<void> transfers(BuildContext context) {
    return _push<void>(context, const TransfersScreen());
  }

  static Future<void> vault(BuildContext context, {Volume? volume}) {
    return _push<void>(context, VaultScreen(volume: volume));
  }
}
