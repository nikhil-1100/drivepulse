import 'package:drivepulse/core/utils/byte_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ByteFormat.format', () {
    test('keeps bytes under 1000 whole', () {
      expect(ByteFormat.format(0), '0 B');
      expect(ByteFormat.format(999), '999 B');
    });

    test('uses decimal units like drive vendors', () {
      expect(ByteFormat.format(1000), '1 KB');
      expect(ByteFormat.format(1024), '1 KB');
      expect(ByteFormat.format(840000), '840 KB');
      expect(ByteFormat.format(42400000), '42.4 MB');
      expect(ByteFormat.format(312400000), '312.4 MB');
      expect(ByteFormat.format(4200000000), '4.2 GB');
      expect(ByteFormat.format(128000000000), '128 GB');
      expect(ByteFormat.format(1000000000000), '1 TB');
    });

    test('handles invalid values', () {
      expect(ByteFormat.format(-1), '—');
      expect(ByteFormat.format(double.nan), '—');
    });

    test('compact removes the space', () {
      expect(ByteFormat.compact(4200000000), '4.2GB');
    });

    test('split returns value and unit separately', () {
      expect(ByteFormat.split(4200000000), ('4.2', 'GB'));
      expect(ByteFormat.split(999), ('999', 'B'));
    });
  });

  group('ByteFormat.percent', () {
    test('truncates so a full drive never reads 100 early', () {
      expect(ByteFormat.percent(0.656), '65%');
      expect(ByteFormat.percent(0.999), '99%');
      expect(ByteFormat.percent(1), '100%');
      expect(ByteFormat.percent(0), '0%');
    });

    test('clamps out-of-range input', () {
      expect(ByteFormat.percent(-0.2), '0%');
      expect(ByteFormat.percent(2), '100%');
    });
  });

  test('speed appends per-second unit', () {
    expect(ByteFormat.speed(142000000), '142 MB/s');
    expect(ByteFormat.speed(0), '0 B/s');
  });

  test('signed shows direction glyphs', () {
    expect(ByteFormat.signed(1400000000), '+ 1.4 GB');
    expect(ByteFormat.signed(420000000, freed: true), '− 420 MB');
  });

  test('eta is compact and human', () {
    expect(ByteFormat.eta(const Duration(seconds: 14)), '14s');
    expect(ByteFormat.eta(const Duration(minutes: 2, seconds: 10)), '2m 10s');
    expect(ByteFormat.eta(const Duration(hours: 1, minutes: 5)), '1h 5m');
    expect(ByteFormat.eta(null), '—');
  });

  test('count uses thousands separators', () {
    expect(ByteFormat.count(1280), '1,280');
    expect(ByteFormat.count(42), '42');
  });
}
