import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../shared/formatters.dart';
import '../../shared/models/feature_record.dart';
import '../../shared/widgets/app_tab_scaffold.dart';
import '../../shared/widgets/debounced_text_field.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/fast_date_range_picker.dart';
import '../../shared/widgets/searchable_dropdown.dart';

class ReturnsScreen extends StatelessWidget {
  const ReturnsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final tabs = <AppTabItem>[
      if (controller.canViewMenu('purchase-returns'))
        const AppTabItem(label: 'Retur Pembelian', child: _PurchaseReturnTab()),
      if (controller.canViewMenu('sales-returns'))
        const AppTabItem(label: 'Retur Penjualan', child: _SalesReturnTab()),
    ];

    if (tabs.isEmpty) {
      return const EmptyState(
        icon: Icons.lock,
        title: 'Akses Ditolak',
        message: 'Menu retur belum diizinkan untuk role ini.',
      );
    }

    return AppTabScaffold(tabs: tabs, emptyMessage: 'Tidak Ada Retur.');
  }
}

class _PurchaseReturnTab extends StatefulWidget {
  const _PurchaseReturnTab();

  @override
  State<_PurchaseReturnTab> createState() => _PurchaseReturnTabState();
}

class _PurchaseReturnTabState extends State<_PurchaseReturnTab> {
  bool _loaded = false;
  final TextEditingController _search = TextEditingController();
  String _query = '';
  int _supplierId = 0;
  int _categoryId = 0;
  int _productId = 0;
  DateTimeRange? _dateRange;

  @override
  void dispose() {
    _search.dispose();
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
      await controller.refreshData();
      await _loadReturns();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final rows = controller.featureRecords('/api/purchase-returns');
    final canCreate = controller.canCreateMenu('purchase-returns');
    final canUpdate = controller.canUpdateMenu('purchase-returns');

    return _ReturnList(
      search: _search,
      query: _query,
      onSearch: (value) {
        setState(() => _query = value);
        _loadReturns();
      },
      addLabel: 'Retur Pembelian',
      onAdd: controller.isBusy || !canCreate
          ? null
          : () => showDialog<void>(
              context: context,
              builder: (_) => const _PurchaseReturnDialog(),
            ),
      rows: rows,
      canUpdate: canUpdate,
      canLoadMore: controller.canLoadMoreFeatureRecords(
        '/api/purchase-returns',
        query: _returnQuery(),
      ),
      onLoadMore: () => controller.loadMoreFeatureRecords(
        '/api/purchase-returns',
        query: _returnQuery(),
      ),
      onEdit: (record) => showDialog<void>(
        context: context,
        builder: (_) => _PurchaseReturnDialog(record: record),
      ),
      emptyIcon: Icons.assignment_return,
      emptyTitle: 'Belum Ada Retur Pembelian',
      filters: _ReturnFilters(
        partnerLabel: 'Suplier',
        partnerIcon: Icons.local_shipping,
        partnerValue: _supplierId,
        partnerChoices: [
          const DropdownChoice(value: 0, label: 'Semua Suplier'),
          for (final supplier in controller.featureRecords('/api/suppliers'))
            DropdownChoice(
              value: supplier.id,
              label: supplier.label(const ['nama', 'kode']),
            ),
        ],
        categoryValue: _categoryId,
        productValue: _productId,
        products: controller.products
            .where(
              (product) =>
                  _categoryId == 0 || product.categoryId == _categoryId,
            )
            .map(
              (product) =>
                  DropdownChoice(value: product.id, label: product.name),
            )
            .toList(growable: false),
        categoryChoices: [
          const DropdownChoice(value: 0, label: 'Semua Grup'),
          for (final category in controller.featureRecords(
            '/api/product-categories',
          ))
            DropdownChoice(
              value: category.id,
              label: category.label(const ['nama', 'kode']),
            ),
        ],
        dateLabel: _dateLabel(),
        onPartnerChanged: (value) {
          setState(() => _supplierId = value);
          _loadReturns();
        },
        onCategoryChanged: (value) {
          setState(() {
            _categoryId = value;
            _productId = 0;
          });
          _loadReturns();
        },
        onProductChanged: (value) {
          setState(() => _productId = value);
          _loadReturns();
        },
        onDatePressed: () => _pickDateRange(context),
        onClearDate: _dateRange == null
            ? null
            : () {
                setState(() => _dateRange = null);
                _loadReturns();
              },
      ),
    );
  }

  Map<String, String>? _returnQuery() {
    final query = <String, String>{};
    final search = _query.trim();
    if (search.isNotEmpty) query['search'] = search;
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

  Future<void> _loadReturns() {
    return AppScope.of(context).loadFeatureRecords(
      '/api/purchase-returns',
      query: _returnQuery(),
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
    await _loadReturns();
  }

  String _dateLabel() => _dateRange == null
      ? 'Pilih Tanggal'
      : '${_dateOnly(_dateRange!.start)} - ${_dateOnly(_dateRange!.end)}';
}

class _SalesReturnTab extends StatefulWidget {
  const _SalesReturnTab();

  @override
  State<_SalesReturnTab> createState() => _SalesReturnTabState();
}

class _SalesReturnTabState extends State<_SalesReturnTab> {
  bool _loaded = false;
  final TextEditingController _search = TextEditingController();
  String _query = '';
  int _customerId = 0;
  int _categoryId = 0;
  int _productId = 0;
  DateTimeRange? _dateRange;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    final controller = AppScope.of(context);
    Future.microtask(() async {
      if (controller.canCreateMenu('sales-returns') ||
          controller.canUpdateMenu('sales-returns')) {
        await controller.refreshData();
      }
      await controller.loadFeatureRecords('/api/product-categories');
      await _loadReturns();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final rows = controller.featureRecords('/api/sales-returns');
    final canCreate = controller.canCreateMenu('sales-returns');
    final canUpdate = controller.canUpdateMenu('sales-returns');

    return _ReturnList(
      search: _search,
      query: _query,
      onSearch: (value) {
        setState(() => _query = value);
        _loadReturns();
      },
      addLabel: 'Retur Penjualan',
      onAdd: controller.isBusy || !canCreate
          ? null
          : () => showDialog<void>(
              context: context,
              builder: (_) => const _SalesReturnDialog(),
            ),
      rows: rows,
      canUpdate: canUpdate,
      canLoadMore: controller.canLoadMoreFeatureRecords(
        '/api/sales-returns',
        query: _returnQuery(),
      ),
      onLoadMore: () => controller.loadMoreFeatureRecords(
        '/api/sales-returns',
        query: _returnQuery(),
      ),
      onEdit: (record) => showDialog<void>(
        context: context,
        builder: (_) => _SalesReturnDialog(record: record),
      ),
      emptyIcon: Icons.assignment_returned,
      emptyTitle: 'Belum Ada Retur Penjualan',
      filters: _ReturnFilters(
        partnerLabel: 'Pelanggan',
        partnerIcon: Icons.people,
        partnerValue: _customerId,
        partnerChoices: [
          const DropdownChoice(value: 0, label: 'Semua Pelanggan'),
          for (final customer in controller.customers)
            DropdownChoice(value: customer.id, label: customer.name),
        ],
        categoryValue: _categoryId,
        productValue: _productId,
        products: controller.products
            .where(
              (product) =>
                  _categoryId == 0 || product.categoryId == _categoryId,
            )
            .map(
              (product) =>
                  DropdownChoice(value: product.id, label: product.name),
            )
            .toList(growable: false),
        categoryChoices: [
          const DropdownChoice(value: 0, label: 'Semua Grup'),
          for (final category in controller.featureRecords(
            '/api/product-categories',
          ))
            DropdownChoice(
              value: category.id,
              label: category.label(const ['nama', 'kode']),
            ),
        ],
        dateLabel: _dateLabel(),
        onPartnerChanged: (value) {
          setState(() => _customerId = value);
          _loadReturns();
        },
        onCategoryChanged: (value) {
          setState(() {
            _categoryId = value;
            _productId = 0;
          });
          _loadReturns();
        },
        onProductChanged: (value) {
          setState(() => _productId = value);
          _loadReturns();
        },
        onDatePressed: () => _pickDateRange(context),
        onClearDate: _dateRange == null
            ? null
            : () {
                setState(() => _dateRange = null);
                _loadReturns();
              },
      ),
    );
  }

  Map<String, String>? _returnQuery() {
    final query = <String, String>{};
    final search = _query.trim();
    if (search.isNotEmpty) query['search'] = search;
    if (_customerId != 0) query['customer_id'] = _customerId.toString();
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

  Future<void> _loadReturns() {
    return AppScope.of(context).loadFeatureRecords(
      '/api/sales-returns',
      query: _returnQuery(),
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
    await _loadReturns();
  }

  String _dateLabel() => _dateRange == null
      ? 'Pilih Tanggal'
      : '${_dateOnly(_dateRange!.start)} - ${_dateOnly(_dateRange!.end)}';
}

class _ReturnList extends StatelessWidget {
  const _ReturnList({
    required this.search,
    required this.query,
    required this.onSearch,
    required this.addLabel,
    required this.onAdd,
    required this.rows,
    required this.canUpdate,
    required this.canLoadMore,
    required this.onLoadMore,
    required this.onEdit,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.filters,
  });

  final TextEditingController search;
  final String query;
  final ValueChanged<String> onSearch;
  final String addLabel;
  final VoidCallback? onAdd;
  final List<FeatureRecord> rows;
  final bool canUpdate;
  final bool canLoadMore;
  final Future<void> Function() onLoadMore;
  final ValueChanged<FeatureRecord> onEdit;
  final IconData emptyIcon;
  final String emptyTitle;
  final Widget filters;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 560;
              final searchField = DebouncedTextField(
                controller: search,
                onChanged: onSearch,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  labelText: 'Cari Retur',
                  suffixIcon: query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Bersihkan',
                          onPressed: () {
                            search.clear();
                            onSearch('');
                          },
                          icon: const Icon(Icons.close),
                        ),
                ),
              );
              final addButton = onAdd == null
                  ? null
                  : FilledButton.icon(
                      onPressed: onAdd,
                      icon: const Icon(Icons.add),
                      label: Text(addLabel),
                    );
              if (addButton == null) return searchField;
              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [searchField, const SizedBox(height: 8), addButton],
                );
              }
              return Row(
                children: [
                  Expanded(child: searchField),
                  const SizedBox(width: 12),
                  addButton,
                ],
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: filters,
        ),
        Expanded(
          child: rows.isEmpty
              ? EmptyState(
                  icon: emptyIcon,
                  title: emptyTitle,
                  message: 'Data retur akan muncul di sini.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: rows.length + (canLoadMore ? 1 : 0),
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    if (index == rows.length) {
                      return SizedBox(
                        width: double.infinity,
                        child: Center(
                          child: OutlinedButton.icon(
                            onPressed: onLoadMore,
                            icon: const Icon(Icons.expand_more),
                            label: const Text('Muat Lagi'),
                          ),
                        ),
                      );
                    }
                    return _ReturnCard(
                      record: rows[index],
                      onEdit: canUpdate ? () => onEdit(rows[index]) : null,
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _ReturnFilters extends StatelessWidget {
  const _ReturnFilters({
    required this.partnerLabel,
    required this.partnerIcon,
    required this.partnerValue,
    required this.partnerChoices,
    required this.categoryValue,
    required this.productValue,
    required this.categoryChoices,
    required this.products,
    required this.dateLabel,
    required this.onPartnerChanged,
    required this.onCategoryChanged,
    required this.onProductChanged,
    required this.onDatePressed,
    required this.onClearDate,
  });

  final String partnerLabel;
  final IconData partnerIcon;
  final int partnerValue;
  final List<DropdownChoice<int>> partnerChoices;
  final int categoryValue;
  final int productValue;
  final List<DropdownChoice<int>> categoryChoices;
  final List<DropdownChoice<int>> products;
  final String dateLabel;
  final ValueChanged<int> onPartnerChanged;
  final ValueChanged<int> onCategoryChanged;
  final ValueChanged<int> onProductChanged;
  final VoidCallback onDatePressed;
  final VoidCallback? onClearDate;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 760;
        final partnerFilter = SearchableDropdown<int>(
          label: partnerLabel,
          value: partnerValue,
          prefixIcon: partnerIcon,
          choices: partnerChoices,
          onChanged: onPartnerChanged,
        );
        final categoryFilter = SearchableDropdown<int>(
          label: 'Grup Produk',
          value: categoryValue,
          prefixIcon: Icons.category,
          choices: categoryChoices,
          onChanged: onCategoryChanged,
        );
        final productFilter = SearchableDropdown<int>(
          label: 'Produk',
          value: productValue,
          prefixIcon: Icons.inventory_2,
          choices: [
            const DropdownChoice(value: 0, label: 'Semua Produk'),
            ...products,
          ],
          onChanged: onProductChanged,
        );
        final dateFilter = Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onDatePressed,
                icon: const Icon(Icons.calendar_month),
                label: Text(dateLabel, overflow: TextOverflow.ellipsis),
              ),
            ),
            if (onClearDate != null)
              IconButton(
                tooltip: 'Hapus Filter Tanggal',
                onPressed: onClearDate,
                icon: const Icon(Icons.close),
              ),
          ],
        );
        if (narrow) {
          return Column(
            children: [
              dateFilter,
              const SizedBox(height: 8),
              partnerFilter,
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
                Expanded(child: partnerFilter),
                const SizedBox(width: 12),
                Expanded(child: categoryFilter),
                const SizedBox(width: 12),
                Expanded(child: productFilter),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ReturnCard extends StatelessWidget {
  const _ReturnCard({required this.record, this.onEdit});

  final FeatureRecord record;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final values = record.values;
    final date = DateTime.tryParse(values['created_at']?.toString() ?? '');
    final partner =
        values['supplier_name'] ?? values['customer_name'] ?? 'Tanpa Relasi';
    final products = values['returned_products']?.toString() ?? '';
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _showDetail(context),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const CircleAvatar(child: Icon(Icons.assignment_return)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      partner.toString(),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(date == null ? '-' : shortDate(date.toLocal())),
                    const SizedBox(height: 8),
                    Text(
                      products.trim().isEmpty ? 'Belum Ada Produk' : products,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    rupiah(_number(values['total'])),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (onEdit != null)
                    IconButton(
                      tooltip: 'Edit Retur',
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit),
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
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Retur #${record.id}'),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DetailLine(
                  label: 'Transaksi',
                  value:
                      '#${values['purchase_id'] ?? values['transaction_id'] ?? '-'}',
                ),
                _DetailLine(
                  label: values['supplier_name'] != null
                      ? 'Suplier'
                      : 'Pelanggan',
                  value:
                      (values['supplier_name'] ??
                              values['customer_name'] ??
                              'Tanpa Relasi')
                          .toString(),
                ),
                const SizedBox(height: 8),
                _ReturnItemRows(
                  items: (values['items'] is List)
                      ? (values['items'] as List).cast()
                      : const [],
                ),
                const Divider(),
                _DetailLine(
                  label: 'Total',
                  value: rupiah(_number(values['total'])),
                ),
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
}

class _PurchaseReturnDialog extends StatefulWidget {
  const _PurchaseReturnDialog({this.record});

  final FeatureRecord? record;

  @override
  State<_PurchaseReturnDialog> createState() => _PurchaseReturnDialogState();
}

class _PurchaseReturnDialogState extends State<_PurchaseReturnDialog> {
  late final TextEditingController _note = TextEditingController(
    text: widget.record?.values['keterangan']?.toString() ?? '',
  );
  int? _purchaseId;
  List<_ReturnLineDraft> _lines = [];
  bool _loadedPurchases = false;

  @override
  void dispose() {
    _note.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loadedPurchases) return;
    _loadedPurchases = true;
    Future.microtask(_loadPurchases);
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final purchases = controller.featureRecords('/api/purchases');
    final purchase = purchases
        .where((record) => record.id == _purchaseId)
        .firstOrNull;
    _syncPurchaseLines(purchase);

    return AlertDialog(
      title: Text(
        widget.record == null
            ? 'Tambah Retur Pembelian'
            : 'Edit Retur Pembelian',
      ),
      content: SizedBox(
        width: 640,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ReferenceDropdown(
                value: _purchaseId,
                label: 'Pembelian',
                emptyText: 'Tidak Ada Pembelian Hari Ini',
                entries: [
                  for (final record in purchases)
                    _ReferenceEntry(
                      id: record.id,
                      label: _purchaseLabel(record),
                    ),
                ],
                onChanged: (value) {
                  setState(() {
                    _purchaseId = value;
                    _replaceLines(const []);
                  });
                },
              ),
              const SizedBox(height: 12),
              for (final line in _lines)
                _ReturnLineEditor(line: line, onChanged: () => setState(() {})),
              const SizedBox(height: 8),
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
          onPressed: _lines.isEmpty ? null : () => _save(context, purchase),
          child: const Text('Simpan'),
        ),
      ],
    );
  }

  Future<void> _loadPurchases([String search = '']) async {
    final controller = AppScope.of(context);
    final trimmed = search.trim();
    final query = {
      'mode': 'return-picker',
      if (trimmed.isNotEmpty) 'search': trimmed,
    };
    await controller.loadFeatureRecords(
      '/api/purchases',
      query: query,
      force: true,
    );
    if (!mounted) return;
    final purchases = controller.featureRecords('/api/purchases');
    final preferredId =
        _purchaseId ?? (widget.record?.values['purchase_id'] as num?)?.toInt();
    final nextId = purchases.any((record) => record.id == preferredId)
        ? preferredId
        : (purchases.isEmpty ? null : purchases.first.id);
    setState(() {
      if (_purchaseId != nextId) {
        _purchaseId = nextId;
        _replaceLines(const []);
      }
    });
  }

  void _syncPurchaseLines(FeatureRecord? purchase) {
    if (_lines.isNotEmpty || purchase == null) return;
    final items = purchase.values['items'];
    if (items is! List) return;
    final returnedItems = _returnedItemsByProduct(widget.record);
    _replaceLines(
      items
          .whereType<Map>()
          .map((item) {
            final map = item.cast<String, Object?>();
            return _ReturnLineDraft(
              productId: (map['product_id'] as num).toInt(),
              productName:
                  (map['nama_produk'] ?? map['product_name'] ?? 'Produk')
                      .toString(),
              maxQuantity: (map['quantity'] as num).toInt(),
              unitPrice: _number(map['unit_price']),
              initialQuantity:
                  returnedItems[(map['product_id'] as num).toInt()] ?? 0,
            );
          })
          .toList(growable: false),
    );
  }

  Future<void> _save(BuildContext context, FeatureRecord? purchase) async {
    if (purchase == null) return;
    final controller = AppScope.of(context);
    final items = _lines
        .map((line) => line.toBody())
        .where((item) => (item['quantity'] as int) > 0)
        .toList(growable: false);
    if (items.isEmpty) return;
    await controller.saveFeatureRecord('/api/purchase-returns', {
      'purchase_id': purchase.id,
      'supplier_id': purchase.values['supplier_id'],
      'items': items,
      'keterangan': _note.text.trim(),
    }, id: widget.record?.id);
    if (context.mounted) Navigator.of(context).pop();
  }

  void _replaceLines(List<_ReturnLineDraft> lines) {
    for (final line in _lines) {
      line.dispose();
    }
    _lines = lines;
  }
}

class _SalesReturnDialog extends StatefulWidget {
  const _SalesReturnDialog({this.record});

  final FeatureRecord? record;

  @override
  State<_SalesReturnDialog> createState() => _SalesReturnDialogState();
}

class _SalesReturnDialogState extends State<_SalesReturnDialog> {
  late final TextEditingController _note = TextEditingController(
    text: widget.record?.values['keterangan']?.toString() ?? '',
  );
  int? _transactionId;
  List<_ReturnLineDraft> _lines = [];
  bool _loadedTransactions = false;

  @override
  void dispose() {
    _note.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loadedTransactions) return;
    _loadedTransactions = true;
    Future.microtask(_loadTransactions);
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final transactions = controller.featureRecords('/api/transactions');
    final transaction = transactions
        .where((record) => record.id == _transactionId)
        .firstOrNull;
    _syncSalesLines(transaction);

    return AlertDialog(
      title: Text(
        widget.record == null
            ? 'Tambah Retur Penjualan'
            : 'Edit Retur Penjualan',
      ),
      content: SizedBox(
        width: 640,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ReferenceDropdown(
                value: _transactionId,
                label: 'Penjualan',
                emptyText: 'Tidak Ada Penjualan Hari Ini',
                entries: [
                  for (final transaction in transactions)
                    _ReferenceEntry(
                      id: transaction.id,
                      label: _salesLabel(transaction),
                    ),
                ],
                onChanged: (value) {
                  setState(() {
                    _transactionId = value;
                    _replaceLines(const []);
                  });
                },
              ),
              const SizedBox(height: 12),
              for (final line in _lines)
                _ReturnLineEditor(line: line, onChanged: () => setState(() {})),
              const SizedBox(height: 8),
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
          onPressed: _lines.isEmpty ? null : () => _save(context, transaction),
          child: const Text('Simpan'),
        ),
      ],
    );
  }

  Future<void> _loadTransactions([String search = '']) async {
    final controller = AppScope.of(context);
    final trimmed = search.trim();
    final query = {
      'mode': 'return-picker',
      if (trimmed.isNotEmpty) 'search': trimmed,
    };
    await controller.loadFeatureRecords(
      '/api/transactions',
      query: query,
      force: true,
    );
    if (!mounted) return;
    final transactions = controller.featureRecords('/api/transactions');
    final preferredId =
        _transactionId ??
        (widget.record?.values['transaction_id'] as num?)?.toInt();
    final nextId = transactions.any((record) => record.id == preferredId)
        ? preferredId
        : (transactions.isEmpty ? null : transactions.first.id);
    setState(() {
      if (_transactionId != nextId) {
        _transactionId = nextId;
        _replaceLines(const []);
      }
    });
  }

  void _syncSalesLines(FeatureRecord? transaction) {
    if (_lines.isNotEmpty || transaction == null) return;
    final returnedItems = _returnedItemsByProduct(widget.record);
    final items = transaction.values['items'];
    if (items is! List) return;
    _replaceLines(
      items
          .whereType<Map>()
          .map((item) {
            final map = item.cast<String, Object?>();
            final productId = (map['product_id'] as num).toInt();
            return _ReturnLineDraft(
              productId: productId,
              productName:
                  (map['nama_produk'] ?? map['product_name'] ?? 'Produk')
                      .toString(),
              maxQuantity: (map['jumlah_beli'] as num).toInt(),
              unitPrice: _number(map['harga_satuan']),
              initialQuantity: returnedItems[productId] ?? 0,
            );
          })
          .toList(growable: false),
    );
  }

  Future<void> _save(BuildContext context, FeatureRecord? transaction) async {
    if (transaction == null) return;
    final controller = AppScope.of(context);
    final items = _lines
        .map((line) => line.toBody())
        .where((item) => (item['quantity'] as int) > 0)
        .toList(growable: false);
    if (items.isEmpty) return;
    await controller.saveFeatureRecord('/api/sales-returns', {
      'transaction_id': transaction.id,
      'customer_id': transaction.values['customer_id'],
      'items': items,
      'keterangan': _note.text.trim(),
    }, id: widget.record?.id);
    if (context.mounted) Navigator.of(context).pop();
  }

  void _replaceLines(List<_ReturnLineDraft> lines) {
    for (final line in _lines) {
      line.dispose();
    }
    _lines = lines;
  }
}

class _ReferenceEntry {
  const _ReferenceEntry({required this.id, required this.label});

  final int id;
  final String label;
}

class _ReferenceDropdown extends StatelessWidget {
  const _ReferenceDropdown({
    required this.value,
    required this.label,
    required this.emptyText,
    required this.entries,
    required this.onChanged,
  });

  final int? value;
  final String label;
  final String emptyText;
  final List<_ReferenceEntry> entries;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final currentValue = entries.any((entry) => entry.id == value)
        ? value
        : null;
    if (entries.isEmpty) {
      return InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(emptyText, overflow: TextOverflow.ellipsis),
      );
    }
    return SearchableDropdown<int?>(
      key: ValueKey('$label-$currentValue-${entries.length}'),
      label: label,
      value: currentValue,
      choices: [
        for (final entry in entries)
          DropdownChoice<int?>(value: entry.id, label: entry.label),
      ],
      onChanged: onChanged,
    );
  }
}

class _ReturnLineDraft {
  _ReturnLineDraft({
    required this.productId,
    required this.productName,
    required this.maxQuantity,
    required this.unitPrice,
    int initialQuantity = 0,
  }) : quantity = TextEditingController(
         text: initialQuantity.clamp(0, maxQuantity).toString(),
       );

  final int productId;
  final String productName;
  final int maxQuantity;
  final double unitPrice;
  final TextEditingController quantity;

  Map<String, Object?> toBody() {
    final qty = int.tryParse(quantity.text.trim()) ?? 0;
    return {
      'product_id': productId,
      'quantity': qty.clamp(0, maxQuantity),
      'unit_price': unitPrice,
    };
  }

  void dispose() => quantity.dispose();
}

class _ReturnLineEditor extends StatelessWidget {
  const _ReturnLineEditor({required this.line, required this.onChanged});

  final _ReturnLineDraft line;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line.productName),
                Text('${rupiah(line.unitPrice)} / Maks ${line.maxQuantity}'),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 88,
            child: TextField(
              controller: line.quantity,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Qty'),
              onChanged: (_) => onChanged(),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReturnItemRows extends StatelessWidget {
  const _ReturnItemRows({required this.items});

  final List<Object?> items;

  @override
  Widget build(BuildContext context) {
    final rows = items
        .whereType<Map>()
        .map((item) => item.cast<String, Object?>())
        .toList(growable: false);
    if (rows.isEmpty) return const Text('Detail item tidak tersedia.');
    return Column(
      children: [
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
                Text((item['nama_produk'] ?? 'Produk').toString()),
                const SizedBox(height: 4),
                Text(
                  '${item['quantity'] ?? '-'} x ${rupiah(_number(item['unit_price']))}',
                ),
                Text('Total ${rupiah(_number(item['subtotal']))}'),
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
            width: 104,
            child: Text(label, style: Theme.of(context).textTheme.labelMedium),
          ),
          Expanded(child: Text(value, textAlign: TextAlign.end)),
        ],
      ),
    );
  }
}

String _purchaseLabel(FeatureRecord record) {
  final date = DateTime.tryParse(record.values['created_at']?.toString() ?? '');
  final supplier = record.values['supplier_name'] ?? 'Tanpa Suplier';
  final products = record.values['bought_products']?.toString() ?? '';
  final suffix = products.trim().isEmpty
      ? rupiah(_number(record.values['total']))
      : products;
  return '#${record.id} - $supplier - ${date == null ? '-' : shortDate(date.toLocal())} - $suffix';
}

String _salesLabel(FeatureRecord record) {
  final date = DateTime.tryParse(record.values['created_at']?.toString() ?? '');
  final customer = record.values['customer_name'] ?? 'Umum';
  final products = _salesProducts(record);
  final suffix = products.isEmpty
      ? rupiah(_number(record.values['total_akhir']))
      : products;
  return '#${record.id} - $customer - ${date == null ? '-' : shortDate(date.toLocal())} - $suffix';
}

String _salesProducts(FeatureRecord record) {
  final items = record.values['items'];
  if (items is! List) return '';
  return items
      .whereType<Map>()
      .map((item) {
        final name = item['nama_produk'] ?? item['product_name'] ?? 'Produk';
        final quantity = item['jumlah_beli'] ?? item['quantity'] ?? '-';
        return '$name x$quantity';
      })
      .join(', ');
}

String _dateOnly(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}

double _number(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

Map<int, int> _returnedItemsByProduct(FeatureRecord? record) {
  final items = record?.values['items'];
  if (items is! List) return const {};
  return {
    for (final item in items.whereType<Map>())
      if ((item['product_id'] as num?) != null)
        (item['product_id'] as num).toInt():
            ((item['quantity'] as num?)?.toInt() ?? 0),
  };
}
