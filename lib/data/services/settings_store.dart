import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum LibraryView { list, grid }

enum SortField { name, size, modified, kind }

extension SortFieldX on SortField {
  String get label => switch (this) {
        SortField.name => 'Name',
        SortField.size => 'Size',
        SortField.modified => 'Date',
        SortField.kind => 'Type',
      };
}

/// All user preferences, persisted locally with SharedPreferences.
///
/// There is deliberately no account, sync or remote settings source: the app is
/// usable on a plane with the radio off.
class SettingsController extends ChangeNotifier {
  SettingsController(this._prefs);

  final SharedPreferences _prefs;

  static const String _kTheme = 'settings.theme';
  static const String _kAutoHideNav = 'settings.autoHideNav';
  static const String _kHaptics = 'settings.haptics';
  static const String _kAlerts = 'settings.alerts';
  static const String _kLowStorage = 'settings.lowStoragePercent';
  static const String _kView = 'settings.view';
  static const String _kSort = 'settings.sort';
  static const String _kSortAsc = 'settings.sortAscending';
  static const String _kConfirm = 'settings.confirmDestructive';
  static const String _kHidden = 'settings.showHidden';
  static const String _kLargeFile = 'settings.largeFileMb';
  static const String _kOnboarded = 'settings.onboarded';
  static const String _kFavorites = 'library.favorites';

  static Future<SettingsController> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return SettingsController(prefs);
  }

  ThemeMode get themeMode => switch (_prefs.getString(_kTheme) ?? 'system') {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  bool get autoHideNav => _prefs.getBool(_kAutoHideNav) ?? false;
  bool get haptics => _prefs.getBool(_kHaptics) ?? true;
  bool get alertsEnabled => _prefs.getBool(_kAlerts) ?? true;
  int get lowStoragePercent => _prefs.getInt(_kLowStorage) ?? 15;
  LibraryView get view =>
      (_prefs.getString(_kView) ?? 'list') == 'grid'
          ? LibraryView.grid
          : LibraryView.list;
  SortField get sortField => switch (_prefs.getString(_kSort) ?? 'name') {
        'size' => SortField.size,
        'modified' => SortField.modified,
        'kind' => SortField.kind,
        _ => SortField.name,
      };
  bool get sortAscending => _prefs.getBool(_kSortAsc) ?? true;
  bool get confirmDestructive => _prefs.getBool(_kConfirm) ?? true;
  bool get showHidden => _prefs.getBool(_kHidden) ?? false;
  int get largeFileThresholdMb => _prefs.getInt(_kLargeFile) ?? 100;
  bool get onboarded => _prefs.getBool(_kOnboarded) ?? false;

  List<String> get favorites =>
      _prefs.getStringList(_kFavorites) ?? const <String>[];

  Future<void> setThemeMode(ThemeMode mode) async {
    await _prefs.setString(_kTheme, mode.name);
    notifyListeners();
  }

  Future<void> setAutoHideNav(bool value) async {
    await _prefs.setBool(_kAutoHideNav, value);
    notifyListeners();
  }

  Future<void> setHaptics(bool value) async {
    await _prefs.setBool(_kHaptics, value);
    notifyListeners();
  }

  Future<void> setAlerts(bool value) async {
    await _prefs.setBool(_kAlerts, value);
    notifyListeners();
  }

  Future<void> setLowStoragePercent(int value) async {
    await _prefs.setInt(_kLowStorage, value.clamp(5, 50));
    notifyListeners();
  }

  Future<void> setView(LibraryView value) async {
    await _prefs.setString(_kView, value.name);
    notifyListeners();
  }

  Future<void> setSort(SortField field, {bool? ascending}) async {
    await _prefs.setString(_kSort, field.name);
    if (ascending != null) await _prefs.setBool(_kSortAsc, ascending);
    notifyListeners();
  }

  Future<void> setConfirmDestructive(bool value) async {
    await _prefs.setBool(_kConfirm, value);
    notifyListeners();
  }

  Future<void> setShowHidden(bool value) async {
    await _prefs.setBool(_kHidden, value);
    notifyListeners();
  }

  Future<void> setLargeFileThreshold(int megabytes) async {
    await _prefs.setInt(_kLargeFile, megabytes.clamp(10, 2000));
    notifyListeners();
  }

  Future<void> completeOnboarding() async {
    await _prefs.setBool(_kOnboarded, true);
    notifyListeners();
  }

  Future<void> toggleFavorite(String path) async {
    final List<String> current = List<String>.from(favorites);
    if (!current.remove(path)) current.add(path);
    await _prefs.setStringList(_kFavorites, current);
    notifyListeners();
  }

  Future<void> resetPreferences() async {
    for (final String key in <String>[
      _kTheme,
      _kAutoHideNav,
      _kHaptics,
      _kAlerts,
      _kLowStorage,
      _kView,
      _kSort,
      _kSortAsc,
      _kConfirm,
      _kHidden,
      _kLargeFile,
    ]) {
      await _prefs.remove(key);
    }
    notifyListeners();
  }
}
