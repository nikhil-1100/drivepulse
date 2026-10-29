import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/routing.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_type.dart';
import '../../core/utils/byte_format.dart';
import '../../core/utils/date_x.dart';
import '../../core/utils/file_kind.dart';
import '../../core/widgets/dialogs.dart';
import '../../core/widgets/dp_card.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/file_row.dart';
import '../../core/widgets/filter_bar.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/sheets.dart';
import '../../data/models/file_entry.dart';
import '../../data/models/transfer_task.dart';
import '../../data/models/volume.dart';
import '../../data/services/settings_store.dart';
import '../../data/services/storage_service.dart';
import '../../data/state/app_state.dart';

/// File browser: breadcrumb navigation, recursive search, filters, multi-select
/// and local copy/move/encrypt actions. Works against the native bridge on
/// Android/iOS and the demo tree in preview builds.
class BrowseScreen extends StatefulWidget {
  const BrowseScreen({
    super.key,
    this.volume,
    this.initialPath,
    this.selectMode = false,
  });

  final Volume? volume;
  final String? initialPath;
  final bool selectMode;

  @override
  State<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends State<BrowseScreen> {
  late Volume? _volume;
  late String _path;
  late LibraryView _view;
  late SortField _sort;
  late bool _ascending;

  final TextEditingController _searchController = TextEditingController();
  final Map<String, FolderSummary> _summaries = <String, FolderSummary>{};
  final Map<String, FileEntry> _selected = <String, FileEntry>{};

  List<FileEntry> _entries = <FileEntry>[];
  List<FileEntry>? _searchResults;
  bool _loading = true;
  bool _searching = false;
  bool _selectionMode = false;
  bool _showHidden = false;
  String? _error;
  String? _errorCode;
  String _query = '';
  StorageCategory? _filter;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    final SettingsController settings = context.read<SettingsController>();
    _view = settings.view;
    _sort = settings.sortField;
    _ascending = settings.sortAscending;
    _showHidden = settings.showHidden;
    final AppState app = context.read<AppState>();
    _volume = widget.volume ?? app.currentVolume;
    _path = widget.initialPath ?? (_volume == null ? '/' : app.rootFor(_volume!));
    _selectionMode = widget.selectMode;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  AppState get _app => context.read<AppState>();

  String get _root => _volume == null ? '/' : _app.rootFor(_volume!);

  String get _relativePath {
    if (_volume == null) return _path;
    if (_path == _root) return 'Root';
    final String prefix = '$_root/';
    return _path.startsWith(prefix) ? _path.substring(prefix.length) : _path;
  }

  List<(String, String)> get _crumbs {
    final List<(String, String)> crumbs = <(String, String)>[
      (_volume?.label ?? 'Storage', _root),
    ];
    if (_path == _root) return crumbs;
    final String prefix = '$_root/';
    final String rel = _path.startsWith(prefix) ? _path.substring(prefix.length) : _path;
    final List<String> parts = rel.split('/').where((String p) => p.isNotEmpty).toList();
    String cursor = _root;
    for (final String part in parts) {
      cursor = '$cursor/$part';
      crumbs.add((part, cursor));
    }
    return crumbs;
  }

  Future<void> _load() async {
    if (_volume == null) {
      setState(() {
        _loading = false;
        _error = 'No drive is available.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _errorCode = null;
    });
    try {
      final List<FileEntry> entries = await _app.listDirectory(_path);
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _loading = false;
      });
      unawaited(_loadFolderSizes(entries));
    } on StorageException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _errorCode = error.code;
        _loading = false;
        _entries = <FileEntry>[];
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '$error';
        _loading = false;
        _entries = <FileEntry>[];
      });
    }
  }

  Future<void> _loadFolderSizes(List<FileEntry> entries) async {
    final List<FileEntry> folders =
        entries.where((FileEntry e) => e.isDirectory).take(10).toList(growable: false);
    for (final FileEntry folder in folders) {
      if (_summaries.containsKey(folder.path)) continue;
      try {
        final FolderSummary summary = await _app.summarize(folder);
        if (!mounted) return;
        setState(() => _summaries[folder.path] = summary);
      } on StorageException {
        continue;
      }
    }
  }

  void _navigate(String path) {
    setState(() {
      _path = path;
      _query = '';
      _searchController.clear();
      _searchResults = null;
      _selected.clear();
      _selectionMode = false;
      _filter = null;
    });
    _load();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    final String query = value.trim();
    setState(() => _query = value);
    if (query.length < 2) {
      setState(() {
        _searchResults = null;
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 320), () async {
      final List<FileEntry> results = await _app.search(query, volume: _volume);
      if (!mounted || _query.trim() != query) return;
      setState(() {
        _searchResults = results;
        _searching = false;
      });
    });
  }

  List<FileEntry> get _sourceEntries =>
      _searchResults ?? _entries;

  List<FileEntry> get _visibleEntries {
    final List<FileEntry> list = _sourceEntries.where((FileEntry entry) {
      if (!_showHidden && entry.isHidden) return false;
      if (entry.name.startsWith('.') && entry.name != '.' && !_showHidden) {
        return false;
      }
      if (_filter != null && !entry.isDirectory && entry.category != _filter) {
        return false;
      }
      if (_filter != null && entry.isDirectory) return false;
      return true;
    }).toList();

    list.sort(_compare);
    return list;
  }

  List<FileEntry> get _folders =>
      _visibleEntries.where((FileEntry e) => e.isDirectory).toList(growable: false);

  List<FileEntry> get _files =>
      _visibleEntries.where((FileEntry e) => !e.isDirectory).toList(growable: false);

  int _compare(FileEntry a, FileEntry b) {
    if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
    int value;
    switch (_sort) {
      case SortField.name:
        value = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      case SortField.size:
        value = a.effectiveSize.compareTo(b.effectiveSize);
      case SortField.modified:
        value = a.modifiedAt.compareTo(b.modifiedAt);
      case SortField.kind:
        value = a.chipLabel.compareTo(b.chipLabel);
    }
    return _ascending ? value : -value;
  }

  FileEntry _enrich(FileEntry entry) {
    if (!entry.isDirectory) return entry;
    final FolderSummary? summary = _summaries[entry.path];
    if (summary == null) return entry;
    return entry.copyWith(folderBytes: summary.bytes, childCount: summary.items);
  }

  bool _isSelected(FileEntry entry) => _selected.containsKey(entry.path);

  void _toggleSelect(FileEntry entry) {
    setState(() {
      _selectionMode = true;
      if (_selected.containsKey(entry.path)) {
        _selected.remove(entry.path);
      } else {
        _selected[entry.path] = entry;
      }
      if (_selected.isEmpty) _selectionMode = false;
    });
  }

  void _clearSelection() {
    setState(() {
      _selected.clear();
      _selectionMode = false;
    });
  }

  void _selectAll() {
    setState(() {
      _selectionMode = true;
      for (final FileEntry entry in _visibleEntries) {
        _selected[entry.path] = entry;
      }
    });
  }

  Future<void> _onEntryTap(FileEntry entry) async {
    if (_selectionMode) {
      _toggleSelect(entry);
      return;
    }
    if (entry.isDirectory) {
      _navigate(entry.path);
      return;
    }
    await _openFile(entry);
  }

  Future<void> _onEntryLongPress(FileEntry entry) {
    _toggleSelect(entry);
    return Future<void>.value();
  }

  Future<void> _openFile(FileEntry entry) async {
    if (kIsWeb || _app.isDemo) {
      await _showDetails(entry);
      return;
    }
    try {
      final OpenResult result = await OpenFilex.open(entry.path);
      if (!mounted) return;
      if (result.type != ResultType.done) {
        showAppToast(
          context,
          result.message.isEmpty ? 'No app can open this file.' : result.message,
          icon: Icons.error_outline_rounded,
          iconColor: context.colors.danger,
        );
      }
    } catch (error) {
      if (!mounted) return;
      showAppToast(context, '$error', icon: Icons.error_outline_rounded);
    }
  }

  Future<void> _shareFile(FileEntry entry) async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[XFile(entry.path)],
          text: entry.name,
          subject: entry.name,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      showAppToast(context, 'Sharing unavailable: $error');
    }
  }

  Future<void> _showDetails(FileEntry entry) async {
    final _FileAction? action = await showDpSheet<_FileAction>(
      context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              FileTypeChip(entry: entry, size: 48),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      entry.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.headlineSmall(context.colors.text)
                          .copyWith(fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      entry.isDirectory
                          ? '${entry.childCount ?? 0} items in this folder'
                          : '${entry.kind.label} • ${ByteFormat.format(entry.sizeBytes)}',
                      style: AppType.bodySmall(context.colors.textMuted),
                    ),
                  ],
                ),
              ),
              if (_app.isFavorite(entry.path))
                Icon(Icons.star_rounded, color: context.colors.primary, size: 20),
            ],
          ),
          const SizedBox(height: Insets.md),
          _DetailLine(label: 'Path', value: entry.path),
          _DetailLine(
            label: 'Modified',
            value: DateX.full(entry.modifiedAt),
          ),
          if (entry.isDirectory)
            _DetailLine(
              label: 'Folder size',
              value: entry.folderBytes == null
                  ? 'Calculating…'
                  : ByteFormat.format(entry.folderBytes!),
            ),
          const SizedBox(height: Insets.sm),
          const Divider(),
          SheetAction(
            icon: Icons.open_in_new_rounded,
            label: entry.isDirectory ? 'Open folder' : 'Open file',
            onTap: () => Navigator.of(context).pop(_FileAction.open),
          ),
          if (!entry.isDirectory)
            SheetAction(
              icon: Icons.share_outlined,
              label: 'Share',
              description: 'Hand the file to another app',
              onTap: () => Navigator.of(context).pop(_FileAction.share),
            ),
          SheetAction(
            icon: _app.isFavorite(entry.path)
                ? Icons.star_rounded
                : Icons.star_outline_rounded,
            label: _app.isFavorite(entry.path)
                ? 'Remove from favourites'
                : 'Add to favourites',
            onTap: () => Navigator.of(context).pop(_FileAction.favorite),
          ),
          SheetAction(
            icon: Icons.drive_file_rename_outline_rounded,
            label: 'Rename',
            onTap: () => Navigator.of(context).pop(_FileAction.rename),
          ),
          SheetAction(
            icon: Icons.copy_all_rounded,
            label: 'Copy to another drive',
            onTap: () => Navigator.of(context).pop(_FileAction.copy),
          ),
          SheetAction(
            icon: Icons.drive_file_move_outline,
            label: 'Move to another drive',
            onTap: () => Navigator.of(context).pop(_FileAction.move),
          ),
          if (!entry.isDirectory)
            SheetAction(
              icon: Icons.lock_outline_rounded,
              label: 'Encrypt with passphrase',
              description: 'AES-256-GCM, passphrase never stored',
              onTap: () => Navigator.of(context).pop(_FileAction.encrypt),
            ),
          SheetAction(
            icon: Icons.delete_outline_rounded,
            label: 'Delete',
            destructive: true,
            onTap: () => Navigator.of(context).pop(_FileAction.delete),
          ),
        ],
      ),
    );

    if (action == null || !mounted) return;
    switch (action) {
      case _FileAction.open:
        if (entry.isDirectory) {
          _navigate(entry.path);
        } else {
          await _openFile(entry);
        }
      case _FileAction.share:
        await _shareFile(entry);
      case _FileAction.favorite:
        await _app.toggleFavorite(entry.path);
        if (!mounted) return;
        setState(() {});
      case _FileAction.rename:
        await _renameEntry(entry);
      case _FileAction.copy:
        await _copyMove(<FileEntry>[entry], move: false);
      case _FileAction.move:
        await _copyMove(<FileEntry>[entry], move: true);
      case _FileAction.encrypt:
        await _encrypt(<FileEntry>[entry]);
      case _FileAction.delete:
        await _deleteEntries(<FileEntry>[entry]);
    }
  }

  Future<void> _renameEntry(FileEntry entry) async {
    final String? name = await showTextPrompt(
      context,
      title: 'Rename',
      message: 'Enter a new name for “${entry.name}”.',
      initialValue: entry.name,
      selectBaseName: !entry.isDirectory,
      confirmLabel: 'Rename',
      validator: (String value) {
        if (value.trim().isEmpty) return 'Enter a name';
        if (value.contains('/')) return 'Names cannot contain "/"';
        if (value.trim() == entry.name) return 'Name is unchanged';
        return null;
      },
    );
    if (name == null || !mounted) return;
    final Volume? volume = _volume;
    if (volume == null) return;
    try {
      await _app.renameEntry(entry: entry, newName: name, volume: volume);
      await _load();
      if (!mounted) return;
      showAppToast(context, 'Renamed to “$name”');
    } on StorageException catch (error) {
      if (!mounted) return;
      showAppToast(
        context,
        error.message,
        icon: Icons.error_outline_rounded,
        iconColor: context.colors.danger,
      );
    }
  }

  Future<void> _createFolder() async {
    final String? name = await showTextPrompt(
      context,
      title: 'New folder',
      message: 'Create a folder inside ${_relativePath == 'Root' ? _volume?.label ?? 'the drive' : _relativePath}.',
      hint: 'Folder name',
      confirmLabel: 'Create',
      icon: Icons.create_new_folder_outlined,
      validator: (String value) {
        if (value.trim().isEmpty) return 'Enter a folder name';
        if (value.contains('/')) return 'Names cannot contain "/"';
        return null;
      },
    );
    if (name == null || !mounted) return;
    final Volume? volume = _volume;
    if (volume == null) return;
    try {
      await _app.createFolder(parentPath: _path, name: name, volume: volume);
      await _load();
      if (!mounted) return;
      showAppToast(context, 'Folder “$name” created');
    } on StorageException catch (error) {
      if (!mounted) return;
      showAppToast(
        context,
        error.message,
        icon: Icons.error_outline_rounded,
        iconColor: context.colors.danger,
      );
    }
  }

  Future<void> _deleteEntries(List<FileEntry> entries) async {
    if (entries.isEmpty) return;
    final Volume? volume = _volume;
    if (volume == null) return;
    final int bytes = entries.fold<int>(
      0,
      (int sum, FileEntry e) => sum + (e.isDirectory ? 0 : e.sizeBytes),
    );
    final bool needsConfirm =
        context.read<SettingsController>().confirmDestructive;
    bool confirmed = true;
    if (needsConfirm) {
      confirmed = await showConfirmDialog(
        context,
        title: entries.length == 1
            ? 'Delete this item?'
            : 'Delete ${entries.length} items?',
        message:
            'This permanently removes ${entries.length == 1 ? '“${entries.first.name}”' : 'the selected items'}'
            '${bytes > 0 ? ' (${ByteFormat.format(bytes)})' : ''} from ${volume.label}. '
            'This cannot be undone.',
        confirmLabel: 'Delete',
        destructive: true,
        icon: Icons.delete_outline_rounded,
      );
    }
    if (!confirmed || !mounted) return;
    try {
      await _app.deleteEntries(entries: entries, volume: volume);
      _clearSelection();
      await _load();
      if (!mounted) return;
      showAppToast(
        context,
        entries.length == 1 ? 'Item deleted' : '${entries.length} items deleted',
      );
    } on StorageException catch (error) {
      if (!mounted) return;
      showAppToast(
        context,
        error.message,
        icon: Icons.error_outline_rounded,
        iconColor: context.colors.danger,
      );
    }
  }

  Future<void> _encrypt(List<FileEntry> entries) async {
    final Volume? volume = _volume;
    if (volume == null) return;
    final List<FileEntry> files =
        entries.where((FileEntry e) => !e.isDirectory).toList(growable: false);
    if (files.isEmpty) {
      showAppToast(context, 'Only files can be encrypted.');
      return;
    }
    final String? passphrase = await showPassphrasePrompt(
      context,
      title: 'Encrypt ${files.length == 1 ? 'file' : '${files.length} files'}',
      message:
          'AES-256-GCM with a 120,000-round PBKDF2 key. The passphrase is never '
          'stored — if you lose it, the data cannot be recovered.',
      confirmTwice: true,
      confirmLabel: 'Encrypt',
    );
    if (passphrase == null || !mounted) return;
    try {
      final int count =
          await _app.encryptFiles(entries: files, password: passphrase, volume: volume);
      _clearSelection();
      await _load();
      if (!mounted) return;
      showAppToast(context, '$count file${count == 1 ? '' : 's'} encrypted');
    } catch (error) {
      if (!mounted) return;
      showAppToast(
        context,
        '$error',
        icon: Icons.error_outline_rounded,
        iconColor: context.colors.danger,
      );
    }
  }

  Future<void> _copyMove(List<FileEntry> entries, {required bool move}) async {
    if (entries.isEmpty) return;
    final Volume? source = _volume;
    if (source == null) return;
    final List<Volume> targets = _app.connectedVolumes
        .where((Volume v) => v.id != source.id)
        .toList(growable: false);
    if (targets.isEmpty) {
      showAppToast(
        context,
        'Connect a second drive to ${move ? 'move' : 'copy'} files to.',
        icon: Icons.usb_rounded,
      );
      return;
    }

    final Volume? target = await showDpSheet<Volume>(
      context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SheetHeader(
            title: move ? 'Move to…' : 'Copy to…',
            subtitle: '${entries.length} item${entries.length == 1 ? '' : 's'} '
                'from ${source.label}',
          ),
          for (final Volume volume in targets)
            SheetAction(
              icon: Icons.usb_rounded,
              label: volume.label,
              description:
                  '${ByteFormat.format(volume.freeBytes)} free • ${volume.protocolOrBus}',
              trailing: Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: context.colors.textFaint,
              ),
              onTap: () => Navigator.of(context).pop(volume),
            ),
          const SizedBox(height: Insets.sm),
          InfoBanner(
            message: move
                ? 'Moved items are removed from ${source.label} after a verified copy.'
                : 'Files are copied into the drive root. Same-name files are replaced.',
            tone: BannerTone.neutral,
          ),
        ],
      ),
    );
    if (target == null || !mounted) return;

    await _app.transferFiles(
      sources: entries,
      destination: target,
      destinationPath: _app.rootFor(target),
      sourceLabel: source.label,
      direction: move ? TransferDirection.move : TransferDirection.copy,
      label: entries.length == 1 ? entries.first.name : '${entries.length} items',
    );
    _clearSelection();
    if (!mounted) return;
    showAppToast(
      context,
      '${move ? 'Move' : 'Copy'} started to ${target.label}',
      icon: Icons.swap_horiz_rounded,
    );
  }

  Future<void> _sortSheet() async {
    await showDpSheet<void>(
      context,
      child: StatefulBuilder(
        builder: (BuildContext ctx, void Function(VoidCallback) setSheetState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SheetHeader(
                title: 'Sort files',
                subtitle: 'Folders always stay on top',
              ),
              RadioGroup<SortField>(
                groupValue: _sort,
                onChanged: (SortField? value) {
                  if (value == null) return;
                  setState(() => _sort = value);
                  context.read<SettingsController>().setSort(value);
                  setSheetState(() {});
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    for (final SortField field in SortField.values)
                      RadioListTile<SortField>(
                        value: field,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          field.label,
                          style: AppType.bodyMedium(context.colors.text),
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(),
              SwitchListTile(
                value: _ascending,
                onChanged: (bool value) {
                  setState(() => _ascending = value);
                  context.read<SettingsController>().setSort(_sort, ascending: value);
                  setSheetState(() {});
                },
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  _ascending ? 'Ascending' : 'Descending',
                  style: AppType.bodyMedium(context.colors.text),
                ),
                subtitle: Text(
                  'Applies to name, size, date and type',
                  style: AppType.bodySmall(context.colors.textMuted),
                ),
              ),
              const SizedBox(height: Insets.sm),
              DpPrimaryButton(
                label: 'Done',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _moreSheet() async {
    await showDpSheet<void>(
      context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SheetHeader(title: 'Folder actions', subtitle: 'Everything happens locally'),
          SheetAction(
            icon: Icons.create_new_folder_outlined,
            label: 'New folder',
            onTap: () {
              Navigator.of(context).pop();
              _createFolder();
            },
          ),
          SheetAction(
            icon: Icons.checklist_rounded,
            label: _selectionMode ? 'Select all' : 'Select items',
            description: 'Copy, move, encrypt or delete in bulk',
            onTap: () {
              Navigator.of(context).pop();
              if (_selectionMode) {
                _selectAll();
              } else {
                setState(() => _selectionMode = true);
              }
            },
          ),
          SheetAction(
            icon: _showHidden
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            label: _showHidden ? 'Hide hidden files' : 'Show hidden files',
            onTap: () {
              Navigator.of(context).pop();
              setState(() => _showHidden = !_showHidden);
            },
          ),
          if (_volume != null)
            SheetAction(
              icon: Icons.tune_rounded,
              label: 'Drive details',
              onTap: () {
                Navigator.of(context).pop();
                AppRoutes.driveDetails(context, _volume!);
              },
            ),
          SheetAction(
            icon: Icons.refresh_rounded,
            label: 'Refresh',
            onTap: () {
              Navigator.of(context).pop();
              _load();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _switchVolume() async {
    final List<Volume> volumes = _app.connectedVolumes;
    final Volume? chosen = await showDpSheet<Volume>(
      context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SheetHeader(title: 'Switch drive'),
          for (final Volume volume in volumes)
            SheetAction(
              icon: volume.isInternal ? Icons.smartphone_rounded : Icons.usb_rounded,
              label: volume.label,
              description:
                  '${volume.fileSystemLabel} • ${ByteFormat.format(volume.freeBytes)} free',
              onTap: () => Navigator.of(context).pop(volume),
            ),
        ],
      ),
    );
    if (chosen == null || !mounted) return;
    setState(() {
      _volume = chosen;
      _path = _app.rootFor(chosen);
      _summaries.clear();
      _selected.clear();
      _selectionMode = false;
      _query = '';
      _searchController.clear();
      _searchResults = null;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final double width = MediaQuery.sizeOf(context).width;

    return Scaffold(
      backgroundColor: c.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            _selectionMode ? _selectionHeader() : _header(),
            Padding(
              padding: const EdgeInsets.fromLTRB(Insets.screen, 0, Insets.screen, Insets.sm),
              child: DpSearchField(
                controller: _searchController,
                hint: 'Search ${_volume?.label ?? 'this drive'}',
                onChanged: _onQueryChanged,
                trailing: IconButton(
                  tooltip: 'Search this folder only',
                  icon: const Icon(Icons.tune_rounded, size: 18),
                  onPressed: _sortSheet,
                ),
              ),
            ),
            if (_query.length < 2) _breadcrumb(),
            Padding(
              padding: const EdgeInsets.fromLTRB(Insets.screen, 8, Insets.screen, 8),
              child: DpFilterBar<StorageCategory?>(
                options: _filterOptions(),
                selected: _filter,
                onSelected: (StorageCategory? value) => setState(() => _filter = value),
              ),
            ),
            Expanded(child: _body(width)),
          ],
        ),
      ),
      bottomNavigationBar: _selectionMode ? _selectionBar() : null,
    );
  }

  Widget _header() {
    return PageHeader(
      title: _volume?.label ?? 'Files',
      subtitle: '${_relativePath == 'Root' ? 'Root' : _relativePath} • ${_visibleEntries.length} items',
      showBack: true,
      padding: const EdgeInsets.fromLTRB(Insets.screen, Insets.sm, Insets.screen, Insets.sm),
      actions: <Widget>[
        HeaderAction(
          icon: _view == LibraryView.list
              ? Icons.grid_view_rounded
              : Icons.view_agenda_outlined,
          tooltip: _view == LibraryView.list ? 'Grid view' : 'List view',
          onTap: () {
            final LibraryView next =
                _view == LibraryView.list ? LibraryView.grid : LibraryView.list;
            setState(() => _view = next);
            context.read<SettingsController>().setView(next);
          },
        ),
        HeaderAction(
          icon: Icons.storage_rounded,
          tooltip: 'Switch drive',
          onTap: _switchVolume,
        ),
        HeaderAction(
          icon: Icons.more_horiz_rounded,
          tooltip: 'More',
          onTap: _moreSheet,
        ),
      ],
    );
  }

  Widget _selectionHeader() {
    final AppColors c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.screen, Insets.sm, Insets.screen, Insets.sm),
      child: Row(
        children: <Widget>[
          HeaderAction(
            icon: Icons.close_rounded,
            tooltip: 'Cancel selection',
            onTap: _clearSelection,
          ),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${_selected.length} selected',
                  style: AppType.headlineSmall(c.text).copyWith(fontSize: 17),
                ),
                Text(
                  _selected.length == 1 ? _selected.values.first.name : 'Bulk actions',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.bodySmall(c.textMuted),
                ),
              ],
            ),
          ),
          HeaderAction(
            icon: Icons.select_all_rounded,
            tooltip: 'Select all',
            onTap: _selectAll,
          ),
        ],
      ),
    );
  }

  Widget _breadcrumb() {
    final AppColors c = context.colors;
    final List<(String, String)> crumbs = _crumbs;
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Insets.screen),
        itemCount: crumbs.length,
        separatorBuilder: (_, _) => Icon(
          Icons.chevron_right_rounded,
          size: 15,
          color: c.textFaint,
        ),
        itemBuilder: (BuildContext context, int index) {
          final bool last = index == crumbs.length - 1;
          return Center(
            child: InkWell(
              onTap: last ? null : () => _navigate(crumbs[index].$2),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Text(
                  crumbs[index].$1,
                  style: AppType.bodySmall(last ? c.text : c.textMuted).copyWith(
                    fontSize: 12,
                    fontWeight: last ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  List<FilterOption<StorageCategory?>> _filterOptions() {
    final int total = _entries.where((FileEntry e) => !e.isDirectory).length;
    return <FilterOption<StorageCategory?>>[
      FilterOption<StorageCategory?>(value: null, label: 'All', count: total),
      for (final StorageCategory category in StorageCategory.values)
        if (category != StorageCategory.other)
          FilterOption<StorageCategory?>(
            value: category,
            label: category.label,
            count: _entries
                .where((FileEntry e) => !e.isDirectory && e.category == category)
                .length,
          ),
    ];
  }

  Widget _body(double width) {
    final AppColors c = context.colors;

    if (_loading) {
      return Center(
        child: SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(strokeWidth: 2.4, color: c.primary),
        ),
      );
    }

    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(Insets.screen),
        children: <Widget>[
          InfoBanner(
            message: _error!,
            tone: BannerTone.danger,
            icon: Icons.warning_amber_rounded,
            actionLabel: _errorCode == 'permission' ? 'Grant' : 'Retry',
            onAction: _errorCode == 'permission'
                ? () async {
                    await context.read<AppState>().storage.pickDirectory();
                    if (!mounted) return;
                    _load();
                  }
                : _load,
          ),
        ],
      );
    }

    if (_query.length >= 2 && _searching) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.2, color: c.primary),
            ),
            const SizedBox(height: Insets.md),
            Text(
              'Searching ${_volume?.label ?? 'drive'}…',
              style: AppType.bodySmall(c.textMuted),
            ),
          ],
        ),
      );
    }

    final List<FileEntry> folders = _folders;
    final List<FileEntry> files = _files;

    if (folders.isEmpty && files.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: <Widget>[
          const SizedBox(height: 30),
          EmptyState(
            icon: _query.isNotEmpty
                ? Icons.search_off_rounded
                : Icons.folder_open_rounded,
            title: _query.isNotEmpty ? 'No matches' : 'This folder is empty',
            message: _query.isNotEmpty
                ? 'No file or folder matches “$_query”.'
                : 'Copy files here from another drive, or create a folder to get started.',
            actionLabel: _query.isNotEmpty ? 'Clear search' : 'New folder',
            onAction: () {
              if (_query.isNotEmpty) {
                _searchController.clear();
                _onQueryChanged('');
              } else {
                _createFolder();
              }
            },
          ),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: c.primary,
      backgroundColor: c.surface,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(Insets.screen, 0, Insets.screen, Insets.xl),
        children: <Widget>[
          if (folders.isNotEmpty && _filter == null) ...<Widget>[
            SectionHeader(title: 'Folders', count: folders.length),
            for (final FileEntry folder in folders)
              Padding(
                padding: const EdgeInsets.only(bottom: Insets.sm),
                child: DpCard(
                  padding: const EdgeInsets.all(6),
                  onTap: () => _onEntryTap(folder),
                  onLongPress: () => _onEntryLongPress(folder),
                  borderColor: _isSelected(folder)
                      ? c.primary.withValues(alpha: 0.4)
                      : null,
                  color: _isSelected(folder) ? c.primarySoft : null,
                  child: FileRow(
                    entry: _enrich(folder),
                    onTap: () => _onEntryTap(folder),
                    onLongPress: () => _onEntryLongPress(folder),
                    selected: _isSelected(folder),
                    favorite: _app.isFavorite(folder.path),
                  ),
                ),
              ),
          ],
          if (files.isNotEmpty) ...<Widget>[
            SectionHeader(
              title: _query.length >= 2
                  ? 'Results'
                  : (_filter == null ? 'Files' : _filter!.plural),
              count: files.length,
              actionLabel: _query.length >= 2 ? null : 'By ${_sort.label}',
              actionIcon: Icons.swap_vert_rounded,
              onAction: _query.length >= 2 ? null : _sortSheet,
            ),
            if (_view == LibraryView.grid)
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: width >= 1000 ? 5 : (width >= 700 ? 4 : 2),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  mainAxisExtent: 132,
                ),
                itemCount: files.length,
                itemBuilder: (BuildContext context, int index) {
                  final FileEntry entry = files[index];
                  return FileGridTile(
                    entry: entry,
                    selected: _isSelected(entry),
                    favorite: _app.isFavorite(entry.path),
                    onTap: () => _onEntryTap(entry),
                    onLongPress: () => _onEntryLongPress(entry),
                  );
                },
              )
            else
              DpCard(
                clip: true,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Column(
                  children: <Widget>[
                    for (int i = 0; i < files.length; i++) ...<Widget>[
                      if (_query.length >= 2)
                        FileRow(
                          entry: files[i],
                          subtitle:
                              '${ByteFormat.format(files[i].sizeBytes)} • ${DateX.relative(files[i].modifiedAt)} • ${_relativeLabelFor(files[i])}',
                          selected: _isSelected(files[i]),
                          favorite: _app.isFavorite(files[i].path),
                          onTap: () => _onEntryTap(files[i]),
                          onLongPress: () => _onEntryLongPress(files[i]),
                          trailing: Icon(
                            Icons.more_vert_rounded,
                            size: 18,
                            color: c.textFaint,
                          ),
                        )
                      else
                        FileRow(
                          entry: files[i],
                          selected: _isSelected(files[i]),
                          favorite: _app.isFavorite(files[i].path),
                          onTap: () => _onEntryTap(files[i]),
                          onLongPress: () => _onEntryLongPress(files[i]),
                          trailing: Icon(
                            Icons.more_vert_rounded,
                            size: 18,
                            color: c.textFaint,
                          ),
                        ),
                      if (i != files.length - 1)
                        Divider(height: 1, color: c.border.withValues(alpha: 0.6)),
                    ],
                  ],
                ),
              ),
          ],
          const SizedBox(height: Insets.lg),
          Center(
            child: Text(
              'Showing ${_visibleEntries.length} of ${_entries.length} items • ${ByteFormat.format(_volume?.freeBytes ?? 0)} free',
              style: AppType.labelCaps(c.textFaint).copyWith(fontSize: 9.5),
            ),
          ),
        ],
      ),
    );
  }

  String _relativeLabelFor(FileEntry entry) {
    final String path = entry.parentPath;
    if (path == _root) return _volume?.label ?? 'Root';
    final String prefix = '$_root/';
    final String rel = path.startsWith(prefix) ? path.substring(prefix.length) : path;
    return rel.isEmpty ? (_volume?.label ?? 'Root') : rel;
  }

  Widget _selectionBar() {
    final AppColors c = context.colors;
    final bool hasFiles =
        _selected.values.any((FileEntry e) => !e.isDirectory);
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.border)),
        boxShadow: <BoxShadow>[
          BoxShadow(color: c.shadow, blurRadius: 18, offset: const Offset(0, -6)),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(Insets.md, Insets.sm, Insets.md, Insets.sm),
      child: SafeArea(
        top: false,
        child: Row(
          children: <Widget>[
            _SelectionAction(
              icon: Icons.copy_all_rounded,
              label: 'Copy',
              onTap: () => _copyMove(_selected.values.toList(), move: false),
            ),
            _SelectionAction(
              icon: Icons.drive_file_move_outline,
              label: 'Move',
              onTap: () => _copyMove(_selected.values.toList(), move: true),
            ),
            _SelectionAction(
              icon: Icons.lock_outline_rounded,
              label: 'Encrypt',
              enabled: hasFiles,
              onTap: () => _encrypt(_selected.values.toList()),
            ),
            _SelectionAction(
              icon: Icons.delete_outline_rounded,
              label: 'Delete',
              destructive: true,
              onTap: () => _deleteEntries(_selected.values.toList()),
            ),
            _SelectionAction(
              icon: Icons.more_horiz_rounded,
              label: 'More',
              onTap: () async {
                if (_selected.length == 1) {
                  await _showDetails(_selected.values.first);
                } else {
                  await _sortSheet();
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectionAction extends StatelessWidget {
  const _SelectionAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final Color color = !enabled
        ? c.textFaint
        : (destructive ? c.danger : c.text);
    return Expanded(
      child: InkResponse(
        onTap: enabled ? onTap : null,
        radius: 32,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 20, color: color),
              const SizedBox(height: 3),
              Text(
                label,
                style: AppType.labelCaps(color).copyWith(fontSize: 9),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: AppType.bodySmall(c.textMuted).copyWith(fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppType.monoSmall(c.text).copyWith(fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

enum _FileAction { open, share, favorite, rename, copy, move, encrypt, delete }
