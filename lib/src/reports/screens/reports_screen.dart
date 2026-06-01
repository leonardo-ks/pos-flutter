import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../reports/models/sale_transaction.dart';
import '../../reports/models/sales_report.dart';
import '../../reports/models/transaction_item.dart';
import '../../reports/repositories/report_repository.dart';
import '../../shared/file_download/file_download.dart';
import '../../shared/formatters.dart';
import '../../shared/models/feature_record.dart';
import '../../shared/printing/receipt_printer.dart';
import '../../shared/widgets/app_tab_scaffold.dart';
import '../../shared/widgets/debounced_text_field.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/fast_date_range_picker.dart';
import '../../shared/widgets/searchable_dropdown.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    if (!controller.canManage) {
      return const EmptyState(
        icon: Icons.lock,
        title: 'Akses Ditolak',
        message: 'Laporan penjualan hanya tersedia untuk Manajer.',
      );
    }

    return AppTabScaffold(
      emptyMessage: 'Tidak Ada Laporan.',
      tabs: [
        for (final tab in _reportTabs)
          AppTabItem(
            label: tab.$2,
            child: _GenericReportTab(tab: tab),
          ),
      ],
    );
  }
}

const _reportTabs = [
  ('all-transactions', 'Penjualan/Pembelian'),
  ('returns', 'Retur'),
];

class _GenericReportTab extends StatefulWidget {
  const _GenericReportTab({required this.tab});

  final (String, String) tab;

  @override
  State<_GenericReportTab> createState() => _GenericReportTabState();
}

class _GenericReportTabState extends State<_GenericReportTab> {
  bool _loaded = false;
  bool _filtersCollapsed = false;
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
      Future.microtask(() => controller.loadGenericReport(widget.tab.$1));
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final path = '/api/reports/${widget.tab.$1}';
    final rows = controller.featureRecords(path);

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.axis != Axis.vertical) return false;
        final shouldCollapse = notification.metrics.pixels > 20;
        if (shouldCollapse != _filtersCollapsed) {
          setState(() => _filtersCollapsed = shouldCollapse);
        }
        return false;
      },
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: _filtersCollapsed
                  ? Padding(
                      key: const ValueKey('collapsed'),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              setState(() => _filtersCollapsed = false),
                          icon: const Icon(Icons.filter_list),
                          label: const Text('Filter'),
                        ),
                      ),
                    )
                  : Padding(
                      key: const ValueKey('expanded'),
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: _ReportControls(
                          onExport: _exportExcel,
                          reportKind: widget.tab.$1,
                        ),
                      ),
                    ),
            ),
          ),
          if (!_filtersCollapsed)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: DebouncedTextField(
                  controller: _filterController,
                  onChanged: (value) {
                    setState(() => _filter = value);
                    controller.loadGenericReport(widget.tab.$1, search: value);
                  },
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'Cari Laporan',
                    suffixIcon: _filter.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Bersihkan',
                            onPressed: () {
                              _filterController.clear();
                              setState(() => _filter = '');
                              controller.loadGenericReport(widget.tab.$1);
                            },
                            icon: const Icon(Icons.close),
                          ),
                  ),
                ),
              ),
            ),
          if (controller.isBusy && rows.isEmpty)
            const SliverToBoxAdapter(
              child: SizedBox(
                height: 360,
                child: Center(child: CircularProgressIndicator()),
              ),
            )
          else if (rows.isEmpty)
            const SliverToBoxAdapter(
              child: SizedBox(
                height: 360,
                child: EmptyState(
                  icon: Icons.search_off,
                  title: 'Tidak Ada Data',
                  message: 'Data laporan tidak ditemukan pada filter ini.',
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList.separated(
                itemCount:
                    rows.length +
                    (controller.canLoadMoreFeatureRecords(
                          path,
                          query: controller.reportQueryFor(
                            widget.tab.$1,
                            search: _filter,
                          ),
                        )
                        ? 1
                        : 0),
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  if (index == rows.length) {
                    return SizedBox(
                      width: double.infinity,
                      child: Center(
                        child: OutlinedButton.icon(
                          onPressed: controller.isBusy
                              ? null
                              : () => controller.loadMoreGenericReport(
                                  widget.tab.$1,
                                  search: _filter,
                                ),
                          icon: const Icon(Icons.expand_more),
                          label: const Text('Muat Lagi'),
                        ),
                      ),
                    );
                  }
                  return _GenericReportCard(
                    row: rows[index].values,
                    icon: _reportIcon(widget.tab.$1),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _exportExcel(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final controller = AppScope.of(context);
    final bytes = await controller.exportGenericReport(
      widget.tab.$1,
      search: _filter,
    );
    if (bytes == null || bytes.isEmpty) return;
    final savedPath = await saveExcelFile(
      name: 'laporan-${widget.tab.$1}',
      bytes: Uint8List.fromList(bytes),
    );
    messenger.showSnackBar(
      SnackBar(content: Text('Excel tersimpan: $savedPath')),
    );
  }
}

// ignore: unused_element
class _PurchaseSummary extends StatelessWidget {
  const _PurchaseSummary({required this.rows});

  final List<FeatureRecord> rows;

  @override
  Widget build(BuildContext context) {
    final total = rows.fold<double>(
      0,
      (sum, record) => sum + _number(record.values['total']),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 700 ? 2 : 1;
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: columns == 1 ? 3.6 : 2.4,
          children: [
            _MetricCard(
              icon: Icons.shopping_cart_checkout,
              label: 'Total Pembelian',
              value: rupiah(total),
            ),
            _MetricCard(
              icon: Icons.receipt,
              label: 'Transaksi',
              value: '${rows.length}',
            ),
          ],
        );
      },
    );
  }

  double _number(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class _GenericReportCard extends StatelessWidget {
  const _GenericReportCard({required this.row, required this.icon});

  final Map<String, Object?> row;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final title = _rowTitle();
    final meta = _metaText();
    final effectiveIcon = _rowIcon();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _showDetail(context),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(child: Icon(effectiveIcon)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          meta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _ReportDetailPill(
                      label: 'Produk',
                      value: _formatReportValue('products', row['products']),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _ReportDetailPill(
                    label: 'Total',
                    value: _formatReportValue('total', row['total']),
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
    final controller = AppScope.of(context);
    final title = _rowTitle();
    final isSale = row['type']?.toString().toLowerCase() == 'penjualan';
    final transactionId = (row['id'] as num?)?.toInt();
    final saleDetail = isSale && transactionId != null
        ? controller.transactions
              .where((transaction) => transaction.id == transactionId)
              .firstOrNull
        : null;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final entry in row.entries)
                  if (entry.key != 'items' &&
                      entry.value != null &&
                      entry.value.toString().trim().isNotEmpty)
                    _DetailLine(
                      label: _humanizeKey(entry.key),
                      value: _formatReportValue(entry.key, entry.value),
                    ),
                if (row['items'] is List) ...[
                  const SizedBox(height: 10),
                  _ReportItemRows(items: (row['items'] as List).cast()),
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
          if (saleDetail != null)
            FilledButton.icon(
              onPressed: () => printReceipt(saleDetail),
              icon: const Icon(Icons.print),
              label: const Text('Cetak'),
            ),
        ],
      ),
    );
  }

  String _rowTitle() {
    final type = _formatReportValue('type', row['type']);
    return '$type #${row['id'] ?? '-'}';
  }

  IconData _rowIcon() {
    return switch (row['type']?.toString().toLowerCase()) {
      'penjualan' => Icons.point_of_sale,
      'pembelian' => Icons.inventory_2,
      'retur penjualan' => Icons.assignment_returned,
      'retur pembelian' => Icons.assignment_return,
      _ => icon,
    };
  }

  String _metaText() {
    final parts = <String>[];
    for (final key in [
      'partner_name',
      'customer_name',
      'supplier_name',
      'created_at',
    ]) {
      final value = row[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        parts.add(_formatReportValue(key, value));
      }
    }
    if (parts.isEmpty && row['id'] != null) parts.add('ID ${row['id']}');
    return parts.take(2).join(' | ');
  }
}

class _ReportItemRows extends StatelessWidget {
  const _ReportItemRows({required this.items});

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
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    (item['product_name'] ?? item['nama_produk'] ?? 'Produk')
                        .toString(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${item['quantity'] ?? item['jumlah_beli'] ?? '-'} x '
                  '${_formatReportValue('unit_price', item['unit_price'] ?? item['harga_satuan'])}',
                ),
                const SizedBox(width: 12),
                Text(
                  'Total ${_formatReportValue('subtotal', item['subtotal'])}',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ReportDetailPill extends StatelessWidget {
  const _ReportDetailPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 120),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.outlineVariant),
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

IconData _reportIcon(String kind) {
  return switch (kind) {
    'all-transactions' => Icons.swap_horiz,
    'returns' => Icons.assignment_return,
    'purchases' => Icons.inventory_2,
    'stock-list' => Icons.inventory_2,
    'stock-card' => Icons.timeline,
    'payables' => Icons.payments,
    'receivables' => Icons.request_quote,
    'cash-daily' => Icons.account_balance_wallet,
    _ => Icons.table_chart,
  };
}

String _formatReportValue(String key, Object? value) {
  if (value == null) return '-';
  final text = value.toString();
  if (text.isEmpty) return '-';

  final lowerKey = key.toLowerCase();
  final number = value is num ? value : num.tryParse(text);
  final currencyKeys = [
    'amount',
    'total',
    'sales',
    'discount',
    'kas',
    'saldo',
    'paid',
    'remaining',
    'harga',
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

  if (lowerKey == 'status') {
    return switch (text.toLowerCase()) {
      'paid' => 'Lunas',
      'open' => 'Belum Lunas',
      'partial' => 'Sebagian',
      _ => text,
    };
  }

  if (lowerKey == 'type') {
    return switch (text.toLowerCase()) {
      'penjualan' => 'Penjualan',
      'pembelian' => 'Pembelian',
      'retur pembelian' => 'Retur Pembelian',
      'retur penjualan' => 'Retur Penjualan',
      _ => text,
    };
  }

  return text;
}

String _humanizeKey(String key) {
  const labels = {
    'id': 'ID',
    'nama_produk': 'Produk',
    'supplier_name': 'Suplier',
    'partner_name': 'Relasi',
    'customer_name': 'Pelanggan',
    'location_name': 'Lokasi',
    'quantity': 'Qty',
    'gross_sales': 'Bruto',
    'net_sales': 'Neto',
    'discount': 'Diskon',
    'total': 'Total',
    'paid_amount': 'Terbayar',
    'remaining_amount': 'Sisa',
    'status': 'Status',
    'stock': 'Stok',
    'qty_in': 'Masuk',
    'qty_out': 'Keluar',
    'source_type': 'Sumber',
    'kas_masuk': 'Kas Masuk',
    'kas_keluar': 'Kas Keluar',
    'saldo': 'Saldo',
    'tanggal': 'Tanggal',
    'created_at': 'Dibuat',
    'bought_products': 'Produk dibeli',
    'products': 'Produk',
    'type': 'Jenis',
  };
  return labels[key] ?? key.replaceAll('_', ' ');
}

// ignore: unused_element
class _ReportHeader extends StatelessWidget {
  const _ReportHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: _ReportControls(
          onExport: _exportExcel,
          reportKind: 'all-transactions',
        ),
      ),
    );
  }

  Future<void> _exportExcel(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final controller = AppScope.of(context);

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Mengunduh laporan Excel...')),
      );

    try {
      final bytes = await controller.exportSalesReport();
      if (bytes == null || bytes.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Laporan Excel kosong.')),
        );
        return;
      }

      final savedPath = await saveExcelFile(
        name: _exportFilename(),
        bytes: Uint8List.fromList(bytes),
      );

      final message = savedPath.isEmpty
          ? 'Laporan Excel berhasil diunduh.'
          : 'Laporan Excel tersimpan: $savedPath';
      messenger.showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Gagal mengunduh Excel: $error')),
      );
    }
  }

  String _exportFilename() {
    final now = DateTime.now();
    final stamp =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    return 'laporan-penjualan-$stamp';
  }
}

class _ReportControls extends StatelessWidget {
  const _ReportControls({required this.onExport, required this.reportKind});

  final Future<void> Function(BuildContext context) onExport;
  final String reportKind;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 760;
        final categories = controller.featureRecords('/api/product-categories');
        final selectedCategoryId =
            categories.any(
              (category) =>
                  category.id ==
                  controller.selectedReportCategoryIdFor(reportKind),
            )
            ? controller.selectedReportCategoryIdFor(reportKind)!
            : 0;
        final selectedProductId =
            controller.products.any(
              (product) =>
                  product.id ==
                      controller.selectedReportProductIdFor(reportKind) &&
                  (selectedCategoryId == 0 ||
                      product.categoryId == selectedCategoryId),
            )
            ? controller.selectedReportProductIdFor(reportKind)!
            : 0;
        final selectedCustomerId =
            controller.customers.any(
              (customer) =>
                  customer.id ==
                  controller.selectedReportCustomerIdFor(reportKind),
            )
            ? controller.selectedReportCustomerIdFor(reportKind)!
            : 0;
        final suppliers = controller.featureRecords('/api/suppliers');
        final selectedSupplierId =
            suppliers.any(
              (supplier) =>
                  supplier.id ==
                  controller.selectedReportSupplierIdFor(reportKind),
            )
            ? controller.selectedReportSupplierIdFor(reportKind)!
            : 0;
        final selectedRange = controller.reportRangeFor(reportKind);
        final isReturns = reportKind == 'returns';
        final typeValue = controller.selectedReportTypeFor(reportKind);
        final typeFilterVisible =
            reportKind == 'all-transactions' || reportKind == 'returns';
        final showCustomerFilter =
            typeValue == 'penjualan' || typeValue == 'retur penjualan';
        final showSupplierFilter =
            typeValue == 'pembelian' || typeValue == 'retur pembelian';

        final dateControls = [
          SizedBox(
            width: narrow ? double.infinity : 360,
            child: SegmentedButton<ReportRange>(
              showSelectedIcon: false,
              emptySelectionAllowed: true,
              segments: const [
                ButtonSegment(
                  value: ReportRange.today,
                  label: _SegmentLabel('Hari Ini'),
                ),
                ButtonSegment(
                  value: ReportRange.week,
                  label: _SegmentLabel('Minggu Ini'),
                ),
                ButtonSegment(
                  value: ReportRange.month,
                  label: _SegmentLabel('Bulan Ini'),
                ),
              ],
              selected: selectedRange == ReportRange.custom
                  ? const <ReportRange>{}
                  : {selectedRange},
              onSelectionChanged: controller.isBusy
                  ? null
                  : (value) async {
                      if (value.isEmpty) return;
                      final selected = value.first;
                      await controller.setReportRange(
                        selected,
                        kind: reportKind,
                      );
                    },
            ),
          ),
          SizedBox(
            width: narrow ? double.infinity : 236,
            child: OutlinedButton.icon(
              onPressed: controller.isBusy ? null : () => _pickRange(context),
              icon: const Icon(Icons.calendar_month),
              label: Text(
                _rangeLabel(controller.customReportRangeFor(reportKind)),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          SizedBox(
            width: narrow ? double.infinity : 102,
            child: FilledButton.icon(
              onPressed: controller.isBusy ? null : () => onExport(context),
              icon: const Icon(Icons.download),
              label: const Text('Excel'),
            ),
          ),
        ];

        final relationControls = [
          if (typeFilterVisible)
            SizedBox(
              width: narrow ? double.infinity : 220,
              child: SearchableDropdown<String>(
                label: 'Tipe',
                value: typeValue,
                prefixIcon: Icons.swap_vert,
                choices: isReturns
                    ? const [
                        DropdownChoice(value: 'all', label: 'Semua Retur'),
                        DropdownChoice(
                          value: 'retur penjualan',
                          label: 'Retur Penjualan',
                        ),
                        DropdownChoice(
                          value: 'retur pembelian',
                          label: 'Retur Pembelian',
                        ),
                      ]
                    : const [
                        DropdownChoice(value: 'all', label: 'Semua Tipe'),
                        DropdownChoice(value: 'penjualan', label: 'Penjualan'),
                        DropdownChoice(value: 'pembelian', label: 'Pembelian'),
                      ],
                onChanged: controller.isBusy
                    ? null
                    : (value) {
                        if (isReturns) {
                          controller.setReturnReportType(value);
                        } else {
                          controller.setCombinedReportType(value);
                        }
                      },
              ),
            ),
          if (showCustomerFilter)
            SizedBox(
              width: narrow ? double.infinity : 220,
              child: SearchableDropdown<int>(
                label: 'Pelanggan',
                value: selectedCustomerId,
                prefixIcon: Icons.people,
                choices: [
                  const DropdownChoice(value: 0, label: 'Semua Pelanggan'),
                  for (final customer in controller.customers)
                    DropdownChoice(value: customer.id, label: customer.name),
                ],
                onChanged: controller.isBusy
                    ? null
                    : (value) => controller.setReportCustomerFilter(
                        value == 0 ? null : value,
                        kind: reportKind,
                      ),
              ),
            ),
          if (showSupplierFilter)
            SizedBox(
              width: narrow ? double.infinity : 220,
              child: SearchableDropdown<int>(
                label: 'Suplier',
                value: selectedSupplierId,
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
                    : (value) => controller.setReportSupplierFilter(
                        value == 0 ? null : value,
                        kind: reportKind,
                      ),
              ),
            ),
        ];

        final itemControls = [
          SizedBox(
            width: narrow ? double.infinity : 220,
            child: SearchableDropdown<int>(
              label: 'Grup Item',
              value: selectedCategoryId,
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
                  : (value) async {
                      await controller.setReportCategoryFilter(
                        value == 0 ? null : value,
                        kind: reportKind,
                      );
                      await controller.setReportProductFilter(
                        null,
                        kind: reportKind,
                      );
                    },
            ),
          ),
          if (selectedCategoryId != 0)
            SizedBox(
              width: narrow ? double.infinity : 220,
              child: SearchableDropdown<int>(
                label: 'Item',
                value: selectedProductId,
                prefixIcon: Icons.inventory_2,
                choices: [
                  const DropdownChoice(value: 0, label: 'Semua Item'),
                  for (final product in controller.products.where(
                    (product) => product.categoryId == selectedCategoryId,
                  ))
                    DropdownChoice(value: product.id, label: product.name),
                ],
                onChanged: controller.isBusy
                    ? null
                    : (value) => controller.setReportProductFilter(
                        value == 0 ? null : value,
                        kind: reportKind,
                      ),
              ),
            ),
        ];

        return ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: narrow ? double.infinity : 1180,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ControlRow(children: dateControls),
              const SizedBox(height: 8),
              if (relationControls.isNotEmpty) ...[
                _ControlRow(children: relationControls),
                const SizedBox(height: 8),
              ],
              _ControlRow(children: itemControls),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickRange(BuildContext context) async {
    final controller = AppScope.of(context);
    final now = DateTime.now();
    final selected = await showFastDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 1),
      initialDateRange:
          controller.customReportRangeFor(reportKind) ??
          DateTimeRange(
            start: DateTime(now.year, now.month, now.day),
            end: DateTime(now.year, now.month, now.day),
          ),
    );
    if (selected != null) {
      controller.setCustomReportRange(selected, kind: reportKind);
    }
  }

  String _rangeLabel(DateTimeRange? range) {
    if (range == null) return 'Pilih tanggal';
    return '${_dateOnlyText(range.start)} - ${_dateOnlyText(range.end)}';
  }
}

class _ControlRow extends StatelessWidget {
  const _ControlRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: children,
    );
  }
}

class _RangePickerDialog extends StatefulWidget {
  const _RangePickerDialog({
    required this.initialRange,
    required this.firstDate,
    required this.lastDate,
  });

  final DateTimeRange initialRange;
  final DateTime firstDate;
  final DateTime lastDate;

  @override
  State<_RangePickerDialog> createState() => _RangePickerDialogState();
}

class _RangePickerDialogState extends State<_RangePickerDialog> {
  late DateTime _start = widget.initialRange.start;
  late DateTime _end = widget.initialRange.end;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Pilih Rentang'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${_dateOnlyText(_start)} - ${_dateOnlyText(_end)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            CalendarDatePicker(
              initialDate: _end,
              firstDate: widget.firstDate,
              lastDate: widget.lastDate,
              onDateChanged: (date) {
                setState(() {
                  if (!_start.isAtSameMomentAs(_end) || date.isBefore(_start)) {
                    _start = date;
                    _end = date;
                  } else {
                    _end = date;
                    if (_end.isBefore(_start)) _start = _end;
                  }
                });
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(
            context,
          ).pop(DateTimeRange(start: _start, end: _end)),
          child: const Text('Terapkan'),
        ),
      ],
    );
  }
}

String _dateOnlyText(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}

class _SegmentLabel extends StatelessWidget {
  const _SegmentLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: 72, child: Text(text, textAlign: TextAlign.center));
  }
}

// ignore: unused_element
class _ReportContent extends StatelessWidget {
  const _ReportContent({required this.report});

  final SalesReport report;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 900 ? 3 : 1;
            return GridView.count(
              crossAxisCount: columns,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: columns == 1 ? 3.6 : 2.4,
              children: [
                _MetricCard(
                  icon: Icons.payments,
                  label: 'Pendapatan',
                  value: rupiah(report.revenue),
                ),
                _MetricCard(
                  icon: Icons.receipt,
                  label: 'Transaksi',
                  value: '${report.transactionCount}',
                ),
                _MetricCard(
                  icon: Icons.shopping_bag,
                  label: 'Barang Terjual',
                  value: '${report.itemCount}',
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Produk Terlaris',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                _TopProductChart(data: report.topProducts),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Riwayat Transaksi',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        for (final transaction in report.recentTransactions)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              child: ListTile(
                onTap: () {
                  final detail = controller.transactions
                      .where((item) => item.id == transaction.id)
                      .firstOrNull;
                  showDialog<void>(
                    context: context,
                    builder: (_) => _TransactionDetailDialog(
                      transaction: detail,
                      fallback: transaction,
                    ),
                  );
                },
                leading: const CircleAvatar(child: Icon(Icons.receipt_long)),
                title: Text(
                  '#${transaction.id} - ${rupiah(transaction.totalFinal)}',
                ),
                subtitle: Text(
                  '${shortDate(transaction.time)} - '
                  '${transaction.customerName ?? 'Umum'}',
                ),
                trailing: Text(transaction.cashierName),
              ),
            ),
          ),
      ],
    );
  }
}

class _TransactionDetailDialog extends StatelessWidget {
  const _TransactionDetailDialog({
    required this.transaction,
    required this.fallback,
  });

  final SaleTransaction? transaction;
  final RecentSale fallback;

  @override
  Widget build(BuildContext context) {
    final detail = transaction;
    return AlertDialog(
      title: Text('Transaksi #${fallback.id}'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DetailLine(label: 'Tanggal', value: shortDate(fallback.time)),
              _DetailLine(
                label: 'Pelanggan',
                value:
                    detail?.customer?.name ?? fallback.customerName ?? 'Umum',
              ),
              _DetailLine(label: 'Kasir', value: fallback.cashierName),
              const SizedBox(height: 12),
              if (detail == null || detail.items.isEmpty)
                const Text('Detail item tidak tersedia.')
              else
                _SaleItemRows(items: detail.items),
              const Divider(),
              if (detail != null) ...[
                _DetailLine(
                  label: 'Subtotal',
                  value: rupiah(detail.totalBeforeDiscount),
                ),
                _DetailLine(label: 'Diskon', value: rupiah(detail.discount)),
              ],
              _DetailLine(
                label: 'Total',
                value: rupiah(detail?.totalFinal ?? fallback.totalFinal),
              ),
              if (detail?.paymentMethod == 'cash') ...[
                _DetailLine(
                  label: 'Uang Diterima',
                  value: rupiah(detail?.cashReceived ?? 0),
                ),
                _DetailLine(
                  label: 'Kembalian',
                  value: rupiah(detail?.changeAmount ?? 0),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Tutup'),
        ),
        if (detail != null)
          FilledButton.icon(
            onPressed: () => printReceipt(detail),
            icon: const Icon(Icons.print),
            label: const Text('Cetak'),
          ),
      ],
    );
  }
}

class _SaleItemRows extends StatelessWidget {
  const _SaleItemRows({required this.items});

  final List<TransactionItem> items;

  @override
  Widget build(BuildContext context) {
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
        for (final item in items)
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
                    item.productName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                Text('${item.quantity} x ${rupiah(item.unitPrice)}'),
                const SizedBox(width: 12),
                Text(
                  rupiah(item.subtotal),
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
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(width: 92, child: Text(label)),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(child: Icon(icon)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label),
                  Text(value, style: Theme.of(context).textTheme.headlineSmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopProductChart extends StatelessWidget {
  const _TopProductChart({required this.data});

  final List<TopProduct> data;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const SizedBox(
        height: 120,
        child: EmptyState(
          icon: Icons.bar_chart,
          title: 'Tidak Ada Data',
          message: 'Belum Ada Produk Terjual Pada Filter Ini.',
        ),
      );
    }

    final maxValue = data
        .map((product) => product.quantitySold)
        .reduce((a, b) => a > b ? a : b);

    return Column(
      children: [
        for (final product in data)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 150,
                  child: Text(product.name, overflow: TextOverflow.ellipsis),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      minHeight: 18,
                      value: product.quantitySold / maxValue,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 32,
                  child: Text(
                    '${product.quantitySold}',
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
