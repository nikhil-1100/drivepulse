import '../models/clean_up_report.dart';
import '../models/file_entry.dart';
import '../models/storage_breakdown.dart';
import '../models/volume.dart';
import 'storage_service.dart';

/// Offline storage analyzer.
///
/// Walks the chosen volume once, streaming entries into buckets rather than
/// retaining the tree, so a 2 TB drive with 100k files stays within a few MB of
/// RAM. It is intentionally conservative: junk is limited to well-known cache /
/// temp / trash locations, and duplicates require an identical byte hash.
class AnalyzerService {
  AnalyzerService(this.storage);

  final StorageService storage;

  static const int _maxEntries = 24000;
  static const int _maxDepth = 14;
  static const int _maxHashedFiles = 400;
  static const Set<String> _junkSegments = <String>{
    'cache',
    'caches',
    'tmp',
    'temp',
    '.trash',
    'trash',
    'log',
    'logs',
  };
  static const Set<String> _junkExtensions = <String>{
    'tmp',
    'temp',
    'log',
    'bak',
    'dmp',
    'crdownload',
    'part',
  };

  Future<CleanUpReport> analyze(
    Volume volume, {
    required int largeFileThresholdBytes,
    void Function(int scanned)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final Stopwatch watch = Stopwatch()..start();
    final String root = volume.mountPath.isEmpty ? '/' : volume.mountPath;

    final List<FileEntry> files = <FileEntry>[];
    final List<FileEntry> emptyFolders = <FileEntry>[];
    final List<FileEntry> allEntries = <FileEntry>[];
    final List<(String, int)> stack = <(String, int)>[(root, 0)];
    final Set<String> visited = <String>{};
    final DateTime staleBefore = DateTime.now().subtract(const Duration(days: 180));
    int scanned = 0;
    bool truncated = false;

    while (stack.isNotEmpty) {
      if (isCancelled?.call() == true) {
        throw const StorageException('Scan cancelled', code: 'cancelled');
      }
      final (String dir, int depth) = stack.removeLast();
      if (!visited.add(dir)) continue;
      List<FileEntry> children;
      try {
        children = await storage.listDirectory(dir);
      } on StorageException {
        continue;
      }
      if (children.isEmpty && dir != root) {
        emptyFolders.add(
          FileEntry(
            path: dir,
            name: _nameOf(dir),
            isDirectory: true,
            sizeBytes: 0,
            modifiedAt: DateTime.now(),
          ),
        );
      }
      for (final FileEntry child in children) {
        scanned++;
        allEntries.add(child);
        if (scanned >= _maxEntries) {
          truncated = true;
          break;
        }
        if (child.isDirectory) {
          if (depth < _maxDepth) stack.add((child.path, depth + 1));
        } else {
          files.add(child);
        }
      }
      if (scanned % 400 == 0) onProgress?.call(scanned);
      if (truncated) break;
    }

    final int largeThreshold = largeFileThresholdBytes;
    final List<FileEntry> largeFiles = files
        .where((FileEntry f) => f.sizeBytes >= largeThreshold)
        .toList()
      ..sort((FileEntry a, FileEntry b) => b.sizeBytes.compareTo(a.sizeBytes));

    final List<FileEntry> junkFiles = files
        .where((FileEntry f) => _isJunk(f))
        .toList(growable: false);

    final List<FileEntry> staleFiles = files
        .where((FileEntry f) =>
            f.modifiedAt.isBefore(staleBefore) && !_isJunk(f))
        .toList()
      ..sort((FileEntry a, FileEntry b) => a.modifiedAt.compareTo(b.modifiedAt));

    final List<DuplicateGroup> duplicates =
        await _findDuplicates(files, isCancelled: isCancelled);

    final StorageBreakdown breakdown = StorageBreakdown.fromEntries(
      totalBytes: volume.totalBytes,
      freeBytes: volume.freeBytes,
      entries: files,
      filesScanned: files.length,
      foldersScanned: allEntries.length - files.length,
      truncated: truncated,
    );

    onProgress?.call(scanned);
    return CleanUpReport(
      largeFiles: largeFiles.take(40).toList(growable: false),
      duplicates: duplicates,
      emptyFolders: emptyFolders.take(60).toList(growable: false),
      junkFiles: junkFiles,
      staleFiles: staleFiles.take(60).toList(growable: false),
      breakdown: breakdown,
      scannedAt: DateTime.now().subtract(watch.elapsed),
      truncated: truncated,
    );
  }

  Future<List<DuplicateGroup>> _findDuplicates(
    List<FileEntry> files, {
    bool Function()? isCancelled,
  }) async {
    final Map<int, List<FileEntry>> bySize = <int, List<FileEntry>>{};
    for (final FileEntry file in files) {
      if (file.sizeBytes < 1024 * 1024) continue;
      if (file.sizeBytes > 512 * 1024 * 1024) continue;
      bySize.putIfAbsent(file.sizeBytes, () => <FileEntry>[]).add(file);
    }

    final List<DuplicateGroup> groups = <DuplicateGroup>[];
    int hashed = 0;
    for (final MapEntry<int, List<FileEntry>> bucket in bySize.entries) {
      if (bucket.value.length < 2) continue;
      final Map<String, List<FileEntry>> byHash = <String, List<FileEntry>>{};
      for (final FileEntry file in bucket.value) {
        if (hashed >= _maxHashedFiles) break;
        if (isCancelled?.call() == true) return groups;
        hashed++;
        try {
          final String hash = await storage.hashFile(file.path);
          if (hash.isEmpty) continue;
          byHash.putIfAbsent('${bucket.key}:$hash', () => <FileEntry>[]).add(file);
        } on StorageException {
          continue;
        }
      }
      for (final MapEntry<String, List<FileEntry>> group in byHash.entries) {
        if (group.value.length < 2) continue;
        groups.add(
          DuplicateGroup(
            signature: group.key,
            sizeBytes: bucket.key,
            files: group.value,
          ),
        );
      }
    }
    groups.sort((DuplicateGroup a, DuplicateGroup b) =>
        b.redundantBytes.compareTo(a.redundantBytes));
    return groups;
  }

  bool _isJunk(FileEntry file) {
    final String path = file.path.toLowerCase();
    final List<String> segments = path.split('/');
    if (segments.any(_junkSegments.contains)) return true;
    final int dot = file.name.lastIndexOf('.');
    if (dot > 0) {
      final String ext = file.name.substring(dot + 1).toLowerCase();
      if (_junkExtensions.contains(ext)) return true;
    }
    return false;
  }

  static String _nameOf(String path) {
    final int slash = path.lastIndexOf('/');
    return slash <= 0 ? path : path.substring(slash + 1);
  }
}
