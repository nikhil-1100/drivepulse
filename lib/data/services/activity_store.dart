import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/activity_event.dart';

/// Append-only local activity log.
///
/// Persisted to a JSON file in the app support directory on Android/iOS, and to
/// SharedPreferences on web (where there is no filesystem). History never
/// leaves the device and is capped so it cannot grow without bound.
class ActivityStore {
  ActivityStore({this.capacity = 400});

  final int capacity;

  static const String _prefsKey = 'activity.events.v1';

  final List<ActivityEvent> _events = <ActivityEvent>[];
  bool _loaded = false;
  Future<void>? _pendingWrite;

  List<ActivityEvent> get events => List<ActivityEvent>.unmodifiable(_events);

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final String? raw = await _readRaw();
      if (raw == null || raw.isEmpty) return;
      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      _events
        ..clear()
        ..addAll(decoded
            .whereType<Map<String, dynamic>>()
            .map(ActivityEvent.fromJson));
    } catch (error) {
      debugPrint('ActivityStore: could not load history ($error)');
    }
  }

  Future<void> add(ActivityEvent event) async {
    _events.insert(0, event);
    if (_events.length > capacity) {
      _events.removeRange(capacity, _events.length);
    }
    await _save();
  }

  Future<void> clear() async {
    _events.clear();
    await _save();
  }

  Future<void> seedIfEmpty(List<ActivityEvent> seed) async {
    if (_events.isNotEmpty) return;
    _events.addAll(seed.take(capacity));
    await _save();
  }

  Future<void> _save() async {
    final String payload =
        jsonEncode(_events.map((ActivityEvent e) => e.toJson()).toList());
    // Coalesce rapid writes; the newest payload always wins.
    _pendingWrite = (_pendingWrite ?? Future<void>.value()).then((_) async {
      try {
        if (kIsWeb) {
          final SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setString(_prefsKey, payload);
        } else {
          final File file = await _file();
          await file.parent.create(recursive: true);
          await file.writeAsString(payload, flush: true);
        }
      } catch (error) {
        debugPrint('ActivityStore: could not save history ($error)');
      }
    });
    await _pendingWrite;
  }

  Future<String?> _readRaw() async {
    if (kIsWeb) {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      return prefs.getString(_prefsKey);
    }
    final File file = await _file();
    if (!await file.exists()) return null;
    return file.readAsString();
  }

  Future<File> _file() async {
    final Directory base = await getApplicationSupportDirectory();
    return File('${base.path}/drivepulse/activity.json');
  }
}
