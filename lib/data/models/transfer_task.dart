import 'package:flutter/foundation.dart';

enum TransferStatus { queued, running, paused, completed, failed, cancelled }

extension TransferStatusX on TransferStatus {
  String get label => switch (this) {
        TransferStatus.queued => 'Queued',
        TransferStatus.running => 'Transferring',
        TransferStatus.paused => 'Paused',
        TransferStatus.completed => 'Completed',
        TransferStatus.failed => 'Failed',
        TransferStatus.cancelled => 'Cancelled',
      };

  bool get isActive =>
      this == TransferStatus.queued ||
      this == TransferStatus.running ||
      this == TransferStatus.paused;
}

enum TransferDirection { copy, move, backup }

extension TransferDirectionX on TransferDirection {
  String get label => switch (this) {
        TransferDirection.copy => 'Copy',
        TransferDirection.move => 'Move',
        TransferDirection.backup => 'Backup',
      };
}

/// A copy/move job. The engine mutates a task through [copyWith] and notifies
/// listeners; the UI never touches the filesystem directly.
@immutable
class TransferTask {
  const TransferTask({
    required this.id,
    required this.label,
    required this.direction,
    required this.itemCount,
    required this.totalBytes,
    required this.doneBytes,
    required this.status,
    required this.createdAt,
    this.sourceLabel = '',
    this.targetLabel = '',
    this.bytesPerSecond = 0,
    this.finishedAt,
    this.error,
    this.currentFile,
  });

  final String id;
  final String label;
  final TransferDirection direction;
  final int itemCount;
  final int totalBytes;
  final int doneBytes;
  final TransferStatus status;
  final DateTime createdAt;
  final String sourceLabel;
  final String targetLabel;
  final double bytesPerSecond;
  final DateTime? finishedAt;
  final String? error;
  final String? currentFile;

  double get progress => totalBytes <= 0
      ? (status == TransferStatus.completed ? 1 : 0)
      : (doneBytes / totalBytes).clamp(0, 1);

  bool get isActive => status.isActive;
  bool get isPaused => status == TransferStatus.paused;

  Duration? get eta {
    if (bytesPerSecond <= 0 || totalBytes <= 0) return null;
    final int remaining = (totalBytes - doneBytes).clamp(0, totalBytes);
    return Duration(seconds: (remaining / bytesPerSecond).round());
  }

  /// `Camera Roll → SanDisk` style route label.
  String get routeLabel {
    if (sourceLabel.isEmpty && targetLabel.isEmpty) return label;
    if (sourceLabel.isEmpty) return '→ $targetLabel';
    if (targetLabel.isEmpty) return '$sourceLabel →';
    return '$sourceLabel → $targetLabel';
  }

  TransferTask copyWith({
    String? label,
    TransferDirection? direction,
    int? itemCount,
    int? totalBytes,
    int? doneBytes,
    TransferStatus? status,
    String? sourceLabel,
    String? targetLabel,
    double? bytesPerSecond,
    DateTime? finishedAt,
    String? error,
    String? currentFile,
  }) {
    return TransferTask(
      id: id,
      label: label ?? this.label,
      direction: direction ?? this.direction,
      itemCount: itemCount ?? this.itemCount,
      totalBytes: totalBytes ?? this.totalBytes,
      doneBytes: doneBytes ?? this.doneBytes,
      status: status ?? this.status,
      createdAt: createdAt,
      sourceLabel: sourceLabel ?? this.sourceLabel,
      targetLabel: targetLabel ?? this.targetLabel,
      bytesPerSecond: bytesPerSecond ?? this.bytesPerSecond,
      finishedAt: finishedAt ?? this.finishedAt,
      error: error ?? this.error,
      currentFile: currentFile ?? this.currentFile,
    );
  }
}
