import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import '../models/drive_health.dart';
import '../models/file_entry.dart';
import '../models/volume.dart';
import 'storage_service.dart';

/// In-memory storage backend with a realistic demo drive attached.
///
/// It exists for three reasons: the web build can be reviewed without a phone,
/// widget tests are hermetic, and design QA can see loaded states. All data is
/// local and volatile — nothing is sent anywhere, and nothing touches the real
/// filesystem.
class DemoStorageService extends StorageService {
  DemoStorageService({this._simulateLatency = false}) {
    _seed();
  }

  final bool _simulateLatency;

  final Map<String, List<FileEntry>> _tree = <String, List<FileEntry>>{};
  final Map<String, Volume> _volumes = <String, Volume>{};
  final Map<String, String> _hashes = <String, String>{};
  final Map<String, Uint8List> _contents = <String, Uint8List>{};
  final Set<String> _paused = <String>{};

  @override
  bool get isDemo => true;

  @override
  String get platformName => 'Demo drive';

  static final DateTime _now = DateTime.now();

  @override
  Future<List<Volume>> listVolumes() async {
    await _tick();
    final List<Volume> all = _volumes.values.toList(growable: false);
    all.sort((Volume a, Volume b) {
      if (a.isInternal != b.isInternal) return a.isInternal ? -1 : 1;
      if (a.isConnected != b.isConnected) return a.isConnected ? -1 : 1;
      return a.label.compareTo(b.label);
    });
    return all;
  }

  @override
  Future<Volume?> refreshVolume(String volumeId) async {
    await _tick();
    return _volumes[volumeId];
  }

  @override
  Future<List<FileEntry>> listDirectory(String path) async {
    await _tick();
    final List<FileEntry>? entries = _tree[_normalise(path)];
    if (entries == null) {
      throw StorageException('Folder not found: $path', code: 'not_found');
    }
    return List<FileEntry>.unmodifiable(entries);
  }

  @override
  Future<FileEntry?> stat(String path) async {
    await _tick();
    final String clean = _normalise(path);
    if (_tree.containsKey(clean)) {
      return FileEntry(
        path: clean,
        name: _baseName(clean),
        isDirectory: true,
        sizeBytes: 0,
        modifiedAt: _now,
        childCount: _tree[clean]!.length,
      );
    }
    for (final List<FileEntry> entries in _tree.values) {
      for (final FileEntry entry in entries) {
        if (entry.path == clean) return entry;
      }
    }
    return null;
  }

  @override
  Future<FolderSummary> summarize(
    String path, {
    int maxDepth = 8,
    int maxEntries = 40000,
  }) async {
    await _tick();
    int bytes = 0;
    int items = 0;
    int folders = 0;
    final List<(String, int)> queue = <(String, int)>[(_normalise(path), 0)];
    int visited = 0;

    while (queue.isNotEmpty && visited < maxEntries) {
      final (String dir, int depth) = queue.removeLast();
      final List<FileEntry>? entries = _tree[dir];
      if (entries == null) continue;
      for (final FileEntry entry in entries) {
        visited++;
        if (entry.isDirectory) {
          folders++;
          if (depth < maxDepth) queue.add((entry.path, depth + 1));
        } else {
          items++;
          bytes += entry.sizeBytes;
        }
      }
    }
    return FolderSummary(bytes: bytes, items: items, folders: folders);
  }

  @override
  Future<List<FileEntry>> search(
    String rootPath,
    String query, {
    int limit = 300,
  }) async {
    await _tick();
    final String needle = query.trim().toLowerCase();
    if (needle.isEmpty) return const <FileEntry>[];
    final List<FileEntry> results = <FileEntry>[];
    final List<String> queue = <String>[_normalise(rootPath)];
    final Set<String> seen = <String>{};

    while (queue.isNotEmpty && results.length < limit) {
      final String dir = queue.removeLast();
      if (!seen.add(dir)) continue;
      final List<FileEntry>? entries = _tree[dir];
      if (entries == null) continue;
      for (final FileEntry entry in entries) {
        if (entry.name.toLowerCase().contains(needle)) results.add(entry);
        if (entry.isDirectory) queue.add(entry.path);
        if (results.length >= limit) break;
      }
    }
    return results;
  }

  @override
  Future<void> createFolder(String parentPath, String name) async {
    await _tick();
    final String parent = _normalise(parentPath);
    final String clean = name.trim();
    if (clean.isEmpty) {
      throw const StorageException('Folder name cannot be empty',
          code: 'invalid_name');
    }
    if (clean.contains('/')) {
      throw const StorageException('Folder names cannot contain "/"',
          code: 'invalid_name');
    }
    final List<FileEntry> children = _tree[parent] ??= <FileEntry>[];
    if (children.any((FileEntry e) => e.name.toLowerCase() == clean.toLowerCase())) {
      throw StorageException('"$clean" already exists here', code: 'exists');
    }
    final String path = '$parent/$clean';
    children.add(
      FileEntry(
        path: path,
        name: clean,
        isDirectory: true,
        sizeBytes: 0,
        modifiedAt: DateTime.now(),
        childCount: 0,
      ),
    );
    _tree[path] = <FileEntry>[];
    _recount(parent);
  }

  @override
  Future<void> rename(String path, String newName) async {
    await _tick();
    final String clean = newName.trim();
    if (clean.isEmpty) {
      throw const StorageException('Name cannot be empty', code: 'invalid_name');
    }
    final String parent = _normalise(_parentOf(path));
    final List<FileEntry> siblings = _tree[parent] ?? <FileEntry>[];
    final int index = siblings.indexWhere((FileEntry e) => e.path == path);
    if (index < 0) {
      throw const StorageException('File no longer exists', code: 'not_found');
    }
    final FileEntry entry = siblings[index];
    final String newPath = '$parent/$clean';
    siblings[index] = entry.copyWith(path: newPath, name: clean);

    if (entry.isDirectory) {
      final List<MapEntry<String, List<FileEntry>>> moves = _tree.entries
          .where((MapEntry<String, List<FileEntry>> e) =>
              e.key == path || e.key.startsWith('$path/'))
          .toList();
      for (final MapEntry<String, List<FileEntry>> move in moves) {
        final List<FileEntry> children = _tree.remove(move.key) ?? <FileEntry>[];
        final String newKey = move.key.replaceFirst(path, newPath);
        _tree[newKey] = children
            .map((FileEntry child) => child.copyWith(
                  path: child.path.replaceFirst(path, newPath),
                ))
            .toList();
      }
    }
  }

  @override
  Future<void> deleteEntries(List<FileEntry> entries) async {
    await _tick();
    for (final FileEntry entry in entries) {
      final String parent = _normalise(entry.parentPath);
      _tree[parent]?.removeWhere((FileEntry e) => e.path == entry.path);
      if (entry.isDirectory) {
        _tree.removeWhere((String key, List<FileEntry> _) =>
            key == entry.path || key.startsWith('${entry.path}/'));
      }
      _hashes.remove(entry.path);
    }
    for (final FileEntry entry in entries) {
      _recount(_normalise(entry.parentPath));
    }
  }

  @override
  Future<TransferOutcome> transfer({
    required String taskId,
    required List<FileEntry> sources,
    required String destinationPath,
    required bool move,
    required CancelToken token,
    required void Function(TransferProgress progress) onProgress,
  }) async {
    final String destination = _normalise(destinationPath);
    if (!_tree.containsKey(destination)) {
      throw StorageException('Destination not available: $destinationPath',
          code: 'not_found');
    }
    final int totalBytes = sources.fold<int>(
      0,
      (int sum, FileEntry e) => sum + (e.isDirectory ? 0 : e.sizeBytes),
    );
    int done = 0;
    int copied = 0;
    final Stopwatch watch = Stopwatch()..start();

    for (final FileEntry source in sources) {
      if (token.isCancelled) {
        throw const StorageException('Transfer cancelled', code: 'cancelled');
      }
      while (_paused.contains(taskId)) {
        if (token.isCancelled) {
          throw const StorageException('Transfer cancelled', code: 'cancelled');
        }
        await Future<void>.delayed(const Duration(milliseconds: 120));
      }

      if (source.isDirectory) {
        await _copyDirectory(source, destination);
        done += source.folderBytes ?? 0;
        copied++;
        onProgress(TransferProgress(
          doneBytes: done.clamp(0, totalBytes),
          totalBytes: totalBytes,
          currentFile: source.name,
        ));
        if (move) {
          final String parent = _normalise(source.parentPath);
          _tree[parent]?.removeWhere((FileEntry e) => e.path == source.path);
          _tree.removeWhere((String key, List<FileEntry> _) =>
              key == source.path || key.startsWith('${source.path}/'));
        }
        continue;
      }

      final FileEntry copy = source.copyWith(
        path: '$destination/${source.name}',
        modifiedAt: DateTime.now(),
      );
      _tree[destination]?.removeWhere((FileEntry e) => e.name == copy.name);
      _tree[destination]?.add(copy);
      _hashes[copy.path] = await hashFile(source.path);
      done += source.sizeBytes;
      copied++;

      if (_simulateLatency) {
        // Break large files into ticks so the transfer banner animates.
        const int chunks = 8;
        for (int i = 1; i <= chunks; i++) {
          if (token.isCancelled) {
            throw const StorageException('Transfer cancelled', code: 'cancelled');
          }
          await Future<void>.delayed(const Duration(milliseconds: 60));
          final int chunkDone = done - source.sizeBytes +
              (source.sizeBytes * i / chunks).round();
          final double speed = watch.elapsedMilliseconds == 0
              ? 0
              : chunkDone / (watch.elapsedMilliseconds / 1000);
          onProgress(TransferProgress(
            doneBytes: chunkDone,
            totalBytes: totalBytes,
            currentFile: source.name,
            bytesPerSecond: speed,
          ));
        }
      } else {
        onProgress(TransferProgress(
          doneBytes: done,
          totalBytes: totalBytes,
          currentFile: source.name,
        ));
      }

      if (move) {
        final String parent = _normalise(source.parentPath);
        _tree[parent]?.removeWhere((FileEntry e) => e.path == source.path);
        _hashes.remove(source.path);
      }
    }

    _recount(destination);
    return TransferOutcome(bytes: totalBytes, items: copied);
  }

  Future<void> _copyDirectory(FileEntry source, String destination) async {
    final String targetRoot = '$destination/${source.name}';
    _tree[targetRoot] ??= <FileEntry>[];
    final List<FileEntry> children = _tree[source.path] ?? <FileEntry>[];
    for (final FileEntry child in children) {
      if (child.isDirectory) {
        await _copyDirectory(child, targetRoot);
      } else {
        _tree[targetRoot]!.add(child.copyWith(path: '$targetRoot/${child.name}'));
      }
    }
  }

  @override
  Future<void> pauseTransfer(String taskId, bool paused) async {
    if (paused) {
      _paused.add(taskId);
    } else {
      _paused.remove(taskId);
    }
  }

  @override
  Future<void> cancelTransfer(String taskId) async => _paused.remove(taskId);

  @override
  Future<DriveHealth> benchmark(
    Volume volume, {
    void Function(double progress)? onProgress,
  }) async {
    for (int i = 1; i <= 5; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 90));
      onProgress?.call(i / 5);
    }
    final double read = volume.isInternal ? 780 : 146;
    final double write = volume.isInternal ? 420 : 62;
    final int health = volume.healthPercent <= 0 ? 96 : volume.healthPercent;
    return DriveHealth(
      readMbps: read,
      writeMbps: write,
      latencyMs: volume.isInternal ? 0.3 : 1.8,
      healthPercent: health,
      status: DriveHealth.statusFor(health),
      checkedAt: DateTime.now(),
      smartSupported: false,
      notes: <String>[
        'Measured with a 16 MB local read/write burst.',
        'S.M.A.R.T. is not exposed for removable storage on mobile.',
      ],
    );
  }

  @override
  Future<void> eject(Volume volume) async {
    await _tick();
    if (volume.isInternal) {
      throw const StorageException('Internal storage cannot be ejected',
          code: 'unsupported');
    }
    if (!volume.isConnected) {
      throw const StorageException('This drive is already disconnected',
          code: 'not_connected');
    }
    final Volume current = _volumes[volume.id] ?? volume;
    if (!current.isConnected) {
      throw const StorageException('This drive is already disconnected',
          code: 'not_connected');
    }
    _volumes[volume.id] = volume.copyWith(
      isConnected: false,
      lastSeen: DateTime.now(),
    );
  }

  @override
  Future<Uint8List> readFile(String path) async {
    await _tick();
    return _contents[path] ?? Uint8List.fromList(utf8.encode('DrivePulse demo file'));
  }

  @override
  Future<void> writeFile(String path, Uint8List bytes) async {
    await _tick();
    _contents[path] = bytes;
  }

  @override
  Future<String> hashFile(String path) async {
    final String? seeded = _hashes[path];
    if (seeded != null) return seeded;
    final int dot = path.lastIndexOf('.');
    final String base = (dot > 0 ? path.substring(0, dot) : path)
        .replaceAll(' (copy)', '')
        .replaceAll('_copy', '')
        .toLowerCase();
    return base.hashCode.toRadixString(16).padLeft(16, '0');
  }

  @override
  Future<bool> exists(String path) async =>
      _tree.containsKey(_normalise(path)) ||
      _tree.values.any((List<FileEntry> e) => e.any((FileEntry f) => f.path == path));

  @override
  Future<FileEntry?> pickDirectory() async {
    await _tick();
    return FileEntry(
      path: '/SanDisk',
      name: 'SanDisk Ultra Luxe',
      isDirectory: true,
      sizeBytes: 0,
      modifiedAt: DateTime.now(),
    );
  }

  @override
  Future<List<FileEntry>> pickFiles({bool multiple = true}) async {
    await _tick();
    final List<FileEntry> entries = _tree['/Internal/DCIM/Camera'] ?? <FileEntry>[];
    return entries.take(multiple ? 3 : 1).toList(growable: false);
  }

  @override
  Future<Map<String, String>> deviceInfo() async => <String, String>{
        'platform': 'Preview (web)',
        'model': 'DrivePulse demo device',
        'os': 'Demo backend • no filesystem access',
      };

  Future<void> _tick() async {
    if (_simulateLatency) {
      await Future<void>.delayed(const Duration(milliseconds: 90));
    }
  }

  void _recount(String dir) {
    final List<FileEntry>? children = _tree[dir];
    if (children == null) return;
    for (int i = 0; i < children.length; i++) {
      final FileEntry child = children[i];
      if (!child.isDirectory) continue;
      final List<FileEntry>? inner = _tree[child.path];
      if (inner == null) continue;
      final int bytes = inner.fold<int>(
        0,
        (int sum, FileEntry e) => sum + (e.isDirectory ? (e.folderBytes ?? 0) : e.sizeBytes),
      );
      children[i] = child.copyWith(childCount: inner.length, folderBytes: bytes);
    }
  }

  String _normalise(String path) {
    if (path.isEmpty) return '/';
    String p = path.replaceAll('\\', '/');
    while (p.length > 1 && p.endsWith('/')) {
      p = p.substring(0, p.length - 1);
    }
    return p;
  }

  String _parentOf(String path) {
    final String clean = _normalise(path);
    final int slash = clean.lastIndexOf('/');
    if (slash <= 0) return '/';
    return clean.substring(0, slash);
  }

  String _baseName(String path) {
    final String clean = _normalise(path);
    final int slash = clean.lastIndexOf('/');
    return slash <= 0 ? clean : clean.substring(slash + 1);
  }

  // ---------------------------------------------------------------------------
  // Seed data
  // ---------------------------------------------------------------------------

  DateTime _daysAgo(int days, {int hour = 14, int minute = 15}) {
    final DateTime base = _now.subtract(Duration(days: days));
    return DateTime(base.year, base.month, base.day, hour, minute);
  }

  FileEntry _file(String path, int sizeBytes, DateTime modified) {
    final String name = _baseName(path);
    _hashFor(path, name);
    return FileEntry(
      path: path,
      name: name,
      isDirectory: false,
      sizeBytes: sizeBytes,
      modifiedAt: modified,
    );
  }

  void _hashFor(String path, String name) {
    final String key = name
        .toLowerCase()
        .replaceAll(' (copy)', '')
        .replaceAll('_copy', '');
    _hashes[path] = key.hashCode.toRadixString(16).padLeft(16, '0');
  }

  void _seed() {
    final Random random = Random(42);

    _volumes['internal'] = Volume(
      id: 'internal',
      label: 'Internal storage',
      fileSystem: 'f2fs',
      totalBytes: 256000000000,
      freeBytes: 114000000000,
      kind: VolumeKind.internal,
      busLabel: 'UFS 3.1',
      protocolLabel: 'UFS 3.1',
      mountPath: '/Internal',
      readMbps: 780,
      writeMbps: 420,
      healthPercent: 100,
      lastSeen: _now,
    );

    _volumes['sandisk-ultra'] = Volume(
      id: 'sandisk-ultra',
      label: 'SanDisk Ultra Luxe',
      fileSystem: 'exFAT',
      totalBytes: 128000000000,
      freeBytes: 44000000000,
      kind: VolumeKind.usbFlash,
      busLabel: 'USB-C',
      protocolLabel: 'USB 3.1 Type-C',
      serial: 'SD-UL942004819X',
      mountPath: '/SanDisk',
      readMbps: 150,
      writeMbps: 65,
      healthPercent: 100,
      lastSeen: _now,
    );

    _volumes['samsung-bar'] = Volume(
      id: 'samsung-bar',
      label: 'Samsung Bar Plus',
      fileSystem: 'exFAT',
      totalBytes: 256000000000,
      freeBytes: 82000000000,
      kind: VolumeKind.usbFlash,
      busLabel: 'USB-A',
      protocolLabel: 'USB 3.2 Gen 1',
      serial: 'SB+256-7712',
      mountPath: '',
      isConnected: false,
      readMbps: 300,
      writeMbps: 90,
      healthPercent: 94,
      lastSeen: _daysAgo(2, hour: 9, minute: 20),
    );

    _volumes['kingston-dt'] = Volume(
      id: 'kingston-dt',
      label: 'Kingston DataTraveler',
      fileSystem: 'FAT32',
      totalBytes: 64000000000,
      freeBytes: 51200000000,
      kind: VolumeKind.usbFlash,
      busLabel: 'USB-A',
      protocolLabel: 'USB 2.0',
      serial: 'DT64-2211',
      mountPath: '',
      isConnected: false,
      readMbps: 38,
      writeMbps: 12,
      healthPercent: 71,
      lastSeen: DateTime(2026, 10, 12, 11, 40),
    );

    _volumes['corsair-voyager'] = Volume(
      id: 'corsair-voyager',
      label: 'Corsair Flash Voyager',
      fileSystem: 'exFAT',
      totalBytes: 512000000000,
      freeBytes: 102000000000,
      kind: VolumeKind.usbFlash,
      busLabel: 'USB-A',
      protocolLabel: 'USB 3.0',
      serial: 'CMFVY-512',
      mountPath: '',
      isConnected: false,
      readMbps: 190,
      writeMbps: 48,
      healthPercent: 88,
      lastSeen: DateTime(2026, 9, 28, 16, 5),
    );

    // --- Internal storage ---------------------------------------------------
    _tree['/Internal'] = <FileEntry>[
      _folder('/Internal/DCIM', _daysAgo(0, hour: 12), 24),
      _folder('/Internal/Documents', _daysAgo(3), 9),
      _folder('/Internal/Download', _daysAgo(1), 7),
      _folder('/Internal/Movies', _daysAgo(5), 4),
      _folder('/Internal/Music', _daysAgo(9), 6),
      _folder('/Internal/cache', _daysAgo(0, hour: 9), 5),
      _folder('/Internal/.trash', _daysAgo(4), 3),
    ];

    _tree['/Internal/DCIM'] = <FileEntry>[_folder('/Internal/DCIM/Camera', _daysAgo(0, hour: 12), 42)];
    _tree['/Internal/DCIM/Camera'] = <FileEntry>[
      for (int i = 0; i < 14; i++)
        _file(
          '/Internal/DCIM/Camera/IMG_2026_${(1000 + i)}.jpg',
          3500000 + random.nextInt(4200000),
          _daysAgo(i % 7, hour: 8 + (i % 9)),
        ),
    ];

    _tree['/Internal/Documents'] = <FileEntry>[
      _file('/Internal/Documents/Lease_Agreement_2026.pdf', 2400000, _daysAgo(40)),
      _file('/Internal/Documents/Rent_Receipts_Q3.xlsx', 840000, _daysAgo(12)),
      _file('/Internal/Documents/Hostel_Checklist.docx', 156000, _daysAgo(21)),
      _file('/Internal/Documents/Passport_Scan.pdf', 5400000, _daysAgo(200)),
      _file('/Internal/Documents/Project_Proposal_v2.pdf', 18200000, _daysAgo(15)),
      _file('/Internal/Documents/Project_Proposal_v2 (copy).pdf', 18200000, _daysAgo(15)),
    ];

    _tree['/Internal/Download'] = <FileEntry>[
      _file('/Internal/Download/Flutter_SDK_Notes.md', 42000, _daysAgo(2)),
      _file('/Internal/Download/Backup_Archive.zip', 4200000000, _daysAgo(10)),
      _file('/Internal/Download/Firmware_Update.zip', 96000000, _daysAgo(35)),
      _file('/Internal/Download/invoice-download.pdf', 320000, _daysAgo(1)),
    ];

    _tree['/Internal/Movies'] = <FileEntry>[
      _file('/Internal/Movies/Final_Edit_4K.mp4', 1800000000, _daysAgo(1)),
      _file('/Internal/Movies/Product_Teaser.mov', 640000000, _daysAgo(26)),
    ];

    _tree['/Internal/Music'] = <FileEntry>[
      _file('/Internal/Music/Master_Audio_Track.wav', 312400000, _daysAgo(18)),
      _file('/Internal/Music/Podcast_Ep12.mp3', 48200000, _daysAgo(6)),
      _file('/Internal/Music/Playlist_Backup.m3u', 1200, _daysAgo(60)),
    ];

    _tree['/Internal/cache'] = <FileEntry>[
      _file('/Internal/cache/tmp_thumb_cache_01.dat', 62000000, _daysAgo(0, hour: 7)),
      _file('/Internal/cache/tmp_transfer_log.txt', 4200000, _daysAgo(1)),
      _file('/Internal/cache/com.drivepulse/cache.img', 38000000, _daysAgo(3)),
      _file('/Internal/cache/stale_export.tmp', 9800000, _daysAgo(90)),
    ];

    _tree['/Internal/.trash'] = <FileEntry>[
      _file('/Internal/.trash/old_screenshot.png', 1200000, _daysAgo(8)),
      _file('/Internal/.trash/duplicate_notes.txt', 18000, _daysAgo(22)),
    ];

    // --- SanDisk ------------------------------------------------------------
    _tree['/SanDisk'] = <FileEntry>[
      _folder('/SanDisk/Camera_RAW', _daysAgo(0, hour: 14), 24),
      _folder('/SanDisk/Client_Deliverables', _daysAgo(2), 12),
      _folder('/SanDisk/Documents & Archives', _daysAgo(9), 8),
      _file('/SanDisk/IMG_2024_Hero.raw', 42400000, _daysAgo(0, hour: 14, minute: 15)),
      _file('/SanDisk/Final_Edit_4K.mp4', 1800000000, _daysAgo(1, hour: 18, minute: 30)),
      _file('/SanDisk/Project_Proposal_v2.pdf', 18200000, _daysAgo(15)),
      _file('/SanDisk/Backup_Archive.zip', 4200000000, _daysAgo(19)),
      _file('/SanDisk/Brand_Assets_2024.ai', 64800000, _daysAgo(31)),
      _file('/SanDisk/Master_Audio_Track.wav', 312400000, _daysAgo(40)),
      _file('/SanDisk/Financial_Report.xlsx', 840000, _daysAgo(45)),
    ];
    _tree['/SanDisk/Camera_RAW'] = <FileEntry>[
      for (int i = 0; i < 10; i++)
        _file(
          '/SanDisk/Camera_RAW/RAW_${2024 + i}.cr2',
          190000000 + random.nextInt(80000000),
          _daysAgo(0, hour: 9 + (i % 6)),
        ),
      _file('/SanDisk/Camera_RAW/IMG_2024_Hero (copy).raw', 42400000, _daysAgo(0, hour: 14, minute: 40)),
    ];
    _tree['/SanDisk/Client_Deliverables'] = <FileEntry>[
      _file('/SanDisk/Client_Deliverables/Client_Pitch_Deck_v3.pdf', 18000000, _daysAgo(1, hour: 18, minute: 40)),
      _file('/SanDisk/Client_Deliverables/Logo_Pack.zip', 240000000, _daysAgo(2)),
      _file('/SanDisk/Client_Deliverables/Delivery_Notes.docx', 96000, _daysAgo(2)),
      _file('/SanDisk/Client_Deliverables/Handover_Video.mp4', 1200000000, _daysAgo(3)),
    ];
    _tree['/SanDisk/Documents & Archives'] = <FileEntry>[
      _file('/SanDisk/Documents & Archives/2025_Tax_Return.pdf', 4200000, _daysAgo(120)),
      _file('/SanDisk/Documents & Archives/ID_Scans.pdf', 8600000, _daysAgo(220)),
      _file('/SanDisk/Documents & Archives/Archive_2024.zip', 3800000000, _daysAgo(300)),
    ];
  }

  FileEntry _folder(String path, DateTime modified, int childCount) => FileEntry(
        path: path,
        name: _baseName(path),
        isDirectory: true,
        sizeBytes: 0,
        modifiedAt: modified,
        childCount: childCount,
      );
}
