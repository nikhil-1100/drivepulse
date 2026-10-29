# Native bridge contract

Channel names:

| Channel | Type | Purpose |
| --- | --- | --- |
| `drivepulse/storage` | `MethodChannel` | request/response operations |
| `drivepulse/volumes` | `EventChannel` | volume hot-plug events (Android) |

Implementations:

- Android: `android/app/src/main/kotlin/com/drivepulse/app/StorageBridge.kt` (registered by `MainActivity`).
- iOS: `ios/Runner/StorageBridge.swift` (registered by `AppDelegate`).
- Dart client: `lib/data/services/native_storage_service.dart`.

## Methods

| Method | Arguments | Result |
| --- | --- | --- |
| `listVolumes` | — | `List<VolumeMap>` |
| `refreshVolume` | `volumeId` | `VolumeMap?` |
| `listDirectory` | `path` | `List<FileMap>` |
| `stat` | `path` | `FileMap?` |
| `summarize` | `path`, `maxDepth`, `maxEntries` | `{bytes, items, folders}` |
| `search` | `root`, `query`, `limit` | `List<FileMap>` |
| `createFolder` | `parent`, `name` | — |
| `rename` | `path`, `newName` | — |
| `delete` | `entries: [{path,isDirectory}]` | — |
| `transfer` | `taskId`, `sources: [{path,name,isDirectory}]`, `destination`, `move` | `{bytes, items}` |
| `pauseTransfer` | `taskId`, `paused` | — |
| `cancelTransfer` | `taskId` | — |
| `benchmark` | `volumeId` | `{readMbps, writeMbps, latencyMs, healthPercent, smartSupported, notes}` |
| `eject` | `volumeId` | `true` |
| `readFile` | `path` | `Uint8List` |
| `writeFile` | `path`, `bytes` | — |
| `hashFile` | `path` | hex SHA-256 |
| `exists` | `path` | `bool` |
| `pickDirectory` | — | `FileMap?` |
| `pickFiles` | `multiple` | `List<FileMap>` |
| `deviceInfo` | — | `{platform, model, os, engine}` |

### Native → Dart callback

`transferProgress` on the same `MethodChannel`:

```
{ taskId, doneBytes, totalBytes, currentFile, bytesPerSecond }
```

## Volume map

```json
{
  "id": "vol:8A2F-1C4B",
  "label": "SanDisk Ultra Luxe",
  "fileSystem": "unknown",
  "totalBytes": 128000000000,
  "freeBytes": 44000000000,
  "kind": "usbFlash",
  "busLabel": "USB OTG",
  "protocolLabel": "USB",
  "serial": "8A2F-1C4B",
  "mountPath": "/storage/8A2F-1C4B",
  "readMbps": 0,
  "writeMbps": 0,
  "healthPercent": 100,
  "isReadOnly": false,
  "isConnected": true,
  "smartSupported": false,
  "lastSeen": "2026-10-29T08:00:00.000Z"
}
```

`kind` must be one of `internal`, `usbFlash`, `externalSsd`, `sdCard`, `hdd`.

Recognised volume id prefixes:

- `internal` — primary shared storage.
- `vol:<uuid>` — mounted removable volume.
- `tree:<content-uri>` — Android SAF tree authorised by the user.
- `ios-documents` — app Documents folder.
- `bm:<index>` — iOS security-scoped bookmark root.

## File map

```json
{
  "path": "/storage/8A2F-1C4B/Camera_RAW/RAW_01.cr2",
  "name": "RAW_01.cr2",
  "isDirectory": false,
  "sizeBytes": 210000000,
  "modifiedAt": "2026-10-29T06:41:00.000Z",
  "childCount": null,
  "isHidden": false
}
```

For SAF/bookmark roots, `path` may be a `content://` URI. Dart treats it as opaque and sends it back unchanged.

## Error codes

Native errors are `FlutterError`/`result.error(code, message, null)`:

`permission`, `not_found`, `exists`, `cancelled`, `too_large`, `io`, `invalid`.

Dart maps `PlatformException(code:)` to `StorageException(code:)`.

## Android notes

- Volume enumeration uses `StorageManager.storageVolumes`; directories are only available on API 30+, so API 24–29 uses `/storage/<uuid>`.
- Scoped storage denies direct listing of some paths; the UI offers `pickDirectory` which persists a SAF grant (`takePersistableUriPermission`).
- Formatting and forced unmounting are not exposed to third-party apps. `eject` flushes and releases the app's own handles; the UI tells the user to unplug.
- `S.M.A.R.T.` is unavailable; `Benchmark` measures an 8 MB sequential write + read-back.
- Volume changes arrive through a non-exported receiver for `MEDIA_*` and `USB_DEVICE_*` broadcasts.

## iOS notes

- iOS does not expose raw USB block devices to apps. The bridge manages the app Documents folder plus folders the user authorises in the picker, stored as security-scoped bookmarks in `UserDefaults`.
- `UIFileSharingEnabled` and `LSSupportsOpeningDocumentsInPlace` make the Documents folder visible in Files.
- Bookmarks are re-resolved at launch; stale bookmarks are skipped.
- Volume events are emitted once on listen and on each picker grant.

## Adding a platform

Implement `StorageService` in Dart (or a channel) and extend `createStorageService()`:

```dart
StorageService createStorageService({bool? forceDemo}) {
  if (kIsWeb) return DemoStorageService();
  if (defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS) {
    return NativeStorageService();
  }
  return DemoStorageService();
}
```

The domain layer, analyzer and UI need no changes.
