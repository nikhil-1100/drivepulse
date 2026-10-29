import 'package:flutter/foundation.dart';

import 'file_entry.dart';
import 'storage_breakdown.dart';

@immutable
class DuplicateGroup {
  const DuplicateGroup({
    required this.signature,
    required this.sizeBytes,
    required this.files,
  });

  final String signature;
  final int sizeBytes;
  final List<FileEntry> files;

  /// Space recovered by keeping exactly one copy.
  int get redundantBytes => sizeBytes * (files.length - 1).clamp(0, files.length).toInt();

  int get count => files.length;
}

/// Result of the offline storage analyzer. Everything here is derived from the
/// chosen roots; nothing leaves the device.
@immutable
class CleanUpReport {
  const CleanUpReport({
    required this.largeFiles,
    required this.duplicates,
    required this.emptyFolders,
    required this.junkFiles,
    required this.staleFiles,
    required this.breakdown,
    required this.scannedAt,
    this.truncated = false,
  });

  /// Files above the size threshold, biggest first.
  final List<FileEntry> largeFiles;

  final List<DuplicateGroup> duplicates;
  final List<FileEntry> emptyFolders;

  /// Temp/cache/log/trash artifacts safe to remove.
  final List<FileEntry> junkFiles;

  /// Files untouched for a long time (older than 180 days).
  final List<FileEntry> staleFiles;

  final StorageBreakdown breakdown;
  final DateTime scannedAt;
  final bool truncated;

  int get junkBytes =>
      junkFiles.fold<int>(0, (int sum, FileEntry f) => sum + f.sizeBytes);

  int get duplicateBytes =>
      duplicates.fold<int>(0, (int sum, DuplicateGroup g) => sum + g.redundantBytes);

  int get staleBytes =>
      staleFiles.fold<int>(0, (int sum, FileEntry f) => sum + f.sizeBytes);

  /// Bytes that can be reclaimed right now without losing unique data.
  int get reclaimableBytes => junkBytes + duplicateBytes;

  bool get isEmpty =>
      largeFiles.isEmpty &&
      duplicates.isEmpty &&
      emptyFolders.isEmpty &&
      junkFiles.isEmpty;

  static CleanUpReport empty(StorageBreakdown breakdown) => CleanUpReport(
        largeFiles: const <FileEntry>[],
        duplicates: const <DuplicateGroup>[],
        emptyFolders: const <FileEntry>[],
        junkFiles: const <FileEntry>[],
        staleFiles: const <FileEntry>[],
        breakdown: breakdown,
        scannedAt: DateTime.now(),
      );
}
