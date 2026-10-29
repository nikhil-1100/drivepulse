import 'dart:typed_data';

import '../models/drive_health.dart';
import '../models/file_entry.dart';
import '../models/volume.dart';

/// Raised for any user-facing storage failure. The message is already written
/// for humans; screens can show it directly.
class StorageException implements Exception {
  const StorageException(this.message, {this.code = 'unknown'});

  final String message;
  final String code;

  @override
  String toString() => message;
}

/// A single progress tick from a copy/move job.
class TransferProgress {
  const TransferProgress({
    required this.doneBytes,
    required this.totalBytes,
    this.currentFile,
    this.bytesPerSecond = 0,
  });

  final int doneBytes;
  final int totalBytes;
  final String? currentFile;
  final double bytesPerSecond;

  double get fraction =>
      totalBytes <= 0 ? 0 : (doneBytes / totalBytes).clamp(0, 1);
}

class TransferOutcome {
  const TransferOutcome({required this.bytes, required this.items});

  final int bytes;
  final int items;
}

/// Cooperative cancellation shared between the UI and the copy loop.
class CancelToken {
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void cancel() => _cancelled = true;
}

/// Everything the app can do with storage. Two implementations exist:
///
/// * [NativeStorageService] — bridges to Kotlin/Swift over a MethodChannel.
/// * [DemoStorageService] — deterministic in-memory tree used for the web
///   preview, widget tests and design QA. It never touches the network.
abstract class StorageService {
  bool get isDemo;

  String get platformName;

  /// Connected volumes, internal storage first.
  Future<List<Volume>> listVolumes();

  /// Re-reads capacity for a single volume.
  Future<Volume?> refreshVolume(String volumeId);

  Future<List<FileEntry>> listDirectory(String path);

  Future<FileEntry?> stat(String path);

  /// Recursively totals a folder. Implementations cap the walk so a 2 TB drive
  /// cannot freeze the UI.
  Future<FolderSummary> summarize(
    String path, {
    int maxDepth = 8,
    int maxEntries = 40000,
  });

  Future<List<FileEntry>> search(
    String rootPath,
    String query, {
    int limit = 300,
  });

  Future<void> createFolder(String parentPath, String name);

  Future<void> rename(String path, String newName);

  Future<void> deleteEntries(List<FileEntry> entries);

  Future<TransferOutcome> transfer({
    required String taskId,
    required List<FileEntry> sources,
    required String destinationPath,
    required bool move,
    required CancelToken token,
    required void Function(TransferProgress progress) onProgress,
  });

  Future<void> pauseTransfer(String taskId, bool paused);

  Future<void> cancelTransfer(String taskId);

  Future<DriveHealth> benchmark(
    Volume volume, {
    void Function(double progress)? onProgress,
  });

  Future<void> eject(Volume volume);

  Future<Uint8List> readFile(String path);

  Future<void> writeFile(String path, Uint8List bytes);

  /// Lower-case hex SHA-256 of the file contents.
  Future<String> hashFile(String path);

  Future<bool> exists(String path);

  /// Opens the system folder picker and returns the chosen directory, or null.
  Future<FileEntry?> pickDirectory();

  /// Opens the system document picker. Returns picked entries (copy targets),
  /// or an empty list when the user cancels.
  Future<List<FileEntry>> pickFiles({bool multiple = true});

  /// Volume hot-plug notifications. Native uses an EventChannel; the demo
  /// service emits nothing.
  Stream<Volume> watchVolumes() => const Stream<Volume>.empty();

  /// Free-form platform facts shown in Settings → About.
  Future<Map<String, String>> deviceInfo() async => <String, String>{};

  Future<void> dispose() async {}
}
