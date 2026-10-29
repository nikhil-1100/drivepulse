# Architecture

DrivePulse is a Flutter application with a deliberately thin, explicit layering. Every layer has one job and no layer reaches around another.

```
┌────────────────────────────────────────────────────────────┐
│ features/*  (screens, sheets, dialogs)                     │
│   read: context.watch<AppState>() / SettingsController     │
│   act : context.read<AppState>().copyFiles(...)            │
└───────────────▲────────────────────────────┬───────────────┘
                │ notifyListeners            │ intents
┌───────────────┴────────────────────────────▼───────────────┐
│ data/state/AppState  — one source of truth                 │
│   volumes, active drive, activity, scans, vault, notices   │
│   owns TransferController, AnalyzerService, stores         │
└───────────────▲────────────────────────────┬───────────────┘
                │ models                     │ StorageService
┌───────────────┴──────────────┐  ┌──────────▼───────────────┐
│ data/models (immutable)      │  │ NativeStorageService      │
│ Volume, FileEntry, Task,     │  │   MethodChannel + events  │
│ ActivityEvent, Reports       │  ├───────────────────────────┤
└──────────────────────────────┘  │ DemoStorageService        │
                                  │   in-memory preview tree  │
                                  └───────────────────────────┘
```

## State ownership

`AppState` is created once in `main.dart` after `SettingsController` loads. Screens never mutate `FileEntry` lists directly; every action goes through a method that performs the storage call, records an activity event and notifies listeners.

Transfers live in their own `ChangeNotifier` (`TransferController`) because progress ticks arrive several times per second. The dashboard, transfer screen and shell watch that controller separately so a tick does not rebuild the entire tree.

`SettingsController` is split from `AppState` because the theme depends on it above `MaterialApp`.

## Startup sequence

1. `WidgetsFlutterBinding.ensureInitialized()`.
2. `SettingsController.load()` from SharedPreferences.
3. Storage backend selection: native channel on Android/iOS, demo everywhere else.
4. `ActivityStore.load()` — JSON in the support directory, or SharedPreferences on web.
5. `AppState.refreshVolumes()` enumerates volumes and chooses the active drive (first connected removable, else internal).
6. Volume event stream subscription (Android broadcast receiver).
7. `runApp` with `MultiProvider`.
8. If onboarding was not completed, the onboarding flow is shown first.

## Storage abstraction

`StorageService` is the only interface the app knows. It returns domain models, never platform maps. `NativeStorageService` translates MethodChannel dictionaries into models and converts platform errors into `StorageException` with stable codes:

| Code | Meaning | UI response |
| --- | --- | --- |
| `permission` | SAF/scoped-storage denial | Inline banner with "Grant" |
| `not_found` | Removed folder or stale bookmark | Empty state + rescan |
| `exists` | Name collision | Rename/new-folder validation |
| `cancelled` | User cancelled a transfer | Task marked cancelled, not failed |
| `unavailable` | No native bridge (desktop/web) | Demo backend is used instead |
| `io` | Filesystem failure | Toast with platform message |

## Copy pipeline

```
Browse / Backup
   → AppState.transferFiles (measures folders once)
   → TransferController.start (task + CancelToken)
   → StorageService.transfer
        Android: executor + streaming 256 KB chunks, progress every 512 KB
        iOS    : FileManager copy with per-item progress
        Demo   : in-memory tree mutation with simulated ticks
   → progress callback updates the task
   → completion logs an ActivityEvent and refreshes volume capacity
```

One job runs at a time. Pausing is cooperative and takes effect between files; cancelling stops at the next chunk/file boundary. This is stated in the UI rather than pretending to support mid-chunk suspension.

## Analyzer

`AnalyzerService` walks a single volume with an explicit stack, a 24,000-entry cap and a depth limit. It streams entries into:

- category totals (no folder double-counting),
- junk candidates (cache/temp/log/trash segments or extensions),
- large files above the configured threshold,
- empty folders,
- files untouched for 180+ days,
- duplicate groups (same size ≥ 1 MB, verified with SHA-256, capped at 400 hashes).

Duplicate deletion always keeps at least one copy and requires explicit confirmation.

## Encryption

`EncryptionService` produces a self-describing container:

```
"DPV1" | salt(16) | nonce(12) | ciphertext | GCM tag(16)
```

PBKDF2-HMAC-SHA256 with 120,000 iterations derives a 256-bit key. AES-256-GCM authenticates both ciphertext and header association. Wrong passphrase and tampering produce the same `EncryptionException`. Files are capped at 128 MB for the in-memory path; the README and vault screen say so.

## Theming

`AppTheme` builds Material 3 from an explicit `ColorScheme` plus an `AppColors` `ThemeExtension`. Components read `context.colors` so no screen hard-codes a hex value. Typography is built from variable fonts with `fontVariations` so weights render correctly on Impeller, Skia and CanvasKit.

## Failure strategy

- A missing native bridge degrades to the demo backend on desktop/web rather than crashing.
- A failed volume refresh leaves the last known volumes visible and surfaces the error in a banner.
- History writes are coalesced and failures are debug-logged, never fatal.
- The app never deletes without confirmation.

## Threading

Android does all I/O that can block on a two-thread executor; results and progress are marshalled to the UI thread through `runOnUiThread`. Dart's transfer progress handler updates state on the platform thread, which is the Flutter UI thread. iOS uses a serial `ioQueue` and dispatches results to the main queue.
