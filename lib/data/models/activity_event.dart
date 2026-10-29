import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Categories of things that happen on a drive. The history screen groups and
/// filters on these.
enum ActivityType {
  transfer,
  backup,
  sync,
  eject,
  connect,
  cleanup,
  format,
  encrypt,
  decrypt,
  delete,
  rename,
  createFolder,
  benchmark,
}

extension ActivityTypeX on ActivityType {
  String get label => switch (this) {
        ActivityType.transfer => 'Transfers',
        ActivityType.backup => 'Backup',
        ActivityType.sync => 'Sync & backup',
        ActivityType.eject => 'Eject & safe',
        ActivityType.connect => 'Connection',
        ActivityType.cleanup => 'Cleanup',
        ActivityType.format => 'Format',
        ActivityType.encrypt => 'Encryption',
        ActivityType.decrypt => 'Decryption',
        ActivityType.delete => 'Delete',
        ActivityType.rename => 'Rename',
        ActivityType.createFolder => 'Folder',
        ActivityType.benchmark => 'Benchmark',
      };

  IconData get icon => switch (this) {
        ActivityType.transfer => Icons.swap_horiz_rounded,
        ActivityType.backup => Icons.cloud_upload_rounded,
        ActivityType.sync => Icons.sync_rounded,
        ActivityType.eject => Icons.eject_rounded,
        ActivityType.connect => Icons.usb_rounded,
        ActivityType.cleanup => Icons.cleaning_services_rounded,
        ActivityType.format => Icons.restart_alt_rounded,
        ActivityType.encrypt => Icons.lock_rounded,
        ActivityType.decrypt => Icons.lock_open_rounded,
        ActivityType.delete => Icons.delete_outline_rounded,
        ActivityType.rename => Icons.drive_file_rename_outline_rounded,
        ActivityType.createFolder => Icons.create_new_folder_outlined,
        ActivityType.benchmark => Icons.speed_rounded,
      };

  Color tint(AppColors c) => switch (this) {
        ActivityType.cleanup => c.success,
        ActivityType.eject => c.success,
        ActivityType.encrypt || ActivityType.decrypt => c.primary,
        ActivityType.format || ActivityType.delete => c.danger,
        _ => c.textMuted,
      };
}

@immutable
class ActivityEvent {
  const ActivityEvent({
    required this.id,
    required this.type,
    required this.title,
    required this.timestamp,
    this.subtitle = '',
    this.volumeLabel = '',
    this.bytes = 0,
    this.statusLabel = '',
    this.isFailure = false,
  });

  final String id;
  final ActivityType type;
  final String title;
  final DateTime timestamp;
  final String subtitle;
  final String volumeLabel;
  final int bytes;
  final String statusLabel;
  final bool isFailure;

  /// `SanDisk Ultra Luxe • 1.4 GB` — the monospace metadata line.
  String get metaLine {
    final List<String> parts = <String>[
      if (volumeLabel.isNotEmpty) volumeLabel,
      if (bytes > 0) _bytesLabel(bytes),
    ];
    return parts.join(' • ');
  }

  String get resolvedStatus => statusLabel.isNotEmpty
      ? statusLabel
      : switch (type) {
          ActivityType.transfer => 'Completed',
          ActivityType.backup => 'Auto-Synced',
          ActivityType.sync => 'Auto-Synced',
          ActivityType.eject => 'Unmounted',
          ActivityType.cleanup => 'Optimized',
          ActivityType.format => 'Formatted',
          ActivityType.encrypt => 'Encrypted',
          ActivityType.decrypt => 'Decrypted',
          ActivityType.delete => 'Deleted',
          ActivityType.rename => 'Renamed',
          ActivityType.createFolder => 'Created',
          ActivityType.benchmark => 'Tested',
          ActivityType.connect => 'Connected',
        };

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'type': type.name,
        'title': title,
        'timestamp': timestamp.toIso8601String(),
        'subtitle': subtitle,
        'volumeLabel': volumeLabel,
        'bytes': bytes,
        'statusLabel': statusLabel,
        'isFailure': isFailure,
      };

  static ActivityEvent fromJson(Map<String, dynamic> json) {
    return ActivityEvent(
      id: '${json['id']}',
      type: ActivityType.values.firstWhere(
        (ActivityType t) => t.name == json['type'],
        orElse: () => ActivityType.transfer,
      ),
      title: '${json['title']}',
      timestamp: DateTime.tryParse('${json['timestamp']}') ?? DateTime.now(),
      subtitle: '${json['subtitle'] ?? ''}',
      volumeLabel: '${json['volumeLabel'] ?? ''}',
      bytes: (json['bytes'] as num?)?.toInt() ?? 0,
      statusLabel: '${json['statusLabel'] ?? ''}',
      isFailure: json['isFailure'] == true,
    );
  }

  static String _bytesLabel(int bytes) {
    if (bytes >= 1000000000) {
      return '${(bytes / 1000000000).toStringAsFixed(1)} GB';
    }
    if (bytes >= 1000000) return '${(bytes / 1000000).toStringAsFixed(0)} MB';
    if (bytes >= 1000) return '${(bytes / 1000).toStringAsFixed(0)} KB';
    return '$bytes B';
  }
}
