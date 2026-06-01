import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_scope.dart';
import '../formatters.dart';
import '../models/feature_record.dart';
import 'debounced_text_field.dart';
import 'empty_state.dart';
import 'searchable_dropdown.dart';

class FeatureField {
  const FeatureField(
    this.key,
    this.label, {
    this.numeric = false,
    this.options,
    this.referencePath,
    this.referenceValueKey,
    this.referenceLabelKeys = const ['nama', 'nama_produk'],
    this.phone = false,
  });

  final String key;
  final String label;
  final bool numeric;
  final List<FeatureOption>? options;
  final String? referencePath;
  final String? referenceValueKey;
  final List<String> referenceLabelKeys;
  final bool phone;
}

class FeatureOption {
  const FeatureOption(this.value, this.label);

  final String value;
  final String label;
}

class FeatureTableScreen extends StatefulWidget {
  const FeatureTableScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.path,
    required this.fields,
    this.labelKeys = const ['nama', 'category', 'description'],
    this.summaryKeys,
    this.createTemplate,
    this.canCreate = true,
    this.showHeader = true,
    this.permissionSection,
  });

  final String title;
  final String subtitle;
  final String path;
  final List<FeatureField> fields;
  final List<String> labelKeys;
  final List<String>? summaryKeys;
  final Map<String, Object?>? createTemplate;
  final bool canCreate;
  final bool showHeader;
  final String? permissionSection;

  @override
  State<FeatureTableScreen> createState() => _FeatureTableScreenState();
}

class _FeatureTableScreenState extends State<FeatureTableScreen> {
  bool _loaded = false;
  final TextEditingController _filterController = TextEditingController();
  String _filter = '';

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loaded = true;
      final controller = AppScope.of(context);
      Future.microtask(() async {
        await controller.loadFeatureRecords(widget.path);
        for (final field in widget.fields) {
          final referencePath = field.referencePath;
          if (referencePath != null) {
            await controller.loadFeatureRecords(referencePath);
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final records = controller.featureRecords(widget.path);
    final query = _filter.trim().isEmpty ? null : {'q': _filter.trim()};
    final permissionSection =
        widget.permissionSection ?? _permissionSectionForPath(widget.path);
    final canCreate =
        widget.canCreate && controller.canCreateMenu(permissionSection);
    final canUpdate = controller.canUpdateMenu(permissionSection);
    final canDelete = controller.canDeleteMenu(permissionSection);

    return Column(
      children: [
        if (widget.showHeader && canCreate)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: controller.isBusy ? null : () => _openForm(context),
                icon: const Icon(Icons.add),
                label: const Text('Tambah'),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: DebouncedTextField(
                  controller: _filterController,
                  onChanged: (value) {
                    setState(() => _filter = value);
                    controller.loadFeatureRecords(
                      widget.path,
                      query: value.trim().isEmpty ? null : {'q': value.trim()},
                      force: true,
                    );
                  },
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'Cari ${widget.title}',
                    suffixIcon: _filter.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Bersihkan',
                            onPressed: () {
                              _filterController.clear();
                              setState(() => _filter = '');
                              controller.loadFeatureRecords(
                                widget.path,
                                force: true,
                              );
                            },
                            icon: const Icon(Icons.close),
                          ),
                  ),
                ),
              ),
              if (!widget.showHeader && canCreate) ...[
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: controller.isBusy
                      ? null
                      : () => _openForm(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Tambah'),
                ),
              ],
            ],
          ),
        ),
        if (controller.errorMessage != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              controller.errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        Expanded(
          child: controller.isBusy && records.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : records.isEmpty
              ? EmptyState(
                  icon: _filter.isEmpty ? Icons.inbox : Icons.search_off,
                  title: _filter.isEmpty
                      ? 'Belum Ada Data'
                      : 'Data Tidak Ditemukan',
                  message: _filter.isEmpty
                      ? '${widget.title} akan muncul di sini.'
                      : 'Coba gunakan kata kunci lain.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount:
                      records.length +
                      (controller.canLoadMoreFeatureRecords(
                            widget.path,
                            query: query,
                          )
                          ? 1
                          : 0),
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    if (index == records.length) {
                      return SizedBox(
                        width: double.infinity,
                        child: Center(
                          child: OutlinedButton.icon(
                            onPressed: controller.isBusy
                                ? null
                                : () => controller.loadMoreFeatureRecords(
                                    widget.path,
                                    query: query,
                                  ),
                            icon: const Icon(Icons.expand_more),
                            label: const Text('Muat Lagi'),
                          ),
                        ),
                      );
                    }
                    final record = records[index];
                    return _FeatureRecordCard(
                      record: record,
                      fields: widget.fields,
                      labelKeys: widget.labelKeys,
                      summaryKeys: widget.summaryKeys,
                      icon: _screenIcon(widget.path),
                      path: widget.path,
                      onEdit: canUpdate
                          ? () => _openForm(context, record: record)
                          : null,
                      onDelete: canDelete
                          ? () => _confirmDelete(context, record)
                          : null,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    FeatureRecord record,
  ) async {
    final controller = AppScope.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus Data'),
        content: Text('Hapus ${record.label(widget.labelKeys)}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await controller.deleteFeatureRecord(widget.path, record);
    }
  }

  IconData _screenIcon(String path) {
    if (path.contains('suppliers')) return Icons.local_shipping;
    if (path.contains('locations')) return Icons.warehouse;
    if (path.contains('categories')) return Icons.category;
    if (path.contains('purchases')) return Icons.shopping_cart_checkout;
    if (path.contains('returns')) return Icons.assignment_return;
    if (path.contains('payables')) return Icons.payments;
    if (path.contains('receivables')) return Icons.request_quote;
    if (path.contains('cash')) return Icons.account_balance_wallet;
    if (path.contains('stock')) return Icons.inventory;
    if (path.contains('roles')) return Icons.admin_panel_settings;
    if (path.contains('users')) return Icons.manage_accounts;
    if (path.contains('settings')) return Icons.settings;
    return Icons.list_alt;
  }

  String _permissionSectionForPath(String path) {
    if (path.contains('suppliers')) return 'suppliers';
    if (path.contains('locations')) return 'inventory';
    if (path.contains('product-categories')) return 'inventory';
    if (path.contains('customer-group-discounts')) return 'customers';
    if (path.contains('customers')) return 'customers';
    if (path.contains('roles')) return 'roles';
    if (path.contains('users')) return 'users';
    if (path.contains('purchase-returns')) return 'purchase-returns';
    if (path.contains('sales-returns')) return 'sales-returns';
    if (path.contains('returns')) return 'returns';
    if (path.contains('purchases')) return 'purchases';
    return 'master';
  }

  Future<void> _openForm(BuildContext context, {FeatureRecord? record}) async {
    final controller = AppScope.of(context);
    final textControllers = {
      for (final field in widget.fields)
        field.key: TextEditingController(
          text:
              (record?.values[field.key] ??
                      widget.createTemplate?[field.key] ??
                      (record == null && field.key == 'kode'
                          ? _generatedCode()
                          : null) ??
                      '')
                  .toString(),
        ),
    };

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          record == null ? 'Tambah ${widget.title}' : 'Edit ${widget.title}',
        ),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final field in widget.fields)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _FeatureFormField(
                      field: field,
                      controller: textControllers[field.key]!,
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () async {
              final body = {
                for (final field in widget.fields)
                  field.key: _fieldValue(
                    field,
                    textControllers[field.key]!.text.trim(),
                  ),
              };
              if (widget.createTemplate?['items'] != null) {
                body['items'] = [
                  {
                    'product_id': body.remove('product_id') ?? 1,
                    'location_id': body.remove('location_id'),
                    'quantity': body.remove('quantity') ?? 1,
                    'unit_price': body.remove('unit_price') ?? 0,
                  },
                ];
              }
              await controller.saveFeatureRecord(widget.path, {
                ...?widget.createTemplate,
                ...body,
              }, id: record?.id);
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  Object _fieldValue(FeatureField field, String value) {
    if (field.phone) return value.replaceAll(RegExp(r'[^0-9]'), '');
    if (field.numeric) return num.tryParse(value) ?? 0;
    if (field.key.startsWith('can_')) return value != 'false';
    return value;
  }

  String _generatedCode() {
    final prefix = switch (widget.path) {
      '/api/suppliers' => 'SUP',
      '/api/locations' => 'LOK',
      '/api/product-categories' => 'GRP',
      '/api/discount-categories' => 'DSK',
      _ =>
        widget.title
            .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
            .toUpperCase()
            .padRight(3, 'X')
            .substring(0, 3),
    };
    final records = AppScope.of(context).featureRecords(widget.path);
    final next = records.fold<int>(
      1,
      (max, record) => record.id >= max ? record.id + 1 : max,
    );
    return '$prefix-${next.toString().padLeft(3, '0')}';
  }
}

class _FeatureRecordCard extends StatelessWidget {
  const _FeatureRecordCard({
    required this.record,
    required this.fields,
    required this.labelKeys,
    required this.summaryKeys,
    required this.icon,
    required this.path,
    this.onEdit,
    this.onDelete,
  });

  final FeatureRecord record;
  final List<FeatureField> fields;
  final List<String> labelKeys;
  final List<String>? summaryKeys;
  final IconData icon;
  final String path;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final title = path.contains('users')
        ? (record.values['nama'] ??
                  record.values['name'] ??
                  record.label(labelKeys))
              .toString()
        : record.label(labelKeys);
    final details = _detailFields().take(6).toList(growable: false);

    return Card(
      clipBehavior: Clip.antiAlias,
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _showDetail(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: colors.onPrimaryContainer),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _metaText(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (_statusValue() case final status?)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: _StatusChip(value: status),
                    ),
                  if (onEdit != null)
                    IconButton(
                      tooltip: 'Edit',
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit),
                    ),
                  if (onDelete != null)
                    IconButton(
                      tooltip: 'Hapus',
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline),
                    ),
                ],
              ),
              if (details.isNotEmpty) ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final field in details)
                      _DetailPill(
                        label: field.label,
                        value: _displayValue(
                          context,
                          field.key,
                          record.values[field.key],
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Iterable<FeatureField> _detailFields() {
    return fields.where((field) {
      if (summaryKeys != null && !summaryKeys!.contains(field.key)) {
        return false;
      }
      if ((path.contains('product-categories') || path.contains('locations')) &&
          (field.key == 'keterangan' || field.key == 'kode')) {
        return false;
      }
      if (_isTitleKey(field.key)) return false;
      if (field.key == 'status') return false;
      if (field.key == 'items') return false;
      final value = record.values[field.key];
      return value != null && value.toString().trim().isNotEmpty;
    });
  }

  Future<void> _showDetail(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(record.label(labelKeys)),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final entry in record.values.entries)
                  if (entry.key != 'items' &&
                      entry.value != null &&
                      entry.value.toString().trim().isNotEmpty)
                    _DetailLine(
                      label: _fieldLabel(entry.key),
                      value: _displayValue(context, entry.key, entry.value),
                    ),
                if (record.values['items'] is List) ...[
                  const SizedBox(height: 8),
                  _ItemRows(items: (record.values['items'] as List).cast()),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  String _displayValue(BuildContext context, String key, Object? value) {
    final field = fields.where((field) => field.key == key).firstOrNull;
    final referencePath = field?.referencePath;
    if (referencePath != null) {
      final records = AppScope.of(context).featureRecords(referencePath);
      final matches = records.where(
        (record) => _referenceValue(record, field!) == value.toString(),
      );
      if (matches.isNotEmpty) {
        return matches.first.label(field!.referenceLabelKeys);
      }
    }
    return _formatFeatureValue(key, value);
  }

  String _fieldLabel(String key) {
    for (final field in fields) {
      if (field.key == key) return field.label;
    }
    const labels = {
      'created_at': 'Dibuat',
      'updated_at': 'Diubah',
      'supplier_name': 'Suplier',
      'customer_name': 'Pelanggan',
      'category_name': 'Grup Produk',
      'location_name': 'Lokasi',
      'returned_products': 'Produk Retur',
      'bought_products': 'Produk Dibeli',
      'paid_amount': 'Terbayar',
      'remaining_amount': 'Sisa',
      'unit_price': 'Harga',
      'subtotal': 'Subtotal',
      'total': 'Total',
      'quantity': 'Qty',
      'keterangan': 'Keterangan',
    };
    if (labels.containsKey(key)) return labels[key]!;
    return key.replaceAll('_', ' ');
  }

  bool _isTitleKey(String key) {
    return labelKeys.contains(key) ||
        key == 'nama' ||
        key == 'nama_produk' ||
        key == 'supplier_name' ||
        key == 'customer_name';
  }

  String _metaText() {
    if (path.contains('users')) {
      final role = record.values['role'];
      return role == null || role.toString().trim().isEmpty
          ? 'ID ${record.id}'
          : _formatFeatureValue('role', role);
    }
    if (path.contains('roles')) {
      final note = record.values['keterangan'];
      return note == null || note.toString().trim().isEmpty
          ? 'ID ${record.id}'
          : note.toString();
    }
    final candidates = <String>[];
    for (final key in ['sku', 'username', 'role', 'created_at']) {
      final value = record.values[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        candidates.add(_formatFeatureValue(key, value));
      }
    }
    candidates.add('ID ${record.id}');
    return candidates.take(2).join(' | ');
  }

  String? _statusValue() {
    final value = record.values['status'];
    if (value == null || value.toString().trim().isEmpty) return null;
    return value.toString();
  }
}

class _FeatureFormField extends StatelessWidget {
  const _FeatureFormField({required this.field, required this.controller});

  final FeatureField field;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final options = field.options;
    if (options != null && options.isNotEmpty) {
      final current = options.any((option) => option.value == controller.text)
          ? controller.text
          : options.first.value;
      controller.text = current;
      return SearchableDropdown<String>(
        label: field.label,
        value: current,
        choices: [
          for (final option in options)
            DropdownChoice(value: option.value, label: option.label),
        ],
        onChanged: (value) => controller.text = value,
      );
    }

    final referencePath = field.referencePath;
    if (referencePath != null) {
      final records = AppScope.of(context).featureRecords(referencePath);
      if (records.isNotEmpty) {
        String valueFor(FeatureRecord record) => _referenceValue(record, field);
        final current =
            records.any((record) => valueFor(record) == controller.text)
            ? controller.text
            : valueFor(records.first);
        controller.text = current;
        return SearchableDropdown<String>(
          label: field.label,
          value: current,
          choices: [
            for (final record in records)
              DropdownChoice(
                value: valueFor(record),
                label: record.label(field.referenceLabelKeys),
              ),
          ],
          onChanged: (value) => controller.text = value,
        );
      }
    }

    return TextField(
      controller: controller,
      keyboardType: field.phone
          ? TextInputType.phone
          : field.numeric
          ? TextInputType.number
          : TextInputType.text,
      inputFormatters: field.phone
          ? [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s]')),
              field.key.toLowerCase().contains('telepon')
                  ? _HomePhoneFormatter()
                  : _PhoneFormatter(),
            ]
          : null,
      decoration: InputDecoration(labelText: field.label),
    );
  }
}

String _referenceValue(FeatureRecord record, FeatureField field) {
  final key = field.referenceValueKey;
  if (key != null) return record.values[key]?.toString() ?? '';
  return record.id.toString();
}

class _HomePhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    final formatted = _formatHomePhone(digits);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _ItemRows extends StatelessWidget {
  const _ItemRows({required this.items});

  final List<Object?> items;

  @override
  Widget build(BuildContext context) {
    final rows = items
        .whereType<Map>()
        .map((item) => item.cast<String, Object?>())
        .toList(growable: false);
    if (rows.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Daftar Produk',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        for (final item in rows)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (item['product_name'] ??
                          item['nama_produk'] ??
                          item['name'] ??
                          'Produk')
                      .toString(),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  '${_formatFeatureValue('quantity', item['quantity'] ?? item['jumlah_beli'])} x '
                  '${_formatFeatureValue('unit_price', item['unit_price'] ?? item['harga'])}',
                ),
                const SizedBox(height: 2),
                Text(
                  'Total ${_formatFeatureValue('subtotal', item['subtotal'] ?? item['total'])}',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(label, style: Theme.of(context).textTheme.labelMedium),
          ),
          Expanded(child: Text(value, textAlign: TextAlign.end)),
        ],
      ),
    );
  }
}

class _PhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    final formatted = _formatPhone(digits);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _DetailPill extends StatelessWidget {
  const _DetailPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 128, maxWidth: 220),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final normalized = value.toLowerCase();
    final isDone = normalized == 'paid' || normalized == 'lunas';
    final color = isDone ? colors.primaryContainer : colors.tertiaryContainer;
    final foreground = isDone
        ? colors.onPrimaryContainer
        : colors.onTertiaryContainer;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _formatStatus(value),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

String _formatFeatureValue(String key, Object? value) {
  if (value == null) return '-';
  final text = value.toString();
  if (text.isEmpty) return '-';

  final lowerKey = key.toLowerCase();
  final number = value is num ? value : num.tryParse(text);
  final currencyKeys = [
    'amount',
    'total',
    'harga',
    'price',
    'paid',
    'remaining',
  ];
  if (number != null && currencyKeys.any(lowerKey.contains)) {
    return rupiah(number);
  }

  if (lowerKey.contains('created_at') ||
      lowerKey.endsWith('_at') ||
      lowerKey.contains('tanggal')) {
    final date = DateTime.tryParse(text);
    if (date != null) return shortDate(date.toLocal());
  }

  if (lowerKey == 'status') return _formatStatus(text);
  if (lowerKey == 'role') {
    return switch (text) {
      'manajer' => 'Manajer',
      'administrator' => 'Administrator',
      'kasir' => 'Kasir',
      _ => _titleCase(text),
    };
  }
  if (lowerKey.startsWith('can_')) {
    return text == 'true' ? 'Diizinkan' : 'Diblokir';
  }
  if (lowerKey == 'type') return text == 'in' ? 'Kas Masuk' : 'Kas Keluar';
  if (lowerKey.contains('telepon')) {
    return _formatHomePhone(text);
  }
  if (lowerKey == 'phone') {
    return _formatPhone(text);
  }
  return text;
}

String _titleCase(String value) {
  return value
      .split(RegExp(r'[\s_-]+'))
      .where((part) => part.isNotEmpty)
      .map((part) => part[0].toUpperCase() + part.substring(1).toLowerCase())
      .join(' ');
}

String _formatHomePhone(String value) {
  final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.length <= 3) return digits;
  final areaLength = digits.startsWith('021') ? 3 : 4;
  if (digits.length <= areaLength) return digits;
  final area = digits.substring(0, areaLength);
  final number = digits.substring(areaLength);
  if (number.length <= 4) return '($area) $number';
  return '($area) ${number.substring(0, 4)}-${number.substring(4)}';
}

String _formatPhone(String value) {
  final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.length <= 4) return digits;
  if (digits.length <= 8) {
    return '${digits.substring(0, 4)}-${digits.substring(4)}';
  }
  return '${digits.substring(0, 4)}-${digits.substring(4, 8)}-${digits.substring(8)}';
}

String _formatStatus(String value) {
  return switch (value.toLowerCase()) {
    'paid' => 'Lunas',
    'open' => 'Belum Lunas',
    'partial' => 'Sebagian',
    _ => value,
  };
}
