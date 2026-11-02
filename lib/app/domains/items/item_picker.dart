/// The labelled single-choice picker the items pages use for categories,
/// rarities, enum custom fields and the list filters.
///
/// A [DropdownButton] in an [InputDecorator], never a `DropdownMenu`,
/// whose text field would take Ctrl+Z (design §8.7). `MetaPicker` in the
/// project settings has the same shape but needs its value among the
/// options and shows no error text; this one allows neither restriction.
library;

import 'package:flutter/material.dart';

/// One option: the stored value and its label.
typedef PickerOption<T> = ({T value, String label});

class ItemPicker<T> extends StatelessWidget {
  const ItemPicker({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.isRequired = false,
    this.errorText,
    this.helperText,
    this.unknownLabel,
    this.isDense = false,
  });

  final String label;

  /// The current value. One not among [options] is shown as an extra
  /// option labelled by [unknownLabel] (the raw value by default), so a
  /// record pointing at a deleted row still renders.
  final T value;
  final List<PickerOption<T>> options;
  final ValueChanged<T>? onChanged;

  /// Adds 0.1.6's ` *` to the label.
  final bool isRequired;
  final String? errorText;
  final String? helperText;
  final String Function(T value)? unknownLabel;
  final bool isDense;

  @override
  Widget build(BuildContext context) {
    final known = options.any((o) => o.value == value);
    final all = [
      ...options,
      if (!known && value != null)
        (value: value, label: unknownLabel?.call(value) ?? '$value'),
    ];
    final onChanged = this.onChanged;
    return InputDecorator(
      decoration: InputDecoration(
        labelText: isRequired ? '$label *' : label,
        errorText: errorText,
        helperText: helperText,
        isDense: isDense,
        enabled: onChanged != null,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isDense: true,
          isExpanded: true,
          items: [
            for (final option in all)
              DropdownMenuItem<T>(
                value: option.value,
                child: Text(option.label, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: onChanged == null
              ? null
              : (v) {
                  if (v is T) onChanged(v);
                },
        ),
      ),
    );
  }
}
