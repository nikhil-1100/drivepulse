import 'dart:async';

import 'package:flutter/services.dart';

import '../models/drive_health.dart';
import '../models/file_entry.dart';
import '../models/volume.dart';
import 'storage_service.dart';

/// Dart side of the DrivePulse native bridge.
///
/// Channel contract (also documented in `docs/NATIVE_API.md`):
///   method  `drivepulse/storage`   — request/response calls
///   event   `drivepulse/volumes`   — volume hot-plug events
///   callback `transferProgress`    — native → Dart progress ticks
class NativeStorageService extends StorageService {
  NativeStorageService() {
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  static const MethodChannel _channel = MethodChannel('drivepulse/storage');
  static const EventChannel _volumeEvents =
      EventChannel('drivepulse/volumes');

  final Map<String, void Function(TransferProgress)> _progressHandlers =
      <String, void Function(TransferProgress)>{};

  /// Names mocked out in widget tests; harmless in production.
  static const String channelName = 'drivepulse/storage';

  @override
  bool get isDemo => false;

  @override
  String get platformName => 'Native storage bridge';

  Future<T?> _invoke<T>(String method, [Map<String, dynamic>? args]) async {
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on PlatformException catch (error) {
      throw StorageException(
        error.message?.trim().isNotEmpty == true
            ? error.message!
            : 'The drive rejected the request.',
        code: error.code,
      );
    } on MissingPluginException {
      throw const StorageException(
        'Native storage bridge is unavailable on this platform.',
        code: 'unavailable',
      );
    }
  }

  Future<void> _handleNativeCall(MethodCall call) async {
    if (call.method != 'transferProgress') return;
    final Map<Object?, Object?> raw = call.arguments as Map<Object?, Object?>;
    final Map<String, dynamic> args = raw.map(
      (Object? key, Object? value) => MapEntry<String, dynamic>('$key', value),
    );
    final String taskId = '${args['taskId']}';
    _progressHandlers[taskId]?.call(
      TransferProgress(
        doneBytes: _asInt(args['doneBytes']),
        totalBytes: _asInt(args['totalBytes']),
        currentFile: args['currentFile'] as String?,
        bytesPerSecond: _asDouble(args['bytesPerSecond']),
      ),
    );
  }

  @override
  Future<List<Volume>> listVolumes() async {
    final List<dynamic>? raw = await _invoke<List<dynamic>>('listVolumes');
    return (raw ?? const <dynamic>[])
        .whereType<Map<Object?, Object?>>()
        .map((Map<Object?, Object?> map) => Volume.fromJson(_stringKeyed(map)))
        .toList(growable: false);
  }

  @override
  Future<Volume?> refreshVolume(String volumeId) async {
    final Map<Object?, Object?>? raw =
        await _invoke<Map<Object?, Object?>>('refreshVolume', <String, dynamic>{
      'volumeId': volumeId,
    });
    return raw == null ? null : Volume.fromJson(_stringKeyed(raw));
  }

  @override
  Future<List<FileEntry>> listDirectory(String path) async {
    final List<dynamic>? raw = await _invoke<List<dynamic>>(
      'listDirectory',
      <String, dynamic>{'path': path},
    );
    return (raw ?? const <dynamic>[])
        .whereType<Map<Object?, Object?>>()
        .map((Map<Object?, Object?> map) => FileEntry.fromJson(_stringKeyed(map)))
        .toList(growable: false);
  }

  @override
  Future<FileEntry?> stat(String path) async {
    final Map<Object?, Object?>? raw =
        await _invoke<Map<Object?, Object?>>('stat', <String, dynamic>{
      'path': path,
    });
    return raw == null ? null : FileEntry.fromJson(_stringKeyed(raw));
  }

  @override
  Future<FolderSummary> summarize(
    String path, {
    int maxDepth = 8,
    int maxEntries = 40000,
  }) async {
    final Map<Object?, Object?>? raw =
        await _invoke<Map<Object?, Object?>>('summarize', <String, dynamic>{
      'path': path,
      'maxDepth': maxDepth,
      'maxEntries': maxEntries,
    });
    if (raw == null) return FolderSummary.empty;
    return FolderSummary(
      bytes: _asInt(raw['bytes']),
      items: _asInt(raw['items']),
      folders: _asInt(raw['folders']),
    );
  }

  @override
  Future<List<FileEntry>> search(
    String rootPath,
    String query, {
    int limit = 300,
  }) async {
    final List<dynamic>? raw = await _invoke<List<dynamic>>(
      'search',
      <String, dynamic>{'root': rootPath, 'query': query, 'limit': limit},
    );
    return (raw ?? const <dynamic>[])
        .whereType<Map<Object?, Object?>>()
        .map((Map<Object?, Object?> map) => FileEntry.fromJson(_stringKeyed(map)))
        .toList(growable: false);
  }

  @override
  Future<void> createFolder(String parentPath, String name) async {
    await _invoke<void>('createFolder', <String, dynamic>{
      'parent': parentPath,
      'name': name,
    });
  }

  @override
  Future<void> rename(String path, String newName) async {
    await _invoke<void>('rename', <String, dynamic>{
      'path': path,
      'newName': newName,
    });
  }

  @override
  Future<void> deleteEntries(List<FileEntry> entries) async {
    await _invoke<void>('delete', <String, dynamic>{
      'entries': entries
          .map((FileEntry e) => <String, dynamic>{
                'path': e.path,
                'isDirectory': e.isDirectory,
              })
          .toList(growable: false),
    });
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
    _progressHandlers[taskId] = onProgress;
    try {
      final Map<Object?, Object?>? raw = await _invoke<Map<Object?, Object?>>(
        'transfer',
        <String, dynamic>{
          'taskId': taskId,
          'sources': sources
              .map((FileEntry e) => <String, dynamic>{
                    'path': e.path,
                    'name': e.name,
                    'isDirectory': e.isDirectory,
                  })
              .toList(growable: false),
          'destination': destinationPath,
          'move': move,
        },
      );
      return TransferOutcome(
        bytes: _asInt(raw?['bytes']),
        items: _asInt(raw?['items']),
      );
    } finally {
      _progressHandlers.remove(taskId);
    }
  }

  @override
  Future<void> pauseTransfer(String taskId, bool paused) async {
    await _invoke<void>('pauseTransfer', <String, dynamic>{
      'taskId': taskId,
      'paused': paused,
    });
  }

  @override
  Future<void> cancelTransfer(String taskId) async {
    await _invoke<void>('cancelTransfer', <String, dynamic>{'taskId': taskId});
  }

  @override
  Future<DriveHealth> benchmark(
    Volume volume, {
    void Function(double progress)? onProgress,
  }) async {
    final Map<Object?, Object?>? raw =
        await _invoke<Map<Object?, Object?>>('benchmark', <String, dynamic>{
      'volumeId': volume.id,
    });
    if (raw == null) return DriveHealth.unknown();
    final int percent = _asInt(raw['healthPercent']);
    return DriveHealth(
      readMbps: _asDouble(raw['readMbps']),
      writeMbps: _asDouble(raw['writeMbps']),
      latencyMs: _asDouble(raw['latencyMs']),
      healthPercent: percent,
      status: DriveHealth.statusFor(percent),
      checkedAt: DateTime.now(),
      smartSupported: raw['smartSupported'] == true,
      notes: (raw['notes'] as List<dynamic>? ?? const <dynamic>[])
          .map((dynamic e) => '$e')
          .toList(growable: false),
    );
  }

  @override
  Future<void> eject(Volume volume) async {
    await _invoke<void>('eject', <String, dynamic>{'volumeId': volume.id});
  }

  @override
  Future<Uint8List> readFile(String path) async {
    final Object? raw = await _invoke<Object>('readFile', <String, dynamic>{
      'path': path,
    });
    if (raw is Uint8List) return raw;
    if (raw is List<int>) return Uint8List.fromList(raw);
    if (raw is List<dynamic>) {
      return Uint8List.fromList(raw.map((dynamic e) => (e as num).toInt()).toList());
    }
    throw const StorageException('The driver returned no data.', code: 'io');
  }

  @override
  Future<void> writeFile(String path, Uint8List bytes) async {
    await _invoke<void>('writeFile', <String, dynamic>{
      'path': path,
      'bytes': bytes,
    });
  }

  @override
  Future<String> hashFile(String path) async {
    final String? hash = await _invoke<String>('hashFile', <String, dynamic>{
      'path': path,
    });
    return hash ?? '';
  }

  @override
  Future<bool> exists(String path) async {
    final bool? result = await _invoke<bool>('exists', <String, dynamic>{
      'path': path,
    });
    return result == true;
  }

  @override
  Future<FileEntry?> pickDirectory() async {
    final Map<Object?, Object?>? raw =
        await _invoke<Map<Object?, Object?>>('pickDirectory');
    return raw == null ? null : FileEntry.fromJson(_stringKeyed(raw));
  }

  @override
  Future<List<FileEntry>> pickFiles({bool multiple = true}) async {
    final List<dynamic>? raw = await _invoke<List<dynamic>>(
      'pickFiles',
      <String, dynamic>{'multiple': multiple},
    );
    return (raw ?? const <dynamic>[])
        .whereType<Map<Object?, Object?>>()
        .map((Map<Object?, Object?> map) => FileEntry.fromJson(_stringKeyed(map)))
        .toList(growable: false);
  }

  @override
  Stream<Volume> watchVolumes() {
    return _volumeEvents.receiveBroadcastStream().map((dynamic event) {
      if (event is Map<Object?, Object?>) return Volume.fromJson(_stringKeyed(event));
      return Volume.fromJson(<String, dynamic>{});
    }).handleError((Object error) {
      // A missing native listener must never break the dashboard.
    });
  }

  @override
  Future<Map<String, String>> deviceInfo() async {
    final Map<Object?, Object?>? raw =
        await _invoke<Map<Object?, Object?>>('deviceInfo');
    if (raw == null) return <String, String>{};
    return raw.map(
      (Object? key, Object? value) => MapEntry<String, String>('$key', '$value'),
    );
  }

  @override
  Future<void> dispose() async {
    _channel.setMethodCallHandler(null);
  }

  static Map<String, dynamic> _stringKeyed(Map<Object?, Object?> map) =>
      map.map((Object? k, Object? v) => MapEntry<String, dynamic>('$k', v));

  static int _asInt(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }

  static double _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? 0;
  }
}
