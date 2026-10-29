import 'package:drivepulse/core/utils/file_kind.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FileKinds.fromPath', () {
    test('maps common media and documents', () {
      expect(FileKinds.fromPath('/a/IMG_2024_Hero.raw'), FileKind.rawImage);
      expect(FileKinds.fromPath('/a/photo.JPG'), FileKind.image);
      expect(FileKinds.fromPath('/a/clip.mp4'), FileKind.video);
      expect(FileKinds.fromPath('/a/track.wav'), FileKind.audio);
      expect(FileKinds.fromPath('/a/Proposal.pdf'), FileKind.document);
      expect(FileKinds.fromPath('/a/archive.zip'), FileKind.archive);
      expect(FileKinds.fromPath('/a/app.apk'), FileKind.app);
      expect(FileKinds.fromPath('/a/main.dart'), FileKind.code);
      expect(FileKinds.fromPath('/a/font.ttf'), FileKind.font);
    });

    test('handles folders, dotfiles and unknown extensions', () {
      expect(FileKinds.fromPath('/a/camera', isDirectory: true), FileKind.folder);
      expect(FileKinds.fromPath('/a/.hidden'), FileKind.other);
      expect(FileKinds.fromPath('/a/README'), FileKind.other);
      expect(FileKinds.fromPath('/a/weird.xyz'), FileKind.other);
    });
  });

  group('FileKinds.chipLabel', () {
    test('upper-cases extensions and shortens long ones', () {
      expect(FileKinds.chipLabel('/a/photo.jpeg'), 'JPEG');
      expect(FileKinds.chipLabel('/a/Proposal.pdf'), 'PDF');
      expect(FileKinds.chipLabel('/a/sheet.xlsx'), 'XLSX');
      expect(FileKinds.chipLabel('/a/weird.extension'), 'EXTE');
      expect(FileKinds.chipLabel('/a/README'), 'FILE');
      expect(FileKinds.chipLabel('/a/folder', isDirectory: true), 'DIR');
    });
  });

  group('categories', () {
    test('raw images count as photos', () {
      expect(FileKinds.categoryOf('/a/x.cr2'), StorageCategory.photos);
      expect(FileKinds.categoryOf('/a/x.mp4'), StorageCategory.videos);
      expect(FileKinds.categoryOf('/a/x.mp3'), StorageCategory.audio);
      expect(FileKinds.categoryOf('/a/x.pdf'), StorageCategory.documents);
      expect(FileKinds.categoryOf('/a/x.zip'), StorageCategory.archives);
      expect(FileKinds.categoryOf('/a/x.apk'), StorageCategory.apps);
      expect(FileKinds.categoryOf('/a/x.xyz'), StorageCategory.other);
    });
  });

  test('extensionOf handles missing and trailing dots', () {
    expect(FileKinds.extensionOf('photo.PNG'), 'png');
    expect(FileKinds.extensionOf('README'), '');
    expect(FileKinds.extensionOf('trailing.'), '');
    expect(FileKinds.extensionOf('.hidden'), '');
  });
}
