import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_type.dart';

class FilterOption<T> {
  const FilterOption({required this.value, required this.label, this.count});

  final T value;
  final String label;
  final int? count;
}

/// Horizontally scrolling filter pills with counts, matching
/// `All (32) Images (14) Videos (6)`.
class DpFilterBar<T> extends StatelessWidget {
  const DpFilterBar({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.padding = EdgeInsets.zero,
    this.showCounts = true,
  });

  final List<FilterOption<T>> options;
  final T selected;
  final ValueChanged<T> onSelected;
  final EdgeInsetsGeometry padding;
  final bool showCounts;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: padding,
        itemCount: options.length,
        separatorBuilder: (_, _) => const SizedBox(width: Insets.sm),
        itemBuilder: (BuildContext context, int index) {
          final FilterOption<T> option = options[index];
          final bool active = option.value == selected;
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => onSelected(option.value),
              borderRadius: BorderRadius.circular(Radii.pill),
              child: AnimatedContainer(
                duration: DpDurations.fast,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active ? c.primary : c.surface,
                  borderRadius: BorderRadius.circular(Radii.pill),
                  border: Border.all(color: active ? c.primary : c.border),
                ),
                child: Text(
                  showCounts && option.count != null
                      ? '${option.label} (${option.count})'
                      : option.label,
                  style: AppType.bodySmall(
                    active ? c.onPrimary : c.textMuted,
                  ).copyWith(
                    fontSize: 12,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Soft search field used above file lists and in the global search screen.
class DpSearchField extends StatelessWidget {
  const DpSearchField({
    super.key,
    required this.controller,
    this.hint = 'Search files and folders',
    this.onChanged,
    this.onCleared,
    this.autofocus = false,
    this.onSubmitted,
    this.trailing,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onCleared;
  final bool autofocus;
  final ValueChanged<String>? onSubmitted;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (BuildContext context, TextEditingValue value, _) {
        return TextField(
          controller: controller,
          autofocus: autofocus,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          textInputAction: TextInputAction.search,
          style: AppType.bodyMedium(c.text),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            suffixIcon: value.text.isEmpty
                ? trailing
                : IconButton(
                    tooltip: 'Clear search',
                    onPressed: () {
                      controller.clear();
                      onChanged?.call('');
                      onCleared?.call();
                    },
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
            filled: true,
            fillColor: c.surface,
            contentPadding: const EdgeInsets.symmetric(vertical: 13),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Radii.pill),
              borderSide: BorderSide(color: c.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Radii.pill),
              borderSide: BorderSide(color: c.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Radii.pill),
              borderSide: BorderSide(color: c.text, width: 1.4),
            ),
          ),
        );
      },
    );
  }
}
