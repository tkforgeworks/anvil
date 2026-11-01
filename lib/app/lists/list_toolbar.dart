import 'package:flutter/material.dart';

import '../theme/anvil_metrics.dart';
import 'list_columns.dart';

/// The one-row toolbar above every list (0.1.6 `ListToolbar.tsx`): search,
/// the page's [filterSlot], the Sort by picker, the Active/Archived toggle
/// and the New button, hidden in the archived view or with [onNew] null.
///
/// The sort picker is a [DropdownButton], never a `DropdownMenu`, whose
/// text field would take Ctrl+Z (design §8.7).
class ListToolbar extends StatefulWidget {
  const ListToolbar({
    super.key,
    required this.search,
    required this.onSearchChanged,
    required this.sortLabels,
    required this.sortLabel,
    required this.onSortChanged,
    required this.mode,
    required this.onModeChanged,
    required this.newLabel,
    this.onNew,
    this.filterSlot,
  });

  static const searchKey = ValueKey('list-toolbar-search');
  static const sortKey = ValueKey('list-toolbar-sort');
  static const modeKey = ValueKey('list-toolbar-mode');
  static const newKey = ValueKey('list-toolbar-new');

  /// 0.1.6's `sx={{ width: 220 }}` and `160` on the search and sort fields.
  static const searchWidth = 220.0;
  static const sortWidth = 160.0;

  final String search;
  final ValueChanged<String> onSearchChanged;
  final List<String> sortLabels;
  final String sortLabel;
  final ValueChanged<String> onSortChanged;
  final ListViewMode mode;
  final ValueChanged<ListViewMode> onModeChanged;
  final String newLabel;
  final VoidCallback? onNew;

  /// The page's own filters, between search and sort.
  final Widget? filterSlot;

  @override
  State<ListToolbar> createState() => _ListToolbarState();
}

class _ListToolbarState extends State<ListToolbar> {
  late final _search = TextEditingController(text: widget.search);

  @override
  void didUpdateWidget(ListToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.search != _search.text) _search.text = widget.search;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final search = SizedBox(
      width: ListToolbar.searchWidth,
      child: TextField(
        key: ListToolbar.searchKey,
        controller: _search,
        onChanged: widget.onSearchChanged,
        decoration: const InputDecoration(
          hintText: 'Search...',
          prefixIcon: Icon(Icons.search, size: 20),
          isDense: true,
        ),
      ),
    );
    // The search, filters and sort wrap onto a second line when the page
    // is too narrow for one (two filter pickers at the 1400 px minimum
    // window with the sidebar open); the view toggle and New stay on the
    // first line at the right.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Wrap(
            spacing: AnvilSpacing.md,
            runSpacing: AnvilSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [search, ?widget.filterSlot, _sortPicker()],
          ),
        ),
        const SizedBox(width: AnvilSpacing.md),
        SegmentedButton<ListViewMode>(
          key: ListToolbar.modeKey,
          showSelectedIcon: false,
          segments: [
            for (final mode in ListViewMode.values)
              ButtonSegment(value: mode, label: Text(mode.label)),
          ],
          selected: {widget.mode},
          onSelectionChanged: (s) => widget.onModeChanged(s.single),
        ),
        if (widget.mode == ListViewMode.active && widget.onNew != null) ...[
          const SizedBox(width: AnvilSpacing.md),
          FilledButton(
            key: ListToolbar.newKey,
            onPressed: widget.onNew,
            child: Text(widget.newLabel),
          ),
        ],
      ],
    );
  }

  Widget _sortPicker() => SizedBox(
    width: ListToolbar.sortWidth,
    child: InputDecorator(
      decoration: const InputDecoration(labelText: 'Sort by', isDense: true),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          key: ListToolbar.sortKey,
          value: widget.sortLabel,
          isDense: true,
          isExpanded: true,
          items: [
            for (final label in widget.sortLabels)
              DropdownMenuItem(value: label, child: Text(label)),
          ],
          onChanged: (label) {
            if (label != null) widget.onSortChanged(label);
          },
        ),
      ),
    ),
  );
}
