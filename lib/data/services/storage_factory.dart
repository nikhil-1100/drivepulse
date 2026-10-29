import 'package:flutter/foundation.dart';

import 'demo_storage_service.dart';
import 'native_storage_service.dart';
import 'storage_service.dart';

/// Chooses the storage backend for the current platform.
///
/// Only Android and iOS have the native bridge. Web, Windows and Linux (used by
/// design QA) fall back to the in-memory demo drive so the app still runs and
/// no fake filesystem operations can be mistaken for real ones.
StorageService createStorageService({bool? forceDemo}) {
  if (forceDemo == true) return DemoStorageService();
  if (kIsWeb) return DemoStorageService();
  if (defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS) {
    return NativeStorageService();
  }
  return DemoStorageService();
}
