import 'package:drivepulse/data/models/clean_up_report.dart';
import 'package:drivepulse/data/models/storage_breakdown.dart';
import 'package:drivepulse/data/models/volume.dart';
import 'package:drivepulse/data/services/analyzer_service.dart';
import 'package:drivepulse/data/services/demo_storage_service.dart';
import 'package:drivepulse/core/utils/file_kind.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DemoStorageService storage;
  late AnalyzerService analyzer;
  late Volume internalVolume;

  setUp(() async {
    storage = DemoStorageService();
    analyzer = AnalyzerService(storage);
    internalVolume = (await storage.listVolumes())
        .firstWhere((Volume v) => v.id == 'internal');
  });

  test('builds a category breakdown without double-counting folders', () async {
    final CleanUpReport report = await analyzer.analyze(
      internalVolume,
      largeFileThresholdBytes: 100000000,
    );
    final StorageBreakdown breakdown = report.breakdown;

    expect(breakdown.filesScanned, greaterThan(10));
    expect(breakdown.categories.length, StorageCategory.values.length);
    expect(breakdown.usageOf(StorageCategory.photos).bytes, greaterThan(0));
    expect(breakdown.usageOf(StorageCategory.videos).bytes, greaterThan(0));
    expect(breakdown.usageOf(StorageCategory.documents).bytes, greaterThan(0));
    expect(breakdown.categorisedBytes, lessThanOrEqualTo(breakdown.usedBytes));
    expect(breakdown.truncated, isFalse);
  });

  test('finds junk in cache and trash folders', () async {
    final CleanUpReport report = await analyzer.analyze(
      internalVolume,
      largeFileThresholdBytes: 100000000,
    );
    expect(report.junkFiles, isNotEmpty);
    expect(
      report.junkFiles.every((dynamic file) => !file.isDirectory),
      isTrue,
    );
    expect(report.junkBytes, greaterThan(0));
    expect(report.reclaimableBytes, greaterThan(0));
  });

  test('detects byte-identical duplicates and reports reclaimable space', () async {
    final CleanUpReport report = await analyzer.analyze(
      internalVolume,
      largeFileThresholdBytes: 100000000,
    );
    expect(report.duplicates, isNotEmpty);
    final DuplicateGroup group = report.duplicates.first;
    expect(group.files.length, greaterThanOrEqualTo(2));
    expect(group.redundantBytes, group.sizeBytes * (group.files.length - 1));
  });

  test('lists large files above the threshold, biggest first', () async {
    final CleanUpReport report = await analyzer.analyze(
      internalVolume,
      largeFileThresholdBytes: 100000000,
    );
    expect(report.largeFiles, isNotEmpty);
    for (int i = 1; i < report.largeFiles.length; i++) {
      expect(
        report.largeFiles[i - 1].sizeBytes,
        greaterThanOrEqualTo(report.largeFiles[i].sizeBytes),
      );
    }
    expect(
      report.largeFiles.every((dynamic f) => f.sizeBytes >= 100000000),
      isTrue,
    );
  });

  test('scan can be cancelled cooperatively', () async {
    expect(
      () => analyzer.analyze(
        internalVolume,
        largeFileThresholdBytes: 100000000,
        isCancelled: () => true,
      ),
      throwsA(isA<Exception>()),
    );
  });
}
