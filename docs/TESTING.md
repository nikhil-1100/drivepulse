# Testing

## Automated

```bash
flutter analyze     # must report: No issues found!
flutter test        # 42 tests, all green
```

| Suite | Covers |
| --- | --- |
| `test/byte_format_test.dart` | decimal units, truncating percentages, speeds, ETA |
| `test/file_kind_test.dart` | extension classification, chips, categories |
| `test/encryption_test.dart` | AES-GCM round-trip, wrong passphrase, tamper detection, naming |
| `test/demo_storage_test.dart` | volume/listing/search, create/rename/delete, copy/move, cancel, eject |
| `test/analyzer_test.dart` | breakdown, junk detection, duplicates, large/stale files, cancellation |
| `test/widget_test.dart` | dashboard render, file browser render, recursive search results |
| `test/offline_guarantee_test.dart` | no INTERNET permission, no analytics deps, iOS Files exposure, bridges present |

Widget tests initialise the real `AppState` against `DemoStorageService`; plugin
calls that need a platform (path_provider) are wrapped in `tester.runAsync` and
degrade gracefully with a debug log, so tests stay hermetic.

## Manual device checklist

Run on a real handset — emulators cannot exercise OTG or SAF properly.

### Android

1. Plug a USB-C flash drive through an OTG adapter; grant access when prompted.
2. Confirm the drive appears in Storage and Drives with correct capacity.
3. Browse into a folder, copy a large file to internal storage; watch progress,
   pause/resume, then cancel a second job halfway.
4. Grant a SAF folder with **+** in Drives; verify it appears as an authorised
   folder and can be browsed.
5. Run a benchmark; confirm read/write values are plausible and the note says
   S.M.A.R.T. is unavailable.
6. Encrypt a file, verify the `.dpv` container and the original removal, then
   decrypt with the same passphrase and with a wrong one.
7. Scan storage; confirm junk/duplicate counts, delete a duplicate group and
   ensure at least one copy remains.
8. Eject from Drive details; verify the app releases the volume and explains the
   OS-level unmount limitation.
9. Put the phone in airplane mode; everything above must still work.

### iOS

1. Open Files → On My iPhone → DrivePulse; confirm the Documents folder is
   visible (file sharing keys are set).
2. Use **+** in Drives to authorise an external folder or another app's folder.
3. Browse, copy a folder, rename, delete, benchmark the app container.
4. Relaunch; confirm bookmark roots are restored.
5. Encrypt/decrypt a small file; lose the passphrase on purpose and verify the
   error is clear and no partial plaintext is written.

### Layout

- 320–430 dp phones, 7–13" tablets, landscape.
- Text scale 1.3.
- Light and dark themes.
- Wide layout: side rail appears at ≥ 900 dp.

## What is not covered

- Native Kotlin/Swift compilation and on-device behaviour require Android SDK /
  Xcode; this repository's CI machine only runs Dart analysis and tests.
- Formatting and forced unmount are intentionally delegated to the OS.
- Files above 128 MB cannot be encrypted in memory yet.
