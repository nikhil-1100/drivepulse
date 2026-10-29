import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_type.dart';
import '../../core/utils/byte_format.dart';
import '../../core/utils/date_x.dart';
import '../../core/widgets/dialogs.dart';
import '../../core/widgets/dp_card.dart';
import '../../core/widgets/dp_pill.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/file_row.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/sheets.dart';
import '../../data/models/file_entry.dart';
import '../../data/models/volume.dart';
import '../../data/state/app_state.dart';

/// Local encryption vault. Everything happens in-process: read file → AES-GCM →
/// write `.dpv` → delete the original. The passphrase is never persisted.
class VaultScreen extends StatefulWidget {
  const VaultScreen({super.key, this.volume});

  final Volume? volume;

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> {
  Volume? _volume;
  List<FileEntry> _vaultFiles = <FileEntry>[];
  bool _loading = true;
  String? _error;

  AppState get _app => context.read<AppState>();

  @override
  void initState() {
    super.initState();
    _volume = widget.volume ?? context.read<AppState>().currentVolume;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final Volume? volume = _volume;
    if (volume == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final String root = _app.rootFor(volume);
      final List<FileEntry> files = <FileEntry>[];
      final List<FileEntry> roots = await _app.listDirectory(root);
      for (final FileEntry entry in roots) {
        if (!entry.isDirectory && _isVault(entry)) files.add(entry);
      }
      for (final FileEntry folder in roots.where((FileEntry e) => e.isDirectory).take(5)) {
        try {
          final List<FileEntry> children = await _app.listDirectory(folder.path);
          files.addAll(children.where(_isVault));
        } catch (_) {
          continue;
        }
      }
      if (!mounted) return;
      setState(() {
        _vaultFiles = files;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '$error';
        _loading = false;
      });
    }
  }

  bool _isVault(FileEntry entry) =>
      !entry.isDirectory && entry.name.toLowerCase().endsWith('.dpv');

  Future<void> _pickAndEncrypt() async {
    final Volume? volume = _volume;
    if (volume == null) return;
    final List<FileEntry> candidates = <FileEntry>[];
    try {
      final List<FileEntry> roots = await _app.listDirectory(_app.rootFor(volume));
      for (final FileEntry entry in roots) {
        if (!entry.isDirectory) {
          if (!_isVault(entry)) candidates.add(entry);
        } else {
          try {
            final List<FileEntry> children = await _app.listDirectory(entry.path);
            candidates.addAll(
              children.where((FileEntry e) => !e.isDirectory && !_isVault(e)),
            );
          } catch (_) {
            continue;
          }
        }
      }
    } catch (error) {
      if (!mounted) return;
      showAppToast(context, '$error');
      return;
    }
    if (!mounted) return;
    if (candidates.isEmpty) {
      showAppToast(context, 'No files found to encrypt on this drive.');
      return;
    }

    final List<FileEntry>? chosen = await showDpSheet<List<FileEntry>>(
      context,
      child: _FilePicker(
        files: candidates.take(120).toList(growable: false),
        rootPath: _app.rootFor(volume),
      ),
    );
    if (chosen == null || chosen.isEmpty || !mounted) return;
    final String? passphrase = await showPassphrasePrompt(
      context,
      title: 'Encrypt ${chosen.length} file${chosen.length == 1 ? '' : 's'}',
      message:
          'AES-256-GCM, PBKDF2-HMAC-SHA256 with 120,000 rounds. The original file is '
          'replaced by a .dpv container. There is no recovery if you forget the '
          'passphrase.',
      confirmTwice: true,
      confirmLabel: 'Encrypt',
    );
    if (passphrase == null || !mounted) return;
    try {
      final int count = await _app.encryptFiles(
        entries: chosen,
        password: passphrase,
        volume: volume,
      );
      if (!mounted) return;
      showAppToast(context, '$count file${count == 1 ? '' : 's'} encrypted');
      await _load();
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

  Future<void> _decrypt(FileEntry entry) async {
    final Volume? volume = _volume;
    if (volume == null) return;
    final String name = entry.name.substring(0, entry.name.length - 4);
    final String? passphrase = await showPassphrasePrompt(
      context,
      title: 'Decrypt “$name”',
      message: 'Enter the passphrase used when this file was encrypted.',
      confirmLabel: 'Decrypt',
    );
    if (passphrase == null || !mounted) return;
    try {
      final FileEntry restored = await _app.decryptEntry(
        entry: entry,
        password: passphrase,
        volume: volume,
      );
      if (!mounted) return;
      showAppToast(context, '“${restored.name}” restored');
      await _load();
    } catch (error) {
      if (!mounted) return;
      showAppToast(
        context,
        '$error',
        icon: Icons.lock_outline_rounded,
        iconColor: context.colors.danger,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final Volume? volume = _volume;

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
                    title: 'Vault',
                    subtitle: volume == null ? 'No drive selected' : volume.label,
                    showBack: true,
                    padding: const EdgeInsets.fromLTRB(0, Insets.md, 0, Insets.md),
                    actions: <Widget>[
                      HeaderAction(
                        icon: Icons.refresh_rounded,
                        tooltip: 'Rescan for encrypted files',
                        onTap: _loading ? () {} : _load,
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(Insets.lg),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[Color(0xFF141414), Color(0xFF0A0A0A)],
                      ),
                      borderRadius: BorderRadius.circular(Radii.lg),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: const Icon(Icons.lock_outline_rounded,
                                  color: Colors.white, size: 20),
                            ),
                            const SizedBox(width: Insets.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    'On-device encryption',
                                    style: AppType.headlineSmall(Colors.white)
                                        .copyWith(fontSize: 15),
                                  ),
                                  Text(
                                    'AES-256-GCM • PBKDF2 120k rounds',
                                    style: AppType.labelCaps(
                                      Colors.white.withValues(alpha: 0.55),
                                    ).copyWith(fontSize: 9),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: c.success.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(Radii.pill),
                                border: Border.all(
                                  color: c.success.withValues(alpha: 0.4),
                                ),
                              ),
                              child: Text(
                                'KEYS NEVER STORED',
                                style: AppType.labelCaps(c.success)
                                    .copyWith(fontSize: 8),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: Insets.md),
                        Text(
                          'Encrypted files are written as .dpv containers next to their '
                          'originals, which are removed only after the encrypted copy is '
                          'written. Losing the passphrase means losing the file — that is '
                          'the trade-off for zero recovery backdoors.',
                          style: AppType.bodySmall(
                            Colors.white.withValues(alpha: 0.62),
                          ).copyWith(height: 1.5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Insets.lg),
                  DpPrimaryButton(
                    label: 'Encrypt files on this drive',
                    icon: Icons.lock_rounded,
                    onPressed: volume == null ? null : _pickAndEncrypt,
                  ),
                  const SizedBox(height: Insets.xl),
                  SectionHeader(
                    title: 'Encrypted files',
                    count: _vaultFiles.length,
                    actionLabel: _vaultFiles.isEmpty ? null : 'Rescan',
                    onAction: _load,
                  ),
                  if (volume == null)
                    const DpCard(
                      child: EmptyState(
                        icon: Icons.usb_off_rounded,
                        title: 'No drive selected',
                        message: 'Connect a drive and open Vault again.',
                        compact: true,
                      ),
                    )
                  else if (_loading)
                    const Padding(
                      padding: EdgeInsets.all(Insets.xl),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_error != null)
                    InfoBanner(
                      message: _error!,
                      tone: BannerTone.danger,
                      actionLabel: 'Retry',
                      onAction: _load,
                    )
                  else if (_vaultFiles.isEmpty)
                    DpCard(
                      padding: const EdgeInsets.all(Insets.md),
                      child: EmptyState(
                        icon: Icons.enhanced_encryption_outlined,
                        title: 'No encrypted files found',
                        message:
                            'Files ending in .dpv on this drive appear here. Use Encrypt '
                            'files, or the Encrypt action in the file browser.',
                        actionLabel: 'Browse files',
                        onAction: () => Navigator.of(context).maybePop(),
                        compact: true,
                      ),
                    )
                  else
                    DpCard(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Column(
                        children: <Widget>[
                          for (final FileEntry file in _vaultFiles)
                            FileRow(
                              entry: file,
                              trailing: const DpPill(
                                label: 'AES',
                                tone: PillTone.success,
                                dense: true,
                                monospace: true,
                              ),
                              subtitle:
                                  '${ByteFormat.format(file.sizeBytes)} • ${DateX.fileStamp(file.modifiedAt)}',
                              onTap: () => _decrypt(file),
                            ),
                        ],
                      ),
                    ),
                  const SizedBox(height: Insets.lg),
                  const InfoBanner(
                    message:
                        'Encryption runs on the CPU of this device. Very large files are '
                        'loaded into memory, so prefer encrypting in batches under 64 MB on '
                        'low-RAM phones.',
                    tone: BannerTone.neutral,
                    icon: Icons.info_outline_rounded,
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

class _FilePicker extends StatefulWidget {
  const _FilePicker({required this.files, required this.rootPath});

  final List<FileEntry> files;
  final String rootPath;

  @override
  State<_FilePicker> createState() => _FilePickerState();
}

class _FilePickerState extends State<_FilePicker> {
  final Set<String> _selected = <String>{};

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SheetHeader(
          title: 'Select files',
          subtitle: '${_selected.length} of ${widget.files.length} selected',
        ),
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: widget.files.length,
            itemBuilder: (BuildContext context, int index) {
              final FileEntry file = widget.files[index];
              final bool checked = _selected.contains(file.path);
              return CheckboxListTile(
                value: checked,
                onChanged: (bool? value) {
                  setState(() {
                    if (value == true) {
                      _selected.add(file.path);
                    } else {
                      _selected.remove(file.path);
                    }
                  });
                },
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(
                  file.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.bodyMedium(c.text).copyWith(fontSize: 13),
                ),
                subtitle: Text(
                  '${ByteFormat.format(file.sizeBytes)} • ${file.parentPath}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.bodySmall(c.textFaint).copyWith(fontSize: 10.5),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: Insets.sm),
        DpPrimaryButton(
          label: _selected.isEmpty ? 'Select files' : 'Encrypt ${_selected.length} files',
          icon: Icons.lock_rounded,
          onPressed: _selected.isEmpty
              ? null
              : () => Navigator.of(context).pop(
                    widget.files
                        .where((FileEntry f) => _selected.contains(f.path))
                        .toList(growable: false),
                  ),
        ),
      ],
    );
  }
}
