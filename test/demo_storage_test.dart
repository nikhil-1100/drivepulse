import 'package:drivepulse/data/models/file_entry.dart';
import 'package:drivepulse/data/models/volume.dart';
import 'package:drivepulse/data/services/demo_storage_service.dart';
import 'package:drivepulse/data/services/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DemoStorageService storage;

  setUp(() {
    storage = DemoStorageService();
  });

  test('exposes internal plus removable volumes, internal first', () async {
    final List<Volume> volumes = await storage.listVolumes();
    expect(volumes.length, 5);
    expect(volumes.first.isInternal, isTrue);
    expect(volumes.where((Volume v) => v.isConnected).length, 2);
    final Volume sandisk =
        volumes.firstWhere((Volume v) => v.id == 'sandisk-ultra');
    expect(sandisk.isConnected, isTrue);
    expect(sandisk.fileSystemLabel, 'EXFAT');
    expect(sandisk.usedFraction, closeTo(84 / 128, 0.001));
  });

  test('lists and summarises a seeded folder', () async {
    final List<FileEntry> root = await storage.listDirectory('/SanDisk');
    expect(root.map((FileEntry e) => e.name), contains('Camera_RAW'));

    final FolderSummary summary = await storage.summarize('/SanDisk/Camera_RAW');
    expect(summary.items, greaterThan(5));
    expect(summary.bytes, greaterThan(1000000000));
  });

  test('searches recursively and is case-insensitive', () async {
    final List<FileEntry> matches = await storage.search('/SanDisk', 'hero');
    expect(matches, isNotEmpty);
    expect(
      matches.any((FileEntry e) => e.name.contains('IMG_2024_Hero')),
      isTrue,
    );
  });

  test('creates, renames and deletes a folder', () async {
    await storage.createFolder('/SanDisk', 'Unit_Test');
    expect(await storage.exists('/SanDisk/Unit_Test'), isTrue);

    await storage.rename('/SanDisk/Unit_Test', 'Unit_Test_Renamed');
    expect(await storage.exists('/SanDisk/Unit_Test_Renamed'), isTrue);
    expect(await storage.exists('/SanDisk/Unit_Test'), isFalse);

    final FileEntry folder = (await storage.stat('/SanDisk/Unit_Test_Renamed'))!;
    await storage.deleteEntries(<FileEntry>[folder]);
    expect(await storage.exists('/SanDisk/Unit_Test_Renamed'), isFalse);
  });

  test('refuses duplicate folder names', () async {
    await storage.createFolder('/SanDisk', 'Dupe');
    expect(
      () => storage.createFolder('/SanDisk', 'Dupe'),
      throwsA(isA<StorageException>()),
    );
  });

  test('copies a file with progress and keeps the source', () async {
    final List<FileEntry> files = await storage.listDirectory('/SanDisk');
    final FileEntry source =
        files.firstWhere((FileEntry e) => e.name == 'IMG_2024_Hero.raw');
    final List<TransferProgress> ticks = <TransferProgress>[];
    final TransferOutcome outcome = await storage.transfer(
      taskId: 'test-copy',
      sources: <FileEntry>[source],
      destinationPath: '/Internal/Download',
      move: false,
      token: CancelToken(),
      onProgress: ticks.add,
    );

    expect(outcome.bytes, source.sizeBytes);
    expect(outcome.items, 1);
    expect(ticks, isNotEmpty);
    final List<FileEntry> destination = await storage.listDirectory('/Internal/Download');
    expect(destination.any((FileEntry e) => e.name == source.name), isTrue);
    expect(await storage.exists(source.path), isTrue);
  });

  test('moves a file and removes the source', () async {
    final List<FileEntry> files = await storage.listDirectory('/SanDisk');
    final FileEntry source =
        files.firstWhere((FileEntry e) => e.name == 'Financial_Report.xlsx');

    await storage.transfer(
      taskId: 'test-move',
      sources: <FileEntry>[source],
      destinationPath: '/Internal/Documents',
      move: true,
      token: CancelToken(),
      onProgress: (_) {},
    );

    expect(await storage.exists('/SanDisk/Financial_Report.xlsx'), isFalse);
    expect(await storage.exists('/Internal/Documents/Financial_Report.xlsx'), isTrue);
  });

  test('cancelling aborts the transfer', () async {
    final CancelToken token = CancelToken()..cancel();
    final List<FileEntry> files = await storage.listDirectory('/SanDisk');
    expect(
      () => storage.transfer(
        taskId: 'test-cancel',
        sources: <FileEntry>[files.first],
        destinationPath: '/Internal/Download',
        move: false,
        token: token,
        onProgress: (_) {},
      ),
      throwsA(isA<StorageException>()),
    );
  });

  test('ejecting a removable volume disconnects it', () async {
    final Volume sandisk = (await storage.listVolumes())
        .firstWhere((Volume v) => v.id == 'sandisk-ultra');
    await storage.eject(sandisk);
    final Volume after =
        (await storage.listVolumes()).firstWhere((Volume v) => v.id == sandisk.id);
    expect(after.isConnected, isFalse);
    expect(
      () => storage.eject(sandisk),
      throwsA(isA<StorageException>()),
    );
  });
}
