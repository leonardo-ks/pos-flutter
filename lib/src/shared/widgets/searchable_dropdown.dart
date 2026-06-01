import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class DropdownChoice<T> {
  const DropdownChoice({required this.value, required this.label});

  final T value;
  final String label;
}

class SearchableDropdown<T> extends StatelessWidget {
  const SearchableDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.choices,
    required this.onChanged,
    this.prefixIcon,
    this.enabled = true,
  });

  final String label;
  final T value;
  final List<DropdownChoice<T>> choices;
  final ValueChanged<T>? onChanged;
  final IconData? prefixIcon;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final selectedLabel = choices
        .where((choice) => choice.value == value)
        .map((choice) => choice.label)
        .firstOrNull;

    return InkWell(
      borderRadius: AppRadius.card,
      onTap: enabled && onChanged != null
          ? () async {
              final selected = await _showPicker(context);
              if (selected != null) onChanged!(selected.value);
            }
          : null,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
          suffixIcon: const Icon(Icons.arrow_drop_down),
          enabled: enabled && onChanged != null,
        ),
        child: Text(
          selectedLabel ?? '-',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Future<_DropdownSelection<T>?> _showPicker(BuildContext context) {
    return showDialog<_DropdownSelection<T>>(
      context: context,
      builder: (dialogContext) => _SearchableDropdownDialog<T>(
        title: label,
        choices: choices,
        value: value,
      ),
    );
  }
}

class _SearchableDropdownDialog<T> extends StatefulWidget {
  const _SearchableDropdownDialog({
    required this.title,
    required this.choices,
    required this.value,
  });

  final String title;
  final List<DropdownChoice<T>> choices;
  final T value;

  @override
  State<_SearchableDropdownDialog<T>> createState() =>
      _SearchableDropdownDialogState<T>();
}

class _SearchableDropdownDialogState<T>
    extends State<_SearchableDropdownDialog<T>> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.choices
        .where(
          (choice) =>
              _query.isEmpty ||
              choice.label.toLowerCase().contains(_query.toLowerCase()),
        )
        .toList(growable: false);
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        height: 420,
        child: Column(
          children: [
            TextField(
              controller: _search,
              autofocus: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                labelText: 'Cari',
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('Data Tidak Ditemukan.'))
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final choice = filtered[index];
                        final selected = choice.value == widget.value;
                        return ListTile(
                          selected: selected,
                          leading: selected ? const Icon(Icons.check) : null,
                          title: Text(choice.label),
                          onTap: () => Navigator.of(
                            context,
                          ).pop(_DropdownSelection(choice.value)),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
      ],
    );
  }
}

class _DropdownSelection<T> {
  const _DropdownSelection(this.value);

  final T value;
}
