import 'package:intl/intl.dart';

/// Human-readable byte formatting.
///
/// Drive capacity is advertised in decimal units (a "128 GB" drive is
/// 128,000,000,000 bytes), so the manager reports decimal units everywhere to
/// avoid the classic "why does my 128 GB drive show 119 GB?" complaint. The
/// helper is pure Dart so it is unit-tested without Flutter bindings.
abstract final class ByteFormat {
  static const List<String> _units = <String>['B', 'KB', 'MB', 'GB', 'TB', 'PB'];

  /// Formats [bytes] with a space between value and unit: `4.8 GB`.
  ///
  /// Values below 1000 bytes are shown as whole bytes. Values under 10 keep one
  /// decimal, under 100 keep one decimal, above that we drop to whole numbers
  /// so long lists of file sizes stay aligned.
  static String format(num bytes, {int? decimals}) {
    if (bytes.isNaN || bytes < 0) return '—';
    if (bytes < 1000) return '${bytes.round()} B';

    double value = bytes.toDouble();
    int unit = 0;
    while (value >= 1000 && unit < _units.length - 1) {
      value /= 1000;
      unit++;
    }
    final int fixed = decimals ?? (value == value.roundToDouble() ? 0 : 1);
    final String number = value
        .toStringAsFixed(fixed)
        .replaceFirst(RegExp(r'\.0+$'), '');
    return '$number ${_units[unit]}';
  }

  /// Compact variant without a space, useful for tiny badges: `4.8GB`.
  static String compact(num bytes) => format(bytes).replaceAll(' ', '');

  /// Splits a formatted size into value and unit for two-line metric layouts.
  static (String, String) split(num bytes) {
    final String text = format(bytes);
    final int space = text.indexOf(' ');
    if (space < 0) return (text, '');
    return (text.substring(0, space), text.substring(space + 1));
  }

  /// `65%` — truncates instead of rounding up so a full drive never reads
  /// "100%" while a byte is still free.
  static String percent(double fraction, {int decimals = 0}) {
    final double clamped = fraction.isNaN ? 0 : fraction.clamp(0, 1);
    final int factor = decimals == 0 ? 1 : (decimals == 1 ? 10 : 100);
    final double truncated = (clamped * 100 * factor).floor() / factor;
    return '${truncated.toStringAsFixed(decimals)}%';
  }

  /// `142 MB/s` from a bytes-per-second value.
  static String speed(double bytesPerSecond) {
    if (bytesPerSecond <= 0) return '0 B/s';
    return '${format(bytesPerSecond)}/s';
  }

  /// Transfer sizes with a signed direction: `+ 1.4 GB` / `− 420 MB`.
  static String signed(num bytes, {bool freed = false}) {
    return '${freed ? '−' : '+'} ${format(bytes)}';
  }

  static final NumberFormat _count = NumberFormat.decimalPattern();

  /// `1,280 items`.
  static String count(int value) => _count.format(value);

  /// Remaining time, tuned for transfer banners (`2m 10s`, `14s`, `> 1h`).
  static String eta(Duration? duration) {
    if (duration == null || duration.isNegative) return '—';
    if (duration.inSeconds < 1) return 'moments';
    if (duration.inHours >= 1) {
      final int hours = duration.inHours;
      final int minutes = duration.inMinutes.remainder(60);
      return minutes == 0 ? '${hours}h' : '${hours}h ${minutes}m';
    }
    if (duration.inMinutes >= 1) {
      final int minutes = duration.inMinutes;
      final int seconds = duration.inSeconds.remainder(60);
      return seconds == 0 ? '${minutes}m' : '${minutes}m ${seconds}s';
    }
    return '${duration.inSeconds}s';
  }
}
