import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routing.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_type.dart';
import '../../core/utils/date_x.dart';
import '../../core/widgets/dialogs.dart';
import '../../core/widgets/dp_card.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/file_row.dart';
import '../../core/widgets/page_header.dart';
import '../../data/models/file_entry.dart';
import '../../data/models/volume.dart';
import '../../data/services/settings_store.dart';
import '../../data/services/storage_service.dart';
import '../../data/state/app_state.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key, this.volume});

  final Volume? volume;

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<FileEntry> _entries = <FileEntry>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final AppState app = context.read<AppState>();
    final List<String> paths = app.settings.favorites;
    final List<FileEntry> entries = <FileEntry>[];
    for (final String path in paths) {
      try {
        final FileEntry? entry = await app.storage.stat(path);
        if (entry != null) entries.add(entry);
      } on StorageException {
        continue;
      }
    }
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _loading = false;
    });
  }

  Future<void> _remove(FileEntry entry) async {
    await context.read<SettingsController>().toggleFavorite(entry.path);
    if (!mounted) return;
    showAppToast(context, 'Removed from favourites');
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final Volume? volume = widget.volume ?? context.watch<AppState>().currentVolume;

    return Scaffold(
      backgroundColor: c.canvas,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            ScreenBody(
              maxWidth: 760,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  PageHeader(
                    title: 'Favourites',
                    subtitle: '${_entries.length} pinned items',
                    showBack: true,
                    padding: const EdgeInsets.fromLTRB(0, Insets.md, 0, Insets.md),
                    actions: <Widget>[
                      HeaderAction(
                        icon: Icons.refresh_rounded,
                        tooltip: 'Refresh',
                        onTap: _load,
                      ),
                    ],
                  ),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.all(Insets.xl),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_entries.isEmpty)
                    DpCard(
                      child: EmptyState(
                        icon: Icons.star_outline_rounded,
                        title: 'No favourites yet',
                        message:
                            'Long-press a file or folder in the browser and choose Add to '
                            'favourites to pin it here.',
                        actionLabel: 'Browse files',
                        onAction: () => AppRoutes.browse(context, volume: volume),
                      ),
                    )
                  else
                    DpCard(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Column(
                        children: <Widget>[
                          for (int i = 0; i < _entries.length; i++) ...<Widget>[
                            FileRow(
                              entry: _entries[i],
                              favorite: true,
                              subtitle:
                                  '${fileMetaLine(_entries[i])} • ${DateX.relative(_entries[i].modifiedAt)}',
                              onTap: () => AppRoutes.browse(
                                context,
                                volume: volume,
                                path: _entries[i].isDirectory
                                    ? _entries[i].path
                                    : _entries[i].parentPath,
                              ),
                              trailing: IconButton(
                                onPressed: () => _remove(_entries[i]),
                                tooltip: 'Remove favourite',
                                icon: const Icon(Icons.star_rounded, size: 18),
                                color: c.primary,
                                visualDensity: VisualDensity.compact,
                                constraints:
                                    const BoxConstraints(minWidth: 32, minHeight: 32),
                                padding: EdgeInsets.zero,
                              ),
                            ),
                            if (i != _entries.length - 1)
                              Divider(
                                height: 1,
                                color: c.border.withValues(alpha: 0.6),
                              ),
                          ],
                        ],
                      ),
                    ),
                  const SizedBox(height: Insets.lg),
                  Text(
                    'Favourite paths are stored in local preferences only. If a drive is '
                    'ejected, its favourites stay listed and reconnect when the volume is '
                    'mounted again.',
                    style: AppType.bodySmall(c.textFaint)
                        .copyWith(fontSize: 10.5, height: 1.5),
                  ),
                  const SizedBox(height: Insets.xxl),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
