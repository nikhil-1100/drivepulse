import 'package:flutter/foundation.dart';

/// How a volume is attached. Used for the icon and the protocol pill.
enum VolumeKind { internal, usbFlash, externalSsd, sdCard, hdd }

extension VolumeKindX on VolumeKind {
  String get label => switch (this) {
        VolumeKind.internal => 'Internal storage',
        VolumeKind.usbFlash => 'USB flash drive',
        VolumeKind.externalSsd => 'External SSD',
        VolumeKind.sdCard => 'SD card',
        VolumeKind.hdd => 'External hard drive',
      };

  bool get isRemovable => this != VolumeKind.internal;

  static VolumeKind parse(String? raw) {
    return switch (raw) {
      'internal' => VolumeKind.internal,
      'usbFlash' => VolumeKind.usbFlash,
      'externalSsd' => VolumeKind.externalSsd,
      'sdCard' => VolumeKind.sdCard,
      'hdd' => VolumeKind.hdd,
      _ => VolumeKind.usbFlash,
    };
  }
}

/// A mounted (or remembered) storage volume.
@immutable
class Volume {
  const Volume({
    required this.id,
    required this.label,
    required this.fileSystem,
    required this.totalBytes,
    required this.freeBytes,
    required this.kind,
    required this.busLabel,
    this.protocolLabel = '',
    this.serial = '',
    this.mountPath = '',
    this.readMbps = 0,
    this.writeMbps = 0,
    this.healthPercent = 100,
    this.isReadOnly = false,
    this.isConnected = true,
    this.smartSupported = false,
    this.lastSeen,
  });

  final String id;
  final String label;
  final String fileSystem;
  final int totalBytes;
  final int freeBytes;
  final VolumeKind kind;
  final String busLabel;
  final String protocolLabel;
  final String serial;
  final String mountPath;
  final double readMbps;
  final double writeMbps;
  final int healthPercent;
  final bool isReadOnly;
  final bool isConnected;
  final bool smartSupported;
  final DateTime? lastSeen;

  bool get isInternal => kind == VolumeKind.internal;
  bool get isRemovable => kind.isRemovable;
  int get usedBytes => (totalBytes - freeBytes).clamp(0, totalBytes);
  double get usedFraction => totalBytes <= 0 ? 0 : usedBytes / totalBytes;
  double get freeFraction => totalBytes <= 0 ? 0 : freeBytes / totalBytes;
  bool get isCritical => usedFraction >= 0.9;
  bool get isLow => usedFraction >= 0.8 && !isCritical;
  bool get isHealthy => healthPercent >= 80;

  /// Filesystem badge, upper-cased for the monospace pills (`EXFAT`).
  String get fileSystemLabel =>
      fileSystem.isEmpty ? 'UNKNOWN' : fileSystem.toUpperCase();

  String get capacityLabel => '${_gb(totalBytes)} GB';

  String get protocolOrBus => protocolLabel.isNotEmpty ? protocolLabel : busLabel;

  String get mountLabel =>
      mountPath.isEmpty ? (isInternal ? 'Internal app storage' : 'Not mounted') : mountPath;

  Volume copyWith({
    String? id,
    String? label,
    String? fileSystem,
    int? totalBytes,
    int? freeBytes,
    VolumeKind? kind,
    String? busLabel,
    String? protocolLabel,
    String? serial,
    String? mountPath,
    double? readMbps,
    double? writeMbps,
    int? healthPercent,
    bool? isReadOnly,
    bool? isConnected,
    bool? smartSupported,
    DateTime? lastSeen,
  }) {
    return Volume(
      id: id ?? this.id,
      label: label ?? this.label,
      fileSystem: fileSystem ?? this.fileSystem,
      totalBytes: totalBytes ?? this.totalBytes,
      freeBytes: freeBytes ?? this.freeBytes,
      kind: kind ?? this.kind,
      busLabel: busLabel ?? this.busLabel,
      protocolLabel: protocolLabel ?? this.protocolLabel,
      serial: serial ?? this.serial,
      mountPath: mountPath ?? this.mountPath,
      readMbps: readMbps ?? this.readMbps,
      writeMbps: writeMbps ?? this.writeMbps,
      healthPercent: healthPercent ?? this.healthPercent,
      isReadOnly: isReadOnly ?? this.isReadOnly,
      isConnected: isConnected ?? this.isConnected,
      smartSupported: smartSupported ?? this.smartSupported,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'label': label,
        'fileSystem': fileSystem,
        'totalBytes': totalBytes,
        'freeBytes': freeBytes,
        'kind': kind.name,
        'busLabel': busLabel,
        'protocolLabel': protocolLabel,
        'serial': serial,
        'mountPath': mountPath,
        'readMbps': readMbps,
        'writeMbps': writeMbps,
        'healthPercent': healthPercent,
        'isReadOnly': isReadOnly,
        'isConnected': isConnected,
        'smartSupported': smartSupported,
        'lastSeen': lastSeen?.toIso8601String(),
      };

  static Volume fromJson(Map<String, dynamic> json) {
    int asInt(Object? value) =>
        value is num ? value.toInt() : int.tryParse('$value') ?? 0;
    double asDouble(Object? value) =>
        value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

    return Volume(
      id: '${json['id']}',
      label: '${json['label'] ?? 'Drive'}',
      fileSystem: '${json['fileSystem'] ?? ''}',
      totalBytes: asInt(json['totalBytes']),
      freeBytes: asInt(json['freeBytes']),
      kind: VolumeKindX.parse(json['kind'] as String?),
      busLabel: '${json['busLabel'] ?? ''}',
      protocolLabel: '${json['protocolLabel'] ?? ''}',
      serial: '${json['serial'] ?? ''}',
      mountPath: '${json['mountPath'] ?? ''}',
      readMbps: asDouble(json['readMbps']),
      writeMbps: asDouble(json['writeMbps']),
      healthPercent: asInt(json['healthPercent'] ?? 100),
      isReadOnly: json['isReadOnly'] == true,
      isConnected: json['isConnected'] == true,
      smartSupported: json['smartSupported'] == true,
      lastSeen: DateTime.tryParse('${json['lastSeen']}'),
    );
  }

  static String _gb(int bytes) {
    final double gb = bytes / 1000000000;
    return gb >= 100 ? gb.round().toString() : gb.toStringAsFixed(0);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Volume && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
