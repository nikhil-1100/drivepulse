import 'package:flutter/foundation.dart';

enum HealthStatus { healthy, warning, critical, unknown }

extension HealthStatusX on HealthStatus {
  String get label => switch (this) {
        HealthStatus.healthy => 'Healthy',
        HealthStatus.warning => 'Check drive',
        HealthStatus.critical => 'At risk',
        HealthStatus.unknown => 'Not tested',
      };
}

/// Result of the local read/write benchmark.
///
/// Android and iOS do not expose S.M.A.R.T. on removable media, so health is a
/// composite of measured throughput, free-space pressure and write errors —
/// clearly labelled as an estimate in the UI instead of pretending to be SMART.
@immutable
class DriveHealth {
  const DriveHealth({
    required this.readMbps,
    required this.writeMbps,
    required this.latencyMs,
    required this.healthPercent,
    required this.status,
    required this.checkedAt,
    this.smartSupported = false,
    this.notes = const <String>[],
  });

  final double readMbps;
  final double writeMbps;
  final double latencyMs;
  final int healthPercent;
  final HealthStatus status;
  final DateTime checkedAt;
  final bool smartSupported;
  final List<String> notes;

  String get readLabel => '${readMbps.toStringAsFixed(0)} MB/s';
  String get writeLabel => '${writeMbps.toStringAsFixed(0)} MB/s';

  static DriveHealth unknown() => DriveHealth(
        readMbps: 0,
        writeMbps: 0,
        latencyMs: 0,
        healthPercent: 0,
        status: HealthStatus.unknown,
        checkedAt: DateTime.fromMillisecondsSinceEpoch(0),
      );

  static HealthStatus statusFor(int percent) {
    if (percent <= 0) return HealthStatus.unknown;
    if (percent >= 80) return HealthStatus.healthy;
    if (percent >= 55) return HealthStatus.warning;
    return HealthStatus.critical;
  }
}
