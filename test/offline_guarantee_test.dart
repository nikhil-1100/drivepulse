import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// These tests encode the product's core promise: the app is local-only.
/// They are intentionally boring and run on every CI pass.
void main() {
  test('release Android manifest has no INTERNET permission', () {
    final File manifest =
        File('android/app/src/main/AndroidManifest.xml');
    expect(manifest.existsSync(), isTrue);
    final String xml = manifest.readAsStringSync();
    expect(
      xml.contains('<uses-permission android:name="android.permission.INTERNET"'),
      isFalse,
      reason: 'DrivePulse must remain unable to open a socket.',
    );
    expect(xml.contains('android:usesCleartextTraffic="false"'), isTrue);
    expect(xml.contains('android:allowBackup="false"'), isTrue);
  });

  test('no analytics or remote-configuration dependencies', () {
    final String pubspec = File('pubspec.yaml').readAsStringSync();
    for (final String banned in <String>[
      'firebase',
      'sentry',
      'amplitude',
      'mixpanel',
      'appsflyer',
      'segment',
      'http:',
      'dio:',
    ]) {
      expect(
        pubspec.contains(banned),
        isFalse,
        reason: 'Unexpected dependency: $banned',
      );
    }
  });

  test('iOS documents folder is exposed through Files', () {
    final String plist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(plist.contains('<key>UIFileSharingEnabled</key>'), isTrue);
    expect(plist.contains('<key>LSSupportsOpeningDocumentsInPlace</key>'), isTrue);
  });

  test('native bridges are present for both platforms', () {
    expect(
      File('android/app/src/main/kotlin/com/drivepulse/app/StorageBridge.kt').existsSync(),
      isTrue,
    );
    expect(File('ios/Runner/StorageBridge.swift').existsSync(), isTrue);
  });
}
