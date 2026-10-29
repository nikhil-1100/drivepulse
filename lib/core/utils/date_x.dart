import 'package:intl/intl.dart';

/// Date helpers used by the activity log, file rows and transfer queue.
///
/// All helpers accept an optional `now` so tests are deterministic.
abstract final class DateX {
  static final DateFormat _clock = DateFormat.jm();
  static final DateFormat _monthDay = DateFormat('MMM d');
  static final DateFormat _weekdayTime = DateFormat('EEE h:mm a');
  static final DateFormat _fullDate = DateFormat('MMM d, yyyy');
  static final DateFormat _fullDateTime = DateFormat('MMM d, yyyy • h:mm a');

  static bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// `Just now`, `18m ago`, `2h ago`, `Yesterday`, `Mon 3:45 PM`, `Oct 14`.
  static String relative(DateTime time, {DateTime? now}) {
    final DateTime reference = now ?? DateTime.now();
    final Duration diff = reference.difference(time);

    if (diff.isNegative) return _clock.format(time);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (sameDay(time, reference)) return '${diff.inHours}h ago';
    if (sameDay(time, reference.subtract(const Duration(days: 1)))) {
      return 'Yesterday';
    }
    if (diff.inDays < 7) return _weekdayTime.format(time);
    if (time.year == reference.year) return _monthDay.format(time);
    return _fullDate.format(time);
  }

  /// `Today`, `Yesterday`, `Monday`, `Oct 12`.
  static String dayHeader(DateTime time, {DateTime? now}) {
    final DateTime reference = now ?? DateTime.now();
    if (sameDay(time, reference)) return 'Today';
    if (sameDay(time, reference.subtract(const Duration(days: 1)))) {
      return 'Yesterday';
    }
    final Duration diff = reference.difference(time);
    if (diff.inDays < 7 && diff.inDays > 0) return DateFormat('EEEE').format(time);
    if (time.year == reference.year) return _monthDay.format(time);
    return _fullDate.format(time);
  }

  static String clock(DateTime time) => _clock.format(time);

  static String full(DateTime time) => _fullDateTime.format(time);

  /// File-browser style timestamp: `Today, 2:15 PM`, `Oct 14`, `Sep 28, 2025`.
  static String fileStamp(DateTime time, {DateTime? now}) {
    final DateTime reference = now ?? DateTime.now();
    if (sameDay(time, reference)) return 'Today, ${_clock.format(time)}';
    if (sameDay(time, reference.subtract(const Duration(days: 1)))) {
      return 'Yesterday, ${_clock.format(time)}';
    }
    if (time.year == reference.year) return _monthDay.format(time);
    return _fullDate.format(time);
  }

  /// Groups ascending or descending events into ordered day buckets.
  static Map<String, List<T>> groupByDay<T>(
    Iterable<T> items,
    DateTime Function(T) timestamp, {
    DateTime? now,
  }) {
    final Map<String, List<T>> groups = <String, List<T>>{};
    for (final T item in items) {
      final String key = dayHeader(timestamp(item), now: now);
      groups.putIfAbsent(key, () => <T>[]).add(item);
    }
    return groups;
  }
}
