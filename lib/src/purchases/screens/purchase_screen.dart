import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../inventory/models/product.dart';
import '../../shared/formatters.dart';
import '../../shared/models/feature_record.dart';
import '../../shared/widgets/debounced_text_field.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/fast_date_range_picker.dart';
import '../../shared/widgets/searchable_dropdown.dart';

class PurchaseScreen extends StatefulWidget {
  const PurchaseScreen({super.key});

  @override
  State<PurchaseScreen> createState() => _PurchaseScreenState();
}

class _PurchaseScreenState extends State<PurchaseScreen> {
  bool _loaded = false;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  int _supplierId = 0;
  int _categoryId = 0;
  int _productId = 0;
  DateTimeRange? _dateRange;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    final controller = AppScope.of(context);
    Future.microtask(() async {
      await controller.loadFeatureRecords('/api/suppliers');
      await controller.loadFeatureRecords('/api/product-categories');
      await controller.loadFeatureRecords('/api/purchases');
      await controller.refreshData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final purchases = controller.featureRecords('/api/purchases');
    final canCreate = controller.canCreateMenu('purchases');
    final canUpdate = controller.canUpdateMenu('purchases');
    final canDelete = controller.canDeleteMenu('purchases');

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: DebouncedTextField(
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() => _query = value);
                    controller.loadFeatureRecords(
                      '/api/purchases',
                      query: _purchaseQuery(search: value),
                      force: true,
                    );
                  },
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    labelText: 'Cari Pembelian',
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Bersihkan',
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                              controller.loadFeatureRecords(
                                '/api/purchases',
                                query: _purchaseQuery(search: ''),
                                force: true,
                              );
                            },
                            icon: const Icon(Icons.close),
                          ),
                  ),
                ),
              ),
              if (canCreate) ...[
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: controller.isBusy
                      ? null
                      : () async {
                          await showDialog<void>(
                            context: context,
                            builder: (_) => const _PurchaseDialog(),
                          );
                          if (mounted) await _loadPurchases();
                        },
                  icon: const Icon(Icons.add_shopping_cart),
                  label: const Text('Pembelian'),
                ),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 720;
              final suppliers = controller.featureRecords('/api/suppliers');
              final categories = controller.featureRecords(
                '/api/product-categories',
              );
              final products = controller.products
                  .where(
                    (product) =>
                        _categoryId == 0 || product.categoryId == _categoryId,
                  )
                  .toList(growable: false);
              final supplierFilter = SearchableDropdown<int>(
                label: 'Suplier',
                value: _supplierId,
                prefixIcon: Icons.local_shipping,
                choices: [
                  const DropdownChoice(value: 0, label: 'Semua Suplier'),
                  for (final supplier in suppliers)
                    DropdownChoice(
                      value: supplier.id,
                      label: supplier.label(const ['nama', 'kode']),
                    ),
                ],
                onChanged: controller.isBusy
                    ? null
                    : (value) {
                        setState(() => _supplierId = value);
                        _loadPurchases();
                      },
              );
              final categoryFilter = SearchableDropdown<int>(
                label: 'Grup Produk',
                value: _categoryId,
                prefixIcon: Icons.category,
                choices: [
                  const DropdownChoice(value: 0, label: 'Semua Grup'),
                  for (final category in categories)
                    DropdownChoice(
                      value: category.id,
                      label: category.label(const ['nama', 'kode']),
                    ),
                ],
                onChanged: controller.isBusy
                    ? null
                    : (value) {
                        setState(() {
                          _categoryId = value;
                          _productId = 0;
                        });
                        _loadPurchases();
                      },
              );
              final productFilter = SearchableDropdown<int>(
                label: 'Produk',
                value: _productId,
                prefixIcon: Icons.inventory_2,
                choices: [
                  const DropdownChoice(value: 0, label: 'Semua Produk'),
                  for (final product in products)
                    DropdownChoice(value: product.id, label: product.name),
                ],
                onChanged: controller.isBusy
                    ? null
                    : (value) {
                        setState(() => _productId = value);
                        _loadPurchases();
                      },
              );
              final dateFilter = Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: controller.isBusy
                          ? null
                          : () => _pickDateRange(context),
                      icon: const Icon(Icons.calendar_month),
                      label: Text(
                        _dateRange == null
                            ? 'Pilih Tanggal'
                            : '${_dateOnly(_dateRange!.start)} - ${_dateOnly(_dateRange!.end)}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  if (_dateRange != null)
                    IconButton(
                      tooltip: 'Hapus Filter Tanggal',
                      onPressed: controller.isBusy
                          ? null
                          : () {
                              setState(() => _dateRange = null);
                              _loadPurchases();
                            },
                      icon: const Icon(Icons.close),
                    ),
                ],
              );
              if (narrow) {
                return Column(
                  children: [
                    dateFilter,
                    const SizedBox(height: 8),
                    supplierFilter,
                    const SizedBox(height: 8),
                    categoryFilter,
                    const SizedBox(height: 8),
                    productFilter,
                  ],
                );
              }
              return Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: 944,
                  child: Row(
                    children: [
                      Expanded(child: dateFilter),
                      const SizedBox(width: 12),
                      Expanded(child: supplierFilter),
                      const SizedBox(width: 12),
                      Expanded(child: categoryFilter),
                      const SizedBox(width: 12),
                      Expanded(child: productFilter),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Expanded(
          child: controller.isBusy && purchases.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : purchases.isEmpty
              ? const EmptyState(
                  icon: Icons.shopping_cart_checkout,
                  title: 'Belum Ada Pembelian',
                  message: 'Transaksi pembelian akan muncul di sini.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount:
                      purchases.length +
                      (controller.canLoadMoreFeatureRecords(
                            '/api/purchases',
                            query: _purchaseQuery(),
                          )
                          ? 1
                          : 0),
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    if (index == purchases.length) {
                      return SizedBox(
                        width: double.infinity,
                        child: Center(
                          child: OutlinedButton.icon(
                            onPressed: controller.isBusy
                                ? null
                                : () => controller.loadMoreFeatureRecords(
                                    '/api/purchases',
                                    query: _purchaseQuery(),
                                  ),
                            icon: const Icon(Icons.expand_more),
                            label: const Text('Muat Lagi'),
                          ),
                        ),
                      );
                    }
                    return _PurchaseCard(
                      record: purchases[index],
                      onEdit: canUpdate
                          ? () async {
                              await showDialog<void>(
                                context: context,
                                builder: (_) =>
                                    _PurchaseDialog(record: purchases[index]),
                              );
                              if (mounted) await _loadPurchases();
                            }
                          : null,
                      onDelete: canDelete
                          ? () => _confirmDeletePurchase(
                              context,
                              purchases[index],
                            )
                          : null,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Map<String, String>? _purchaseQuery({String? search}) {
    final queryText = (search ?? _query).trim();
    final query = <String, String>{};
    if (queryText.isNotEmpty) query['search'] = queryText;
    if (_supplierId != 0) query['supplier_id'] = _supplierId.toString();
    if (_categoryId != 0) query['category_id'] = _categoryId.toString();
    if (_productId != 0) query['product_id'] = _productId.toString();
    final range = _dateRange;
    if (range != null) {
      query['from'] = DateTime(
        range.start.year,
        range.start.month,
        range.start.day,
      ).toIso8601String();
      query['to'] = DateTime(
        range.end.year,
        range.end.month,
        range.end.day + 1,
      ).toIso8601String();
    }
    return query.isEmpty ? null : query;
  }

  Future<void> _loadPurchases() {
    return AppScope.of(context).loadFeatureRecords(
      '/api/purchases',
      query: _purchaseQuery(),
      force: true,
    );
  }

  Future<void> _pickDateRange(BuildContext context) async {
    final now = DateTime.now();
    final selected = await showFastDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 1),
      initialDateRange:
          _dateRange ??
          DateTimeRange(
            start: DateTime(now.year, now.month, now.day),
            end: DateTime(now.year, now.month, now.day),
          ),
    );
    if (selected == null) return;
    setState(() => _dateRange = selected);
    await _loadPurchases();
  }

  String _dateOnly(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  Future<void> _confirmDeletePurchase(
    BuildContext context,
    FeatureRecord record,
  ) async {
    final controller = AppScope.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus Pembelian'),
        content: Text('Hapus pembelian #${record.id}?'),
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
      await controller.deleteFeatureRecord('/api/purchases', record);
      if (mounted) await _loadPurchases();
    }
  }
}

class _PurchaseCard extends StatelessWidget {
  const _PurchaseCard({required this.record, this.onEdit, this.onDelete});

  final FeatureRecord record;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final values = record.values;
    final date = DateTime.tryParse(values['created_at']?.toString() ?? '');
    final total = _number(values['total']);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _showDetail(context),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CircleAvatar(child: Icon(Icons.shopping_cart_checkout)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      values['supplier_name']?.toString().trim().isNotEmpty ==
                              true
                          ? values['supplier_name'].toString()
                          : 'Tanpa Suplier',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(date == null ? '-' : shortDate(date.toLocal())),
                    const SizedBox(height: 10),
                    Text(
                      values['bought_products']?.toString().trim().isNotEmpty ==
                              true
                          ? values['bought_products'].toString()
                          : 'Belum Ada Produk',
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    rupiah(total),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (onEdit != null || onDelete != null)
                    Wrap(
                      spacing: 2,
                      children: [
                        if (onEdit != null)
                          IconButton(
                            tooltip: 'Edit Pembelian',
                            onPressed: onEdit,
                            icon: const Icon(Icons.edit),
                          ),
                        if (onDelete != null)
                          IconButton(
                            tooltip: 'Hapus Pembelian',
                            onPressed: onDelete,
                            icon: const Icon(Icons.delete_outline),
                          ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showDetail(BuildContext context) async {
    final values = record.values;
    final date = DateTime.tryParse(values['created_at']?.toString() ?? '');
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Pembelian #${record.id}'),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PurchaseDetailLine(
                label: 'Tanggal',
                value: date == null ? '-' : shortDate(date.toLocal()),
              ),
              _PurchaseDetailLine(
                label: 'Suplier',
                value: values['supplier_name']?.toString() ?? 'Tanpa Suplier',
              ),
              const SizedBox(height: 8),
              _PurchaseItemRows(
                items: (values['items'] is List)
                    ? (values['items'] as List).cast()
                    : const [],
                fallback: values['bought_products']?.toString(),
              ),
              const SizedBox(height: 8),
              _PurchaseDetailLine(
                label: 'Total',
                value: rupiah(_number(values['total'])),
              ),
            ],
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
}

class _PurchaseItemRows extends StatelessWidget {
  const _PurchaseItemRows({required this.items, this.fallback});

  final List<Object?> items;
  final String? fallback;

  @override
  Widget build(BuildContext context) {
    final rows = items
        .whereType<Map>()
        .map((item) => item.cast<String, Object?>())
        .toList(growable: false);
    if (rows.isEmpty) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Text(
          fallback?.trim().isNotEmpty == true ? fallback! : 'Belum Ada Produk',
        ),
      );
    }

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
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    (item['product_name'] ?? item['nama_produk'] ?? 'Produk')
                        .toString(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${item['quantity'] ?? '-'} x ${rupiah(_number(item['unit_price']))}',
                ),
                const SizedBox(width: 12),
                Text(
                  rupiah(_number(item['subtotal'])),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _PurchaseDetailLine extends StatelessWidget {
  const _PurchaseDetailLine({required this.label, required this.value});

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
            width: 96,
            child: Text(label, style: Theme.of(context).textTheme.labelMedium),
          ),
          Expanded(child: Text(value, textAlign: TextAlign.end)),
        ],
      ),
    );
  }
}

class _PurchaseDialog extends StatefulWidget {
  const _PurchaseDialog({this.record});

  final FeatureRecord? record;

  @override
  State<_PurchaseDialog> createState() => _PurchaseDialogState();
}

class _PurchaseDialogState extends State<_PurchaseDialog> {
  late final TextEditingController _paid = TextEditingController(
    text: widget.record == null
        ? ''
        : _number(widget.record!.values['paid_amount']).round().toString(),
  );
  late final TextEditingController _note = TextEditingController(
    text: widget.record?.values['keterangan']?.toString() ?? '',
  );
  late List<_PurchaseLineDraft> _lines = _initialLines();
  int? _supplierId;

  @override
  void initState() {
    super.initState();
    _supplierId = (widget.record?.values['supplier_id'] as num?)?.toInt();
  }

  @override
  void dispose() {
    _paid.dispose();
    _note.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final suppliers = controller.featureRecords('/api/suppliers');
    final products = controller.products;
    _supplierId ??= suppliers.isEmpty ? null : suppliers.first.id;

    return AlertDialog(
      title: Text(
        widget.record == null ? 'Tambah Pembelian' : 'Edit Pembelian',
      ),
      content: SizedBox(
        width: 720,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SearchableDropdown<int?>(
                label: 'Suplier',
                value: _supplierId,
                choices: [
                  const DropdownChoice<int?>(
                    value: null,
                    label: 'Tanpa Suplier',
                  ),
                  for (final supplier in suppliers)
                    DropdownChoice<int?>(
                      value: supplier.id,
                      label: supplier.label(const ['nama', 'kode']),
                    ),
                ],
                onChanged: (value) => setState(() => _supplierId = value),
              ),
              const SizedBox(height: 12),
              for (var index = 0; index < _lines.length; index++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _PurchaseLineEditor(
                    line: _lines[index],
                    products: products,
                    canRemove: _lines.length > 1,
                    onChanged: () => setState(() {}),
                    onRemove: () {
                      setState(() {
                        _lines.removeAt(index).dispose();
                      });
                    },
                  ),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() {
                    _lines = [..._lines, _newLineFor(products)];
                  }),
                  icon: const Icon(Icons.add),
                  label: const Text('Tambah Produk'),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _paid,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Dibayar',
                  helperText: 'Total pembelian ${rupiah(_total)}',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _note,
                decoration: const InputDecoration(labelText: 'Keterangan'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _lines.any((line) => line.productId != null)
              ? () => _save(context)
              : null,
          child: const Text('Simpan'),
        ),
      ],
    );
  }

  double get _total => _lines.fold<double>(0, (sum, line) => sum + line.total);

  Future<void> _save(BuildContext context) async {
    final controller = AppScope.of(context);
    final items = <Map<String, Object?>>[];
    for (final line in _lines) {
      if (line.productId == null) continue;
      final quantity = int.tryParse(line.quantity.text.trim()) ?? 0;
      final unitPrice = double.tryParse(line.unitPrice.text.trim()) ?? 0;
      if (quantity <= 0 || unitPrice < 0) continue;
      items.add({
        'product_id': line.productId,
        'location_id': line.locationId,
        'quantity': quantity,
        'unit_price': unitPrice,
      });
    }
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tambahkan minimal satu produk.')),
      );
      return;
    }

    await controller.saveFeatureRecord('/api/purchases', {
      'supplier_id': _supplierId,
      'items': items,
      'paid_amount': double.tryParse(_paid.text.trim()) ?? _total,
      'keterangan': _note.text.trim(),
    }, id: widget.record?.id);
    if (context.mounted) Navigator.of(context).pop();
  }

  List<_PurchaseLineDraft> _initialLines() {
    final items = widget.record?.values['items'];
    if (items is! List || items.isEmpty) return [_PurchaseLineDraft()];
    return items
        .whereType<Map>()
        .map((item) {
          final map = item.cast<String, Object?>();
          return _PurchaseLineDraft(
            productId: (map['product_id'] as num?)?.toInt(),
            locationId: (map['location_id'] as num?)?.toInt(),
            productName: (map['nama_produk'] ?? map['product_name'] ?? 'Produk')
                .toString(),
            quantity: ((map['quantity'] as num?)?.toInt() ?? 1).toString(),
            unitPrice: _number(map['unit_price']).round().toString(),
          );
        })
        .toList(growable: true);
  }

  _PurchaseLineDraft _newLineFor(List<Product> products) {
    if (products.isEmpty) return _PurchaseLineDraft();
    final usedIds = _lines
        .map((line) => line.productId)
        .whereType<int>()
        .toSet();
    final product =
        products.where((item) => !usedIds.contains(item.id)).firstOrNull ??
        products.first;
    final price = product.purchasePrice > 0
        ? product.purchasePrice
        : product.price;
    return _PurchaseLineDraft(
      productId: product.id,
      productName: product.name,
      quantity: '1',
      unitPrice: price.round().toString(),
    );
  }
}

class _PurchaseLineEditor extends StatelessWidget {
  const _PurchaseLineEditor({
    required this.line,
    required this.products,
    required this.canRemove,
    required this.onChanged,
    required this.onRemove,
  });

  final _PurchaseLineDraft line;
  final List<Product> products;
  final bool canRemove;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final productExists = products.any(
      (product) => product.id == line.productId,
    );
    if (!productExists && line.productId == null && products.isNotEmpty) {
      line.productId = products.first.id;
      line.productName = products.first.name;
    }
    if (line.unitPrice.text.trim().isEmpty && line.productId != null) {
      final product = products
          .where((item) => item.id == line.productId)
          .firstOrNull;
      if (product != null) {
        line.unitPrice.text =
            (product.purchasePrice > 0 ? product.purchasePrice : product.price)
                .round()
                .toString();
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 620;
        final productField = SearchableDropdown<int?>(
          label: 'Produk',
          value: line.productId,
          choices: [
            if (!productExists && line.productId != null)
              DropdownChoice(
                value: line.productId,
                label: line.productName ?? 'Produk #${line.productId}',
              ),
            for (final product in products)
              DropdownChoice(
                value: product.id,
                label: '${product.name} - ${product.sku}',
              ),
          ],
          onChanged: (value) {
            line.productId = value;
            final product = products
                .where((item) => item.id == value)
                .firstOrNull;
            if (product != null) {
              line.productName = product.name;
              line.unitPrice.text =
                  (product.purchasePrice > 0
                          ? product.purchasePrice
                          : product.price)
                      .round()
                      .toString();
            }
            onChanged();
          },
        );
        final fields = [
          Expanded(flex: 3, child: productField),
          const SizedBox(width: 8),
          SizedBox(
            width: 84,
            child: TextField(
              controller: line.quantity,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Qty'),
              onChanged: (_) => onChanged(),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 132,
            child: TextField(
              controller: line.unitPrice,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Harga'),
              onChanged: (_) => onChanged(),
            ),
          ),
          IconButton(
            tooltip: 'Hapus',
            onPressed: canRemove ? onRemove : null,
            icon: const Icon(Icons.delete_outline),
          ),
        ];
        if (narrow) {
          return Column(
            children: [
              productField,
              const SizedBox(height: 8),
              Row(children: fields.skip(2).toList()),
            ],
          );
        }
        return Row(children: fields);
      },
    );
  }
}

class _PurchaseLineDraft {
  _PurchaseLineDraft({
    this.productId,
    this.locationId,
    this.productName,
    String quantity = '1',
    String? unitPrice,
  }) : quantity = TextEditingController(text: quantity),
       unitPrice = TextEditingController(text: unitPrice ?? '');

  int? productId;
  int? locationId;
  String? productName;
  final TextEditingController quantity;
  final TextEditingController unitPrice;

  double get total {
    final qty = int.tryParse(quantity.text.trim()) ?? 0;
    final price = double.tryParse(unitPrice.text.trim()) ?? 0;
    return qty * price;
  }

  void dispose() {
    quantity.dispose();
    unitPrice.dispose();
  }
}

double _number(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}
