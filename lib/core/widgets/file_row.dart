import 'package:flutter/material.dart';

import '../../data/models/file_entry.dart';
import '../theme/app_colors.dart';
import '../utils/file_kind.dart';
import '../theme/app_type.dart';
import '../utils/byte_format.dart';
import '../utils/date_x.dart';
import 'dp_card.dart';

/// Extension chip that leads every file row: tinted square, glyph and the
/// uppercased extension in monospace.
class FileTypeChip extends StatelessWidget {
  const FileTypeChip({super.key, required this.entry, this.size = 44});

  final FileEntry entry;
  final double size;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final Color tint = entry.isDirectory ? c.textMuted : entry.kind.tint(c);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: c.isDark ? 0.18 : 0.1),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: tint.withValues(alpha: 0.2)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(entry.kind.icon, size: size * 0.42, color: tint),
          const SizedBox(height: 1),
          Text(
            entry.chipLabel,
            style: AppType.labelCaps(tint).copyWith(
              fontSize: size * 0.17,
              letterSpacing: 0.2,
              height: 1.05,
            ),
          ),
        ],
      ),
    );
  }
}

/// Metadata line: `24 items • 4.8 GB` for folders, `42.4 MB • Today, 2:15 PM`
/// for files.
String fileMetaLine(FileEntry entry, {DateTime? now}) {
  if (entry.isDirectory) {
    final String items = entry.childCount == null
        ? 'Folder'
        : '${entry.childCount} ${entry.childCount == 1 ? 'item' : 'items'}';
    if (entry.folderBytes != null && entry.folderBytes! > 0) {
      return '$items • ${ByteFormat.format(entry.folderBytes!)}';
    }
    return items;
  }
  return '${ByteFormat.format(entry.sizeBytes)} • ${DateX.fileStamp(entry.modifiedAt, now: now)}';
}

class FileRow extends StatelessWidget {
  const FileRow({
    super.key,
    required this.entry,
    this.onTap,
    this.onLongPress,
    this.trailing,
    this.selected = false,
    this.showChevron = true,
    this.subtitle,
    this.padding = const EdgeInsets.symmetric(
      horizontal: Insets.md,
      vertical: Insets.sm,
    ),
    this.favorite = false,
  });

  final FileEntry entry;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget? trailing;
  final bool selected;
  final bool showChevron;
  final String? subtitle;
  final EdgeInsetsGeometry padding;
  final bool favorite;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(Radii.md),
        child: Ink(
          decoration: BoxDecoration(
            color: selected ? c.primarySoft : Colors.transparent,
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border.all(
              color: selected ? c.primary.withValues(alpha: 0.4) : Colors.transparent,
            ),
          ),
          child: Padding(
            padding: padding,
            child: Row(
              children: <Widget>[
                FileTypeChip(entry: entry),
                const SizedBox(width: Insets.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Flexible(
                            child: Text(
                              entry.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppType.bodyMedium(c.text).copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: 14.5,
                              ),
                            ),
                          ),
                          if (favorite) ...<Widget>[
                            const SizedBox(width: 5),
                            Icon(Icons.star_rounded, size: 13, color: c.primary),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle ?? fileMetaLine(entry),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.monoSmall(c.textFaint).copyWith(fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
                if (trailing != null)
                  trailing!
                else if (selected)
                  Icon(Icons.check_circle_rounded, size: 20, color: c.primary)
                else if (showChevron)
                  Icon(Icons.chevron_right_rounded, size: 20, color: c.textFaint),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Grid counterpart for the view toggle.
class FileGridTile extends StatelessWidget {
  const FileGridTile({
    super.key,
    required this.entry,
    this.onTap,
    this.onLongPress,
    this.selected = false,
    this.favorite = false,
  });

  final FileEntry entry;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool selected;
  final bool favorite;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return DpCard(
      padding: const EdgeInsets.all(Insets.md),
      onTap: onTap,
      onLongPress: onLongPress,
      color: selected ? c.primarySoft : null,
      borderColor: selected ? c.primary.withValues(alpha: 0.4) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              FileTypeChip(entry: entry, size: 38),
              const Spacer(),
              if (selected)
                Icon(Icons.check_circle_rounded, size: 18, color: c.primary)
              else if (favorite)
                Icon(Icons.star_rounded, size: 15, color: c.primary)
              else
                Icon(
                  entry.isDirectory
                      ? Icons.folder_open_rounded
                      : Icons.more_horiz_rounded,
                  size: 16,
                  color: c.textFaint,
                ),
            ],
          ),
          const Spacer(),
          Text(
            entry.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppType.bodyMedium(c.text).copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            fileMetaLine(entry),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppType.monoSmall(c.textFaint).copyWith(fontSize: 10.5),
          ),
        ],
      ),
    );
  }
}
