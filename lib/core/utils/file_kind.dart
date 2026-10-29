import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Broad storage buckets used by the analyzer, filter chips and breakdowns.
enum StorageCategory { photos, videos, audio, documents, archives, apps, other }

extension StorageCategoryX on StorageCategory {
  String get label => switch (this) {
        StorageCategory.photos => 'Photos',
        StorageCategory.videos => 'Videos',
        StorageCategory.audio => 'Audio',
        StorageCategory.documents => 'Documents',
        StorageCategory.archives => 'Archives',
        StorageCategory.apps => 'Apps',
        StorageCategory.other => 'Other',
      };

  String get plural => switch (this) {
        StorageCategory.photos => 'Photos',
        StorageCategory.videos => 'Videos',
        StorageCategory.audio => 'Audio files',
        StorageCategory.documents => 'Documents',
        StorageCategory.archives => 'Archives',
        StorageCategory.apps => 'Apps & packages',
        StorageCategory.other => 'Other files',
      };

  IconData get icon => switch (this) {
        StorageCategory.photos => Icons.photo_library_rounded,
        StorageCategory.videos => Icons.movie_rounded,
        StorageCategory.audio => Icons.graphic_eq_rounded,
        StorageCategory.documents => Icons.description_rounded,
        StorageCategory.archives => Icons.folder_zip_rounded,
        StorageCategory.apps => Icons.android_rounded,
        StorageCategory.other => Icons.insert_drive_file_rounded,
      };

  Color tint(AppColors c) => switch (this) {
        StorageCategory.photos => c.primary,
        StorageCategory.videos => const Color(0xFF7C3AED),
        StorageCategory.audio => const Color(0xFFD97706),
        StorageCategory.documents => const Color(0xFF2563EB),
        StorageCategory.archives => const Color(0xFF475569),
        StorageCategory.apps => const Color(0xFF059669),
        StorageCategory.other => c.textMuted,
      };
}

/// File class derived from the extension. Drives the icon, colour chip and
/// which analyzer bucket a file lands in.
enum FileKind {
  folder,
  image,
  rawImage,
  video,
  audio,
  document,
  archive,
  app,
  code,
  font,
  other,
}

extension FileKindX on FileKind {
  String get label => switch (this) {
        FileKind.folder => 'Folder',
        FileKind.image => 'Image',
        FileKind.rawImage => 'RAW image',
        FileKind.video => 'Video',
        FileKind.audio => 'Audio',
        FileKind.document => 'Document',
        FileKind.archive => 'Archive',
        FileKind.app => 'App package',
        FileKind.code => 'Code',
        FileKind.font => 'Font',
        FileKind.other => 'File',
      };

  StorageCategory get category => switch (this) {
        FileKind.folder => StorageCategory.other,
        FileKind.image || FileKind.rawImage => StorageCategory.photos,
        FileKind.video => StorageCategory.videos,
        FileKind.audio => StorageCategory.audio,
        FileKind.document || FileKind.code || FileKind.font =>
          StorageCategory.documents,
        FileKind.archive => StorageCategory.archives,
        FileKind.app => StorageCategory.apps,
        FileKind.other => StorageCategory.other,
      };

  IconData get icon => switch (this) {
        FileKind.folder => Icons.folder_rounded,
        FileKind.image => Icons.image_rounded,
        FileKind.rawImage => Icons.camera_rounded,
        FileKind.video => Icons.movie_rounded,
        FileKind.audio => Icons.graphic_eq_rounded,
        FileKind.document => Icons.description_rounded,
        FileKind.archive => Icons.folder_zip_rounded,
        FileKind.app => Icons.android_rounded,
        FileKind.code => Icons.terminal_rounded,
        FileKind.font => Icons.text_fields_rounded,
        FileKind.other => Icons.insert_drive_file_rounded,
      };

  Color tint(AppColors c) => switch (this) {
        FileKind.folder => c.textMuted,
        FileKind.image || FileKind.rawImage => c.primary,
        FileKind.video => const Color(0xFF7C3AED),
        FileKind.audio => const Color(0xFFD97706),
        FileKind.document => const Color(0xFF2563EB),
        FileKind.archive => const Color(0xFF475569),
        FileKind.app => const Color(0xFF059669),
        FileKind.code => const Color(0xFF0D9488),
        FileKind.font => const Color(0xFFDB2777),
        FileKind.other => c.textMuted,
      };
}

/// Extension → [FileKind] mapping plus display helpers.
abstract final class FileKinds {
  static const Set<String> images = <String>{
    'jpg', 'jpeg', 'png', 'gif', 'webp', 'heic', 'heif', 'bmp', 'tif', 'tiff',
    'svg', 'avif', 'jfif',
  };

  static const Set<String> rawImages = <String>{
    'raw', 'cr2', 'cr3', 'nef', 'arw', 'dng', 'raf', 'orf', 'rw2', 'pef', 'srw',
  };

  static const Set<String> videos = <String>{
    'mp4', 'mov', 'mkv', 'avi', 'webm', 'm4v', 'flv', 'wmv', '3gp', 'mts',
    'm2ts',
  };

  static const Set<String> audio = <String>{
    'mp3', 'wav', 'flac', 'aac', 'ogg', 'm4a', 'wma', 'opus', 'aiff', 'amr',
  };

  static const Set<String> documents = <String>{
    'pdf', 'doc', 'docx', 'txt', 'rtf', 'md', 'pages', 'xls', 'xlsx', 'csv',
    'ppt', 'pptx', 'key', 'epub', 'numbers', 'odt', 'ods',
  };

  static const Set<String> archives = <String>{
    'zip', 'rar', '7z', 'tar', 'gz', 'tgz', 'bz2', 'xz', 'iso', 'dmg', 'img',
    'cab',
  };

  static const Set<String> apps = <String>{
    'apk', 'aab', 'ipa', 'exe', 'msi', 'appx', 'deb', 'rpm',
  };

  static const Set<String> code = <String>{
    'dart', 'js', 'ts', 'jsx', 'tsx', 'py', 'java', 'kt', 'swift', 'c', 'cc',
    'cpp', 'h', 'hpp', 'cs', 'go', 'rs', 'rb', 'php', 'json', 'xml', 'yaml',
    'yml', 'toml', 'html', 'css', 'scss', 'sh', 'bat', 'ps1', 'sql', 'ini',
  };

  static const Set<String> fonts = <String>{
    'ttf', 'otf', 'woff', 'woff2', 'eot',
  };

  /// Lower-case extension without the dot, or empty when there is none.
  static String extensionOf(String fileName) {
    final int dot = fileName.lastIndexOf('.');
    if (dot <= 0 || dot == fileName.length - 1) return '';
    return fileName.substring(dot + 1).toLowerCase();
  }

  static FileKind fromPath(String path, {bool isDirectory = false}) {
    if (isDirectory) return FileKind.folder;
    final String ext = extensionOf(path);
    if (ext.isEmpty) return FileKind.other;
    if (images.contains(ext)) return FileKind.image;
    if (rawImages.contains(ext)) return FileKind.rawImage;
    if (videos.contains(ext)) return FileKind.video;
    if (audio.contains(ext)) return FileKind.audio;
    if (documents.contains(ext)) return FileKind.document;
    if (archives.contains(ext)) return FileKind.archive;
    if (apps.contains(ext)) return FileKind.app;
    if (code.contains(ext)) return FileKind.code;
    if (fonts.contains(ext)) return FileKind.font;
    return FileKind.other;
  }

  /// Chip label shown on file rows: `RAW`, `PDF`, `XLSX`, `APK`.
  static String chipLabel(String path, {bool isDirectory = false}) {
    if (isDirectory) return 'DIR';
    final String ext = extensionOf(path);
    if (ext.isEmpty) return 'FILE';
    if (ext.length <= 4) return ext.toUpperCase();
    return ext.substring(0, 4).toUpperCase();
  }

  /// Filters a mixed list into a storage category. Folders are excluded from
  /// category totals because their children are counted individually.
  static StorageCategory categoryOf(String path, {bool isDirectory = false}) =>
      fromPath(path, isDirectory: isDirectory).category;
}
