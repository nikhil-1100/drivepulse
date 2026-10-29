import 'package:flutter/foundation.dart';

import '../../core/utils/file_kind.dart';
import 'file_entry.dart';

@immutable
class CategoryUsage {
  const CategoryUsage({
    required this.category,
    required this.bytes,
    required this.itemCount,
  });

  final StorageCategory category;
  final int bytes;
  final int itemCount;

  CategoryUsage add(int extraBytes) => CategoryUsage(
        category: category,
        bytes: bytes + extraBytes,
        itemCount: itemCount + 1,
      );
}

/// What occupies a volume, grouped into the buckets the analyzer understands.
@immutable
class StorageBreakdown {
  const StorageBreakdown({
    required this.totalBytes,
    required this.freeBytes,
    required this.categories,
    this.filesScanned = 0,
    this.foldersScanned = 0,
    this.truncated = false,
  });

  final int totalBytes;
  final int freeBytes;
  final List<CategoryUsage> categories;
  final int filesScanned;
  final int foldersScanned;

  /// True when the scan hit its safety limit before finishing the tree.
  final bool truncated;

  int get usedBytes => (totalBytes - freeBytes).clamp(0, totalBytes);

  double get usedFraction => totalBytes <= 0 ? 0 : usedBytes / totalBytes;

  double get freeFraction =>
      totalBytes <= 0 ? 0 : freeBytes.clamp(0, totalBytes) / totalBytes;

  int get categorisedBytes =>
      categories.fold<int>(0, (int sum, CategoryUsage c) => sum + c.bytes);

  CategoryUsage usageOf(StorageCategory category) => categories.firstWhere(
        (CategoryUsage c) => c.category == category,
        orElse: () => CategoryUsage(category: category, bytes: 0, itemCount: 0),
      );

  double fractionOf(StorageCategory category) =>
      totalBytes <= 0 ? 0 : usageOf(category).bytes / totalBytes;

  /// Categories with data, largest first. Empty categories are hidden so the
  /// breakdown stays readable on small screens.
  List<CategoryUsage> get nonEmpty {
    final List<CategoryUsage> list = categories
        .where((CategoryUsage c) => c.bytes > 0)
        .toList(growable: false);
    list.sort((CategoryUsage a, CategoryUsage b) => b.bytes.compareTo(a.bytes));
    return list;
  }

  static const StorageBreakdown empty = StorageBreakdown(
    totalBytes: 0,
    freeBytes: 0,
    categories: <CategoryUsage>[],
  );

  /// Aggregate entries into categories. Folders are skipped (their children are
  /// counted individually) which keeps totals from double-counting.
  static StorageBreakdown fromEntries({
    required int totalBytes,
    required int freeBytes,
    required Iterable<FileEntry> entries,
    int filesScanned = 0,
    int foldersScanned = 0,
    bool truncated = false,
  }) {
    final Map<StorageCategory, CategoryUsage> byCategory =
        <StorageCategory, CategoryUsage>{};

    for (final FileEntry entry in entries) {
      if (entry.isDirectory) continue;
      final StorageCategory category = entry.category;
      final CategoryUsage current = byCategory[category] ??
          CategoryUsage(category: category, bytes: 0, itemCount: 0);
      byCategory[category] = current.add(entry.sizeBytes);
    }

    return StorageBreakdown(
      totalBytes: totalBytes,
      freeBytes: freeBytes,
      categories: StorageCategory.values
          .map(
            (StorageCategory c) =>
                byCategory[c] ?? CategoryUsage(category: c, bytes: 0, itemCount: 0),
          )
          .toList(growable: false),
      filesScanned: filesScanned,
      foldersScanned: foldersScanned,
      truncated: truncated,
    );
  }
}
