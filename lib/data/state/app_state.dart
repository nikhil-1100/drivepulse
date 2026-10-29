import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

import '../../core/utils/byte_format.dart';
import '../models/activity_event.dart';
import '../models/clean_up_report.dart';
import '../models/drive_health.dart';
import '../models/file_entry.dart';
import '../models/transfer_task.dart';
import '../models/volume.dart';
import '../services/activity_store.dart';
import '../services/analyzer_service.dart';
import '../services/encryption_service.dart';
import '../services/settings_store.dart';
import '../services/storage_service.dart';
import '../services/transfer_controller.dart';

/// Application state: drives, activity, transfers, vault operations and
/// cleanup scans. One instance lives above the navigator.
class AppState extends ChangeNotifier {
  AppState({
    required this.storage,
    required this.settings,
    required this.activityStore,
    required this.encryption,
  }) : analyzer = AnalyzerService(storage) {
    transfers = TransferController(
      storage: storage,
      onFinished: _handleTransferFinished,
    );
  }

  final StorageService storage;
  final SettingsController settings;
  final ActivityStore activityStore;
  final EncryptionService encryption;
  final AnalyzerService analyzer;

  late final TransferController transfers;

  List<Volume> _volumes = <Volume>[];
  String? _activeVolumeId;
  bool _loading = true;
  String? _error;
  String? _notice;
  int _idSeed = 0;

  final Map<String, DriveHealth> _health = <String, DriveHealth>{};

  CleanUpReport? _cleanUpReport;
  String? _cleanUpVolumeId;
  bool _scanning = false;
  int _scanProgress = 0;
  StreamSubscription<Volume>? _volumeSub;

  // ---------------------------------------------------------------------------
  // Read-only surface
  // ---------------------------------------------------------------------------

  List<Volume> get volumes => List<Volume>.unmodifiable(_volumes);

  List<Volume> get connectedVolumes =>
      _volumes.where((Volume v) => v.isConnected).toList(growable: false);

  List<Volume> get rememberedVolumes => _volumes
      .where((Volume v) => !v.isConnected)
      .toList(growable: false)
    ..sort((Volume a, Volume b) =>
        (b.lastSeen ?? DateTime(0)).compareTo(a.lastSeen ?? DateTime(0)));

  Volume? get currentVolume {
    final String? id = _activeVolumeId;
    if (id != null) {
      for (final Volume volume in _volumes) {
        if (volume.id == id && volume.isConnected) return volume;
      }
    }
    return _defaultVolume();
  }

  String? get activeVolumeId => currentVolume?.id;

  bool get loading => _loading;

  String? get error => _error;

  bool get isDemo => storage.isDemo;

  String get platformName => storage.platformName;

  List<ActivityEvent> get activity => activityStore.events;

  Map<String, DriveHealth> get health => Map<String, DriveHealth>.unmodifiable(_health);

  DriveHealth healthOf(Volume volume) =>
      _health[volume.id] ?? DriveHealth.unknown();

  CleanUpReport? get cleanUpReport => _cleanUpReport;

  String? get cleanUpVolumeId => _cleanUpVolumeId;

  bool get scanning => _scanning;

  int get scanProgress => _scanProgress;

  Set<String> get favorites => settings.favorites.toSet();

  bool isFavorite(String path) => settings.favorites.contains(path);

  /// One-shot notifications for snackbars. Widgets listen to [noticeFeed]
  /// instead of polling the state object.
  final ValueNotifier<String?> noticeFeed = ValueNotifier<String?>(null);

  String? takeNotice() {
    final String? value = _notice;
    _notice = null;
    noticeFeed.value = null;
    return value;
  }

  void _emitNotice(String message) {
    if (!settings.alertsEnabled) return;
    _notice = message;
    noticeFeed.value = message;
  }

  String rootFor(Volume volume) =>
      volume.mountPath.trim().isEmpty ? '/' : volume.mountPath;

  String get currentRoot {
    final Volume? volume = currentVolume;
    return volume == null ? '/' : rootFor(volume);
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  Future<void> init() async {
    await activityStore.load();
    if (storage.isDemo) {
      await activityStore.seedIfEmpty(_demoHistory());
    }
    await refreshVolumes(initial: true, silent: true);
    try {
      _volumeSub = storage.watchVolumes().listen(
        _mergePushedVolume,
        onError: (Object error) {
          debugPrint('Volume event stream unavailable: $error');
        },
      );
    } catch (error) {
      debugPrint('Could not subscribe to volume events: $error');
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> refreshVolumes({
    bool initial = false,
    bool silent = false,
  }) async {
    if (!silent) {
      _loading = true;
      notifyListeners();
    }
    try {
      final Set<String> previouslyConnected = _volumes
          .where((Volume v) => v.isConnected && v.isRemovable)
          .map((Volume v) => v.id)
          .toSet();
      final List<Volume> next = await storage.listVolumes();
      _volumes = next;
      _error = null;

      if (_activeVolumeId != null &&
          !next.any((Volume v) => v.id == _activeVolumeId && v.isConnected)) {
        _activeVolumeId = null;
      }
      _activeVolumeId ??= _defaultVolume()?.id;

      if (!initial) {
        for (final Volume volume in next) {
          if (volume.isConnected &&
              volume.isRemovable &&
              !previouslyConnected.contains(volume.id)) {
            await _log(
              ActivityEvent(
                id: _nextId('connect'),
                type: ActivityType.connect,
                title: '${volume.label} connected',
                subtitle: '${volume.protocolOrBus} • ${volume.fileSystemLabel}',
                volumeLabel: volume.label,
                timestamp: DateTime.now(),
                statusLabel: 'Mounted',
              ),
            );
          }
        }
      }
    } on StorageException catch (error) {
      _error = error.message;
    } catch (error) {
      _error = 'Could not read storage volumes: $error';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void selectVolume(String volumeId) {
    _activeVolumeId = volumeId;
    notifyListeners();
  }

  void _mergePushedVolume(Volume volume) {
    final int index = _volumes.indexWhere((Volume v) => v.id == volume.id);
    final bool wasConnected = index >= 0 && _volumes[index].isConnected;
    if (index >= 0) {
      _volumes[index] = volume;
    } else {
      _volumes = <Volume>[..._volumes, volume];
    }
    if (volume.isConnected && !wasConnected && volume.isRemovable) {
      _log(
        ActivityEvent(
          id: _nextId('connect'),
          type: ActivityType.connect,
          title: '${volume.label} connected',
          volumeLabel: volume.label,
          timestamp: DateTime.now(),
          statusLabel: 'Mounted',
        ),
      );
    }
    if (!volume.isConnected && wasConnected) {
      _activeVolumeId = _defaultVolume()?.id;
    }
    notifyListeners();
  }

  Volume? _defaultVolume([List<Volume>? source]) {
    final List<Volume> pool = source ?? _volumes;
    final Iterable<Volume> connected = pool.where((Volume v) => v.isConnected);
    return connected.where((Volume v) => v.isRemovable).firstOrNull ??
        connected.firstOrNull ??
        pool.firstOrNull;
  }

  // ---------------------------------------------------------------------------
  // Filesystem operations
  // ---------------------------------------------------------------------------

  Future<List<FileEntry>> listDirectory(String path) => storage.listDirectory(path);

  Future<FolderSummary> summarize(FileEntry folder) => storage.summarize(folder.path);

  Future<List<FileEntry>> search(String query, {Volume? volume}) {
    final Volume? target = volume ?? currentVolume;
    if (target == null) return Future<List<FileEntry>>.value(<FileEntry>[]);
    return storage.search(rootFor(target), query);
  }

  /// Shallow "recent files" feed: newest files from the top-level folders of a
  /// volume. Deliberately not a full index — that would cost minutes on a full
  /// 2 TB drive and the app must stay instant.
  Future<List<FileEntry>> recentFiles({Volume? volume, int limit = 14}) async {
    final Volume? target = volume ?? currentVolume;
    if (target == null) return const <FileEntry>[];
    final List<FileEntry> files = <FileEntry>[];
    try {
      final List<FileEntry> roots = await storage.listDirectory(rootFor(target));
      final List<FileEntry> folders =
          roots.where((FileEntry e) => e.isDirectory).take(6).toList(growable: false);
      for (final FileEntry folder in folders) {
        try {
          final List<FileEntry> children = await storage.listDirectory(folder.path);
          files.addAll(children.where((FileEntry e) => !e.isDirectory));
        } on StorageException {
          continue;
        }
      }
      files.sort((FileEntry a, FileEntry b) => b.modifiedAt.compareTo(a.modifiedAt));
    } on StorageException {
      return const <FileEntry>[];
    }
    return files.take(limit).toList(growable: false);
  }

  Future<void> createFolder({
    required String parentPath,
    required String name,
    required Volume volume,
  }) async {
    await storage.createFolder(parentPath, name);
    await _log(
      ActivityEvent(
        id: _nextId('mkdir'),
        type: ActivityType.createFolder,
        title: 'Folder "$name" created',
        volumeLabel: volume.label,
        timestamp: DateTime.now(),
        statusLabel: 'Created',
      ),
    );
    notifyListeners();
  }

  Future<void> renameEntry({
    required FileEntry entry,
    required String newName,
    required Volume volume,
  }) async {
    await storage.rename(entry.path, newName);
    await _log(
      ActivityEvent(
        id: _nextId('rename'),
        type: ActivityType.rename,
        title: '"${entry.name}" renamed',
        subtitle: 'Now "$newName"',
        volumeLabel: volume.label,
        timestamp: DateTime.now(),
        statusLabel: 'Renamed',
      ),
    );
    notifyListeners();
  }

  Future<int> deleteEntries({
    required List<FileEntry> entries,
    required Volume volume,
    ActivityType type = ActivityType.delete,
  }) async {
    final int bytes = entries.fold<int>(
      0,
      (int sum, FileEntry e) => sum + (e.isDirectory ? 0 : e.sizeBytes),
    );
    await storage.deleteEntries(entries);
    await _log(
      ActivityEvent(
        id: _nextId('delete'),
        type: type,
        title: entries.length == 1
            ? '"${entries.first.name}" deleted'
            : '${entries.length} items deleted',
        volumeLabel: volume.label,
        bytes: bytes,
        timestamp: DateTime.now(),
        statusLabel: 'Deleted',
      ),
    );
    notifyListeners();
    return bytes;
  }

  Future<void> eject(Volume volume) async {
    await storage.eject(volume);
    await _log(
      ActivityEvent(
        id: _nextId('eject'),
        type: ActivityType.eject,
        title: '${volume.label} safely removed',
        subtitle: volume.protocolOrBus,
        volumeLabel: volume.label,
        timestamp: DateTime.now(),
        statusLabel: 'Unmounted',
      ),
    );
    _activeVolumeId = null;
    await refreshVolumes(silent: true);
    notifyListeners();
  }

  Future<DriveHealth> benchmark(Volume volume) async {
    final DriveHealth result = await storage.benchmark(volume);
    _health[volume.id] = result;
    _volumes = _volumes
        .map((Volume v) => v.id == volume.id
            ? v.copyWith(
                readMbps: result.readMbps,
                writeMbps: result.writeMbps,
                healthPercent: result.healthPercent,
              )
            : v)
        .toList(growable: false);
    await _log(
      ActivityEvent(
        id: _nextId('bench'),
        type: ActivityType.benchmark,
        title: '${volume.label} benchmarked',
        subtitle: '${result.readLabel} read • ${result.writeLabel} write',
        volumeLabel: volume.label,
        timestamp: DateTime.now(),
        statusLabel: result.status.label,
      ),
    );
    notifyListeners();
    return result;
  }

  Future<Map<String, String>> deviceInfo() => storage.deviceInfo();

  // ---------------------------------------------------------------------------
  // Transfers
  // ---------------------------------------------------------------------------

  Future<TransferTask> transferFiles({
    required List<FileEntry> sources,
    required Volume destination,
    required String destinationPath,
    String sourceLabel = '',
    TransferDirection direction = TransferDirection.copy,
    String? label,
  }) async {
    // Folder sizes are not free: measure them once so the queue can show real
    // byte progress instead of 0 of 0.
    final List<FileEntry> enriched = <FileEntry>[];
    for (final FileEntry entry in sources) {
      if (entry.isDirectory && (entry.folderBytes == null || entry.folderBytes == 0)) {
        try {
          final FolderSummary summary = await storage.summarize(entry.path);
          enriched.add(
            entry.copyWith(folderBytes: summary.bytes, childCount: summary.items),
          );
        } on StorageException {
          enriched.add(entry);
        }
      } else {
        enriched.add(entry);
      }
    }

    return transfers.start(
      sources: enriched,
      destinationPath: destinationPath,
      destinationLabel: destination.label,
      sourceLabel: sourceLabel,
      direction: direction,
      label: label,
    );
  }

  Future<void> _handleTransferFinished(TransferTask task) async {
    final bool completed = task.status == TransferStatus.completed;
    final bool cancelled = task.status == TransferStatus.cancelled;
    final String verb = switch (task.direction) {
      TransferDirection.copy => 'copied',
      TransferDirection.move => 'moved',
      TransferDirection.backup => 'backed up',
    };
    final String title = completed
        ? (task.itemCount == 1 ? '"${task.label}" $verb' : '${task.itemCount} items $verb')
        : '${task.label} ${cancelled ? 'cancelled' : 'failed'}';

    await _log(
      ActivityEvent(
        id: _nextId('transfer'),
        type: task.direction == TransferDirection.backup
            ? ActivityType.backup
            : ActivityType.transfer,
        title: title,
        subtitle: task.routeLabel,
        volumeLabel: task.targetLabel,
        bytes: completed ? task.totalBytes : 0,
        timestamp: DateTime.now(),
        statusLabel: completed ? 'Completed' : (cancelled ? 'Cancelled' : 'Failed'),
        isFailure: !completed && !cancelled,
      ),
    );
    if (completed) {
      _emitNotice(
        '${task.routeLabel}: ${ByteFormat.format(task.totalBytes)} $verb',
      );
    } else if (!cancelled) {
      _emitNotice(task.error ?? 'Transfer failed');
    }
    await refreshVolumes(silent: true);
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Cleanup
  // ---------------------------------------------------------------------------

  Future<CleanUpReport?> scanCleanUp(Volume volume) async {
    _scanning = true;
    _scanProgress = 0;
    notifyListeners();
    try {
      final CleanUpReport report = await analyzer.analyze(
        volume,
        largeFileThresholdBytes: settings.largeFileThresholdMb * 1000000,
        onProgress: (int scanned) {
          _scanProgress = scanned;
          notifyListeners();
        },
      );
      _cleanUpReport = report;
      _cleanUpVolumeId = volume.id;
      return report;
    } finally {
      _scanning = false;
      notifyListeners();
    }
  }

  Future<void> deleteFromCleanup({
    required List<FileEntry> entries,
    required Volume volume,
  }) async {
    if (entries.isEmpty) return;
    final int freed = await deleteEntries(
      entries: entries,
      volume: volume,
      type: ActivityType.cleanup,
    );
    _emitNotice('${ByteFormat.format(freed)} freed');
    await refreshVolumes(silent: true);
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Encryption vault
  // ---------------------------------------------------------------------------

  Future<int> encryptFiles({
    required List<FileEntry> entries,
    required String password,
    required Volume volume,
  }) async {
    if (volume.fileSystem.toUpperCase() == 'SAF') {
      throw const StorageException(
        'Encryption needs direct file access. Use internal storage or a mounted '
        'volume, or grant the drive as a mounted volume.',
      );
    }
    final List<FileEntry> files =
        entries.where((FileEntry e) => !e.isDirectory).toList(growable: false);
    if (files.isEmpty) {
      throw const StorageException('Select at least one file to encrypt.');
    }
    int bytes = 0;
    int done = 0;
    final List<String> failures = <String>[];
    for (final FileEntry file in files) {
      try {
        final Uint8List clear = await storage.readFile(file.path);
        final Uint8List sealed = await encryption.encrypt(clear, password);
        await storage.writeFile(
          '${file.path}.dpv'.replaceAll('//', '/'),
          sealed,
        );
        await storage.deleteEntries(<FileEntry>[file]);
        bytes += clear.length;
        done++;
      } on StorageException catch (error) {
        failures.add('${file.name}: ${error.message}');
      }
    }
    if (done > 0) {
      await _log(
        ActivityEvent(
          id: _nextId('encrypt'),
          type: ActivityType.encrypt,
          title: done == 1 ? '"${files.first.name}" encrypted' : '$done files encrypted',
          subtitle: 'AES-256-GCM • passphrase not stored',
          volumeLabel: volume.label,
          bytes: bytes,
          timestamp: DateTime.now(),
          statusLabel: 'Encrypted',
        ),
      );
      notifyListeners();
    }
    if (failures.isNotEmpty) {
      throw StorageException(
        '${failures.length} file(s) could not be encrypted. ${failures.first}',
        code: 'partial',
      );
    }
    return done;
  }

  Future<FileEntry> decryptEntry({
    required FileEntry entry,
    required String password,
    required Volume volume,
  }) async {
    final String? original = EncryptionService.originalName(entry.name);
    if (original == null) {
      throw const StorageException('This file is not a DrivePulse vault file.');
    }
    final String targetPath = '${entry.parentPath}/$original'.replaceAll('//', '/');
    if (await storage.exists(targetPath)) {
      throw StorageException('"$original" already exists in this folder.');
    }
    final Uint8List sealed = await storage.readFile(entry.path);
    final Uint8List clear = await encryption.decrypt(sealed, password);
    await storage.writeFile(targetPath, clear);
    await storage.deleteEntries(<FileEntry>[entry]);
    await _log(
      ActivityEvent(
        id: _nextId('decrypt'),
        type: ActivityType.decrypt,
        title: '"$original" decrypted',
        volumeLabel: volume.label,
        bytes: clear.length,
        timestamp: DateTime.now(),
        statusLabel: 'Decrypted',
      ),
    );
    notifyListeners();
    return FileEntry(
      path: targetPath,
      name: original,
      isDirectory: false,
      sizeBytes: clear.length,
      modifiedAt: DateTime.now(),
    );
  }

  void setHealth(Volume volume, DriveHealth health) {
    _health[volume.id] = health;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Activity
  // ---------------------------------------------------------------------------

  Future<void> _log(ActivityEvent event) async {
    await activityStore.add(event);
    notifyListeners();
  }

  Future<void> log(ActivityEvent event) => _log(event);

  Future<void> clearHistory() async {
    await activityStore.clear();
    notifyListeners();
  }

  Future<void> toggleFavorite(String path) async {
    await settings.toggleFavorite(path);
    notifyListeners();
  }

  String _nextId(String prefix) =>
      '$prefix-${DateTime.now().millisecondsSinceEpoch}-${++_idSeed}';

  // ---------------------------------------------------------------------------
  // Demo history
  // ---------------------------------------------------------------------------

  List<ActivityEvent> _demoHistory() {
    final DateTime now = DateTime.now();
    DateTime ago(int minutes) => now.subtract(Duration(minutes: minutes));
    return <ActivityEvent>[
      ActivityEvent(
        id: 'seed-1',
        type: ActivityType.transfer,
        title: '42 Photos copied',
        subtitle: 'Camera Roll → SanDisk Ultra Luxe',
        volumeLabel: 'SanDisk Ultra Luxe',
        bytes: 1400000000,
        timestamp: ago(2),
        statusLabel: 'Completed',
      ),
      ActivityEvent(
        id: 'seed-2',
        type: ActivityType.eject,
        title: 'Samsung Bar Plus safely removed',
        subtitle: 'USB 3.2 Gen 1 • unmounted',
        volumeLabel: 'Samsung Bar Plus',
        timestamp: ago(18),
        statusLabel: 'Safe Eject',
      ),
      ActivityEvent(
        id: 'seed-3',
        type: ActivityType.backup,
        title: 'Work Documents backup',
        subtitle: 'Documents → Kingston DataTraveler',
        volumeLabel: 'Kingston DataTraveler',
        bytes: 850000000,
        timestamp: ago(132),
        statusLabel: 'Auto-Synced',
      ),
      ActivityEvent(
        id: 'seed-4',
        type: ActivityType.cleanup,
        title: 'Cache & temp files cleaned',
        subtitle: 'All volumes',
        volumeLabel: 'All volumes',
        bytes: 420000000,
        timestamp: ago(240),
        statusLabel: 'Optimized',
      ),
      ActivityEvent(
        id: 'seed-5',
        type: ActivityType.format,
        title: 'Quick format: FAT32',
        subtitle: 'Kingston DataTraveler • 32 GB',
        volumeLabel: 'Kingston DataTraveler',
        timestamp: ago(60 * 26),
        statusLabel: 'Formatted',
      ),
      ActivityEvent(
        id: 'seed-6',
        type: ActivityType.transfer,
        title: 'Project_Assets.zip moved',
        subtitle: 'Internal storage → SanDisk Ultra Luxe',
        volumeLabel: 'SanDisk Ultra Luxe',
        bytes: 4100000000,
        timestamp: ago(60 * 31),
        statusLabel: 'Completed',
      ),
      ActivityEvent(
        id: 'seed-7',
        type: ActivityType.eject,
        title: 'Corsair Flash Voyager disconnected',
        subtitle: 'USB 3.0',
        volumeLabel: 'Corsair Flash Voyager',
        timestamp: ago(60 * 55),
        statusLabel: 'Unmounted',
      ),
    ];
  }

  @override
  void dispose() {
    _volumeSub?.cancel();
    transfers.dispose();
    storage.dispose();
    super.dispose();
  }
}
