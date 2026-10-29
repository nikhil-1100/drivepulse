import 'package:flutter/foundation.dart';

import '../../core/utils/file_kind.dart';

/// One file or folder row. Sizes are bytes; folder sizes are optional because
/// computing them requires a scan.
@immutable
class FileEntry {
  const FileEntry({
    required this.path,
    required this.name,
    required this.isDirectory,
    required this.sizeBytes,
    required this.modifiedAt,
    this.childCount,
    this.folderBytes,
    this.isHidden = false,
  });

  final String path;
  final String name;
  final bool isDirectory;
  final int sizeBytes;
  final DateTime modifiedAt;

  /// Number of immediate children, when known.
  final int? childCount;

  /// Recursive byte size for folders, when a scan has measured it.
  final int? folderBytes;

  final bool isHidden;

  FileKind get kind => FileKinds.fromPath(name, isDirectory: isDirectory);

  StorageCategory get category => kind.category;

  String get extension => FileKinds.extensionOf(name);

  String get chipLabel => FileKinds.chipLabel(name, isDirectory: isDirectory);

  int get effectiveSize => isDirectory ? (folderBytes ?? 0) : sizeBytes;

  String get parentPath {
    final int slash = path.lastIndexOf('/');
    if (slash <= 0) return '/';
    return path.substring(0, slash);
  }

  String get displayName => isDirectory ? name : name;

  FileEntry copyWith({
    String? path,
    String? name,
    bool? isDirectory,
    int? sizeBytes,
    DateTime? modifiedAt,
    int? childCount,
    int? folderBytes,
    bool? isHidden,
  }) {
    return FileEntry(
      path: path ?? this.path,
      name: name ?? this.name,
      isDirectory: isDirectory ?? this.isDirectory,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      childCount: childCount ?? this.childCount,
      folderBytes: folderBytes ?? this.folderBytes,
      isHidden: isHidden ?? this.isHidden,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'path': path,
        'name': name,
        'isDirectory': isDirectory,
        'sizeBytes': sizeBytes,
        'modifiedAt': modifiedAt.toIso8601String(),
        'childCount': childCount,
        'folderBytes': folderBytes,
        'isHidden': isHidden,
      };

  static FileEntry fromJson(Map<String, dynamic> json) {
    return FileEntry(
      path: '${json['path']}',
      name: '${json['name']}',
      isDirectory: json['isDirectory'] == true,
      sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
      modifiedAt: DateTime.tryParse('${json['modifiedAt']}') ?? DateTime.now(),
      childCount: (json['childCount'] as num?)?.toInt(),
      folderBytes: (json['folderBytes'] as num?)?.toInt(),
      isHidden: json['isHidden'] == true,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is FileEntry && other.path == path);

  @override
  int get hashCode => path.hashCode;
}

/// Result of summarising a directory tree.
@immutable
class FolderSummary {
  const FolderSummary({
    required this.bytes,
    required this.items,
    required this.folders,
  });

  final int bytes;
  final int items;
  final int folders;

  static const FolderSummary empty =
      FolderSummary(bytes: 0, items: 0, folders: 0);
}
