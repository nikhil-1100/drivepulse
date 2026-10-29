import 'package:flutter/foundation.dart';

import '../models/file_entry.dart';
import '../models/transfer_task.dart';
import 'storage_service.dart';

/// Owns the copy/move queue and its lifecycle.
///
/// One job runs at a time on purpose: removable media hate interleaved streams,
/// and a single visible banner is easier to reason about than five competing
/// progress bars. Jobs are cancellable, and pausing takes effect at the next
/// file boundary (stated in the UI).
class TransferController extends ChangeNotifier {
  TransferController({
    required this.storage,
    this.onFinished,
    this.onStarted,
  });

  final StorageService storage;

  /// Called once when a job reaches a terminal state.
  final void Function(TransferTask task)? onFinished;
  final void Function(TransferTask task)? onStarted;

  final List<TransferTask> _tasks = <TransferTask>[];
  final Map<String, CancelToken> _tokens = <String, CancelToken>{};
  int _sequence = 0;

  List<TransferTask> get tasks => List<TransferTask>.unmodifiable(_tasks);

  TransferTask? get activeTask {
    for (final TransferTask task in _tasks) {
      if (task.isActive) return task;
    }
    return null;
  }

  bool get hasActive => activeTask != null;

  List<TransferTask> get recent =>
      _tasks.where((TransferTask t) => !t.isActive).take(8).toList(growable: false);

  Future<TransferTask> start({
    required List<FileEntry> sources,
    required String destinationPath,
    required String destinationLabel,
    String sourceLabel = '',
    TransferDirection direction = TransferDirection.copy,
    String? label,
  }) async {
    _sequence++;
    final String id = 'tx-${DateTime.now().millisecondsSinceEpoch}-$_sequence';
    final int totalBytes = sources.fold<int>(
      0,
      (int sum, FileEntry e) => sum + e.effectiveSize,
    );
    final String jobLabel = label ??
        (sources.length == 1
            ? sources.first.name
            : '${sources.length} items');

    final TransferTask task = TransferTask(
      id: id,
      label: jobLabel,
      direction: direction,
      itemCount: sources.length,
      totalBytes: totalBytes,
      doneBytes: 0,
      status: TransferStatus.running,
      createdAt: DateTime.now(),
      sourceLabel: sourceLabel,
      targetLabel: destinationLabel,
    );
    _tasks.insert(0, task);
    final CancelToken token = CancelToken();
    _tokens[id] = token;
    notifyListeners();
    onStarted?.call(task);

    try {
      final TransferOutcome outcome = await storage.transfer(
        taskId: id,
        sources: sources,
        destinationPath: destinationPath,
        move: direction == TransferDirection.move,
        token: token,
        onProgress: (TransferProgress progress) {
          _update(
            id,
            (TransferTask current) => current.copyWith(
              doneBytes: progress.doneBytes,
              totalBytes: progress.totalBytes > 0
                  ? progress.totalBytes
                  : current.totalBytes,
              bytesPerSecond: progress.bytesPerSecond,
              currentFile: progress.currentFile,
              status: TransferStatus.running,
            ),
          );
        },
      );
      return _finish(
        id,
        (TransferTask current) => current.copyWith(
          status: TransferStatus.completed,
          doneBytes: outcome.bytes > 0 ? outcome.bytes : current.totalBytes,
          totalBytes: outcome.bytes > 0 ? outcome.bytes : current.totalBytes,
          itemCount: outcome.items,
          finishedAt: DateTime.now(),
          bytesPerSecond: 0,
        ),
      );
    } on StorageException catch (error) {
      final bool cancelled =
          error.code == 'cancelled' || token.isCancelled;
      return _finish(
        id,
        (TransferTask current) => current.copyWith(
          status: cancelled ? TransferStatus.cancelled : TransferStatus.failed,
          finishedAt: DateTime.now(),
          error: cancelled ? null : error.message,
          bytesPerSecond: 0,
        ),
      );
    } catch (error) {
      return _finish(
        id,
        (TransferTask current) => current.copyWith(
          status: TransferStatus.failed,
          finishedAt: DateTime.now(),
          error: '$error',
          bytesPerSecond: 0,
        ),
      );
    } finally {
      _tokens.remove(id);
    }
  }

  Future<void> pause(String taskId) async {
    _update(taskId, (TransferTask t) => t.copyWith(status: TransferStatus.paused));
    await storage.pauseTransfer(taskId, true);
  }

  Future<void> resume(String taskId) async {
    _update(taskId, (TransferTask t) => t.copyWith(status: TransferStatus.running));
    await storage.pauseTransfer(taskId, false);
  }

  Future<void> cancel(String taskId) async {
    _tokens[taskId]?.cancel();
    await storage.cancelTransfer(taskId);
    _update(
      taskId,
      (TransferTask t) => t.copyWith(
        status: TransferStatus.cancelled,
        finishedAt: DateTime.now(),
        bytesPerSecond: 0,
      ),
    );
  }

  void remove(String taskId) {
    _tasks.removeWhere((TransferTask t) => t.id == taskId);
    notifyListeners();
  }

  void clearFinished() {
    _tasks.removeWhere((TransferTask t) => !t.isActive);
    notifyListeners();
  }

  TransferTask _finish(
    String id,
    TransferTask Function(TransferTask current) transform,
  ) {
    _update(id, transform);
    final TransferTask finished = _tasks.firstWhere((TransferTask t) => t.id == id);
    onFinished?.call(finished);
    return finished;
  }

  void _update(String id, TransferTask Function(TransferTask current) transform) {
    final int index = _tasks.indexWhere((TransferTask t) => t.id == id);
    if (index < 0) return;
    _tasks[index] = transform(_tasks[index]);
    notifyListeners();
  }
}
