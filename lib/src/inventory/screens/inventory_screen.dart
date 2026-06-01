import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../app/app_scope.dart';
import '../../shared/formatters.dart';
import '../../shared/models/feature_record.dart';
import '../../shared/widgets/debounced_text_field.dart';
import '../../shared/widgets/feature_table_screen.dart';
import '../../shared/widgets/searchable_dropdown.dart';
import '../models/product.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  bool _loadedFeatureData = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loadedFeatureData) {
      _loadedFeatureData = true;
      final controller = AppScope.of(context);
      Future.microtask(() async {
        await controller.loadFeatureRecords('/api/stock');
        await controller.loadFeatureRecords('/api/locations');
        await controller.loadFeatureRecords('/api/product-categories');
        await controller.loadFeatureRecords('/api/suppliers');
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final canCreate = controller.canCreateMenu('inventory');
    final canUpdate = controller.canUpdateMenu('inventory');
    final canDelete = controller.canDeleteMenu('inventory');
    final products = controller.products;
    final stockRecords = controller.featureRecords('/api/stock');

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        body: Column(
          children: [
            const TabBar(
              tabs: [
                Tab(text: 'Produk'),
                Tab(text: 'Grup Produk'),
                Tab(text: 'Lokasi/Gudang'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final compact = constraints.maxWidth < 560;
                            final search = DebouncedTextField(
                              controller: _searchController,
                              onChanged: (value) {
                                setState(() => _query = value);
                                controller.setProductSearch(value);
                              },
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.search),
                                hintText:
                                    'Cari produk, SKU, grup produk, atau suplier',
                                suffixIcon: _query.isEmpty
                                    ? null
                                    : IconButton(
                                        tooltip: 'Bersihkan',
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() => _query = '');
                                          controller.setProductSearch('');
                                        },
                                        icon: const Icon(Icons.close),
                                      ),
                              ),
                            );
                            final addButton = FilledButton.icon(
                              onPressed: canCreate && !controller.isBusy
                                  ? () => _showProductDialog(context)
                                  : null,
                              icon: const Icon(Icons.add),
                              label: const Text('Produk'),
                            );

                            if (!canCreate) return search;
                            if (compact) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  search,
                                  const SizedBox(height: 8),
                                  addButton,
                                ],
                              );
                            }

                            return Row(
                              children: [
                                Expanded(child: search),
                                const SizedBox(width: 12),
                                addButton,
                              ],
                            );
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final categories = controller.featureRecords(
                              '/api/product-categories',
                            );
                            final locations = controller.featureRecords(
                              '/api/locations',
                            );
                            final compact = constraints.maxWidth < 820;
                            final groupFilter = SearchableDropdown<int?>(
                              label: 'Grup Produk',
                              value: controller.selectedProductCategoryFilterId,
                              prefixIcon: Icons.category,
                              choices: [
                                const DropdownChoice<int?>(
                                  value: null,
                                  label: 'Semua Grup',
                                ),
                                for (final category in categories)
                                  DropdownChoice<int?>(
                                    value: category.id,
                                    label: category.label(const [
                                      'nama',
                                      'kode',
                                    ]),
                                  ),
                              ],
                              onChanged: controller.isBusy
                                  ? null
                                  : controller.setProductCategoryFilter,
                            );
                            final stockFilter = SearchableDropdown<String>(
                              label: 'Stok',
                              value: controller.selectedProductStockFilter,
                              prefixIcon: Icons.inventory_2,
                              choices: const [
                                DropdownChoice(
                                  value: 'all',
                                  label: 'Semua Stok',
                                ),
                                DropdownChoice(
                                  value: 'available',
                                  label: 'Stok Aman',
                                ),
                                DropdownChoice(
                                  value: 'low',
                                  label: 'Stok Rendah',
                                ),
                                DropdownChoice(
                                  value: 'empty',
                                  label: 'Stok Kosong',
                                ),
                              ],
                              onChanged: controller.isBusy
                                  ? null
                                  : controller.setProductStockFilter,
                            );
                            final locationFilter = SearchableDropdown<int?>(
                              label: 'Lokasi/Gudang',
                              value: controller.selectedProductLocationFilterId,
                              prefixIcon: Icons.warehouse,
                              choices: [
                                const DropdownChoice<int?>(
                                  value: null,
                                  label: 'Semua Lokasi/Gudang',
                                ),
                                for (final location in locations)
                                  DropdownChoice<int?>(
                                    value: location.id,
                                    label: location.label(const [
                                      'nama',
                                      'kode',
                                    ]),
                                  ),
                              ],
                              onChanged: controller.isBusy
                                  ? null
                                  : controller.setProductLocationFilter,
                            );
                            if (compact) {
                              return Column(
                                children: [
                                  groupFilter,
                                  const SizedBox(height: 8),
                                  locationFilter,
                                  const SizedBox(height: 8),
                                  stockFilter,
                                ],
                              );
                            }
                            return Row(
                              children: [
                                Expanded(child: groupFilter),
                                const SizedBox(width: 12),
                                Expanded(child: locationFilter),
                                const SizedBox(width: 12),
                                Expanded(child: stockFilter),
                              ],
                            );
                          },
                        ),
                      ),
                      Expanded(
                        child: products.isEmpty
                            ? const Center(
                                child: Text('Produk Tidak Ditemukan.'),
                              )
                            : CustomScrollView(
                                slivers: [
                                  SliverPadding(
                                    padding: const EdgeInsets.all(16),
                                    sliver: SliverGrid.builder(
                                      addAutomaticKeepAlives: false,
                                      addSemanticIndexes: false,
                                      gridDelegate:
                                          const SliverGridDelegateWithMaxCrossAxisExtent(
                                            maxCrossAxisExtent: 360,
                                            mainAxisExtent: 210,
                                            crossAxisSpacing: 12,
                                            mainAxisSpacing: 12,
                                          ),
                                      itemCount: products.length,
                                      itemBuilder: (context, index) {
                                        final product = products[index];
                                        final stocks = _stocksForProduct(
                                          product,
                                          stockRecords,
                                        );
                                        return RepaintBoundary(
                                          child: _InventoryCard(
                                            product: product,
                                            canUpdate: canUpdate,
                                            canDelete: canDelete,
                                            onTap: () => _showProductDetail(
                                              context,
                                              product,
                                              stocks,
                                            ),
                                            onEdit: () => _showProductDialog(
                                              context,
                                              product: product,
                                            ),
                                            onDelete: () =>
                                                _confirmDeleteProduct(
                                                  context,
                                                  product,
                                                ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  if (controller.canLoadMoreProducts)
                                    SliverToBoxAdapter(
                                      child: Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          16,
                                          0,
                                          16,
                                          16,
                                        ),
                                        child: SizedBox(
                                          width: double.infinity,
                                          child: Center(
                                            child: OutlinedButton.icon(
                                              onPressed: controller.isBusy
                                                  ? null
                                                  : controller.loadMoreProducts,
                                              icon: const Icon(
                                                Icons.expand_more,
                                              ),
                                              label: const Text('Muat Lagi'),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                      ),
                    ],
                  ),
                  const FeatureTableScreen(
                    title: 'Grup Produk',
                    subtitle: 'Kelola grup atau kategori produk.',
                    path: '/api/product-categories',
                    showHeader: false,
                    fields: [
                      FeatureField('kode', 'Kode'),
                      FeatureField('nama', 'Nama'),
                      FeatureField('keterangan', 'Keterangan'),
                    ],
                    labelKeys: ['nama'],
                  ),
                  const FeatureTableScreen(
                    title: 'Lokasi/Gudang',
                    subtitle: 'Kelola gudang atau lokasi penyimpanan.',
                    path: '/api/locations',
                    showHeader: false,
                    fields: [
                      FeatureField('kode', 'Kode'),
                      FeatureField('nama', 'Nama'),
                      FeatureField('keterangan', 'Keterangan'),
                    ],
                    labelKeys: ['nama'],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<FeatureRecord> _stocksForProduct(
    Product product,
    List<FeatureRecord> records,
  ) {
    return records
        .where((record) {
          final productId = (record.values['product_id'] as num?)?.toInt();
          return productId == product.id;
        })
        .toList(growable: false);
  }

  Future<void> _showProductDialog(
    BuildContext context, {
    Product? product,
  }) async {
    final controller = AppScope.of(context);
    final name = TextEditingController(text: product?.name ?? '');
    final sku = TextEditingController(text: product?.sku ?? '');
    final price = TextEditingController(
      text: product == null ? '' : product.price.round().toString(),
    );
    final purchasePrice = TextEditingController(
      text: product == null ? '' : product.purchasePrice.round().toString(),
    );
    final description = TextEditingController(text: product?.description ?? '');
    final supplierId = TextEditingController(
      text: product?.supplierId?.toString() ?? '',
    );
    final categoryId = TextEditingController(
      text: product?.categoryId?.toString() ?? '',
    );
    final locations = controller.featureRecords('/api/locations');
    final draftStocks = <_DraftLocationStock>[];

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(product == null ? 'Tambah Produk' : 'Edit Produk'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 460, maxHeight: 620),
            child: StatefulBuilder(
              builder: (context, setDialogState) {
                return SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: name,
                        decoration: const InputDecoration(
                          labelText: 'Nama Produk',
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: sku,
                              decoration: const InputDecoration(
                                labelText: 'SKU / Barcode',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filledTonal(
                            tooltip: 'Scan Barcode',
                            onPressed: () async {
                              final code = await _scanBarcode(context);
                              if (code != null && code.trim().isNotEmpty) {
                                sku.text = code.trim();
                              }
                            },
                            icon: const Icon(Icons.qr_code_scanner),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: description,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Keterangan',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: price,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Harga Jual',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: purchasePrice,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Harga Beli',
                        ),
                      ),
                      const SizedBox(height: 10),
                      _ReferenceDropdown(
                        controller: supplierId,
                        label: 'Suplier',
                        records: controller.featureRecords('/api/suppliers'),
                        labelKeys: const ['nama', 'kode'],
                      ),
                      const SizedBox(height: 10),
                      _ReferenceDropdown(
                        controller: categoryId,
                        label: 'Grup Produk',
                        records: controller.featureRecords(
                          '/api/product-categories',
                        ),
                        labelKeys: const ['nama', 'kode'],
                      ),
                      if (product != null) ...[
                        const SizedBox(height: 16),
                        _ProductStockEditor(
                          product: product,
                          stocksForProduct: _stocksForProduct,
                          hasStock: _hasStock,
                          onSaveStock: (locationId, value) =>
                              _saveLocationStock(
                                context,
                                productId: product.id,
                                locationId: locationId,
                                stock: value,
                              ),
                          onAddStock: (stocks) => _showStockDialog(
                            context,
                            product: product,
                            stocks: stocks,
                          ),
                        ),
                      ] else ...[
                        const SizedBox(height: 16),
                        _NewProductStockEditor(
                          locations: locations,
                          stocks: draftStocks,
                          onAddStock: () async {
                            final draft = await _showDraftStockDialog(
                              context,
                              locations: locations,
                              stocks: draftStocks,
                            );
                            if (draft != null) {
                              setDialogState(() => draftStocks.add(draft));
                            }
                          },
                          onSaveStock: (locationId, value) {
                            setDialogState(() {
                              final stock = draftStocks.firstWhere(
                                (item) => item.locationId == locationId,
                              );
                              stock.stock = value;
                            });
                          },
                          onRemoveStock: (locationId) {
                            setDialogState(
                              () => draftStocks.removeWhere(
                                (item) => item.locationId == locationId,
                              ),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () async {
                final skuText = sku.text.trim();
                if (skuText.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('SKU wajib diisi.')),
                  );
                  return;
                }
                final stockByLocation = {
                  for (final draft in draftStocks)
                    draft.locationId: draft.stock,
                };
                final totalStock = stockByLocation.values.fold<int>(
                  0,
                  (total, value) => total + value,
                );
                final currentLocationStock = product == null
                    ? totalStock
                    : _stocksForProduct(
                        product,
                        controller.featureRecords('/api/stock'),
                      ).fold<int>(
                        0,
                        (total, record) =>
                            total +
                            ((record.values['stock'] as num?)?.toInt() ?? 0),
                      );
                final saved = await controller.saveProduct(
                  Product(
                    id: product?.id ?? 0,
                    name: name.text.trim().isEmpty
                        ? 'Produk Baru'
                        : name.text.trim(),
                    sku: skuText,
                    price: double.tryParse(price.text.trim()) ?? 0,
                    stock: currentLocationStock,
                    purchasePrice:
                        double.tryParse(purchasePrice.text.trim()) ?? 0,
                    supplierId: int.tryParse(supplierId.text.trim()),
                    categoryId: int.tryParse(categoryId.text.trim()),
                    description: description.text.trim(),
                  ),
                );
                if (product == null && saved != null) {
                  for (final entry in stockByLocation.entries) {
                    if (entry.value <= 0) continue;
                    await controller.saveFeatureRecord('/api/stock', {
                      'product_id': saved.id,
                      'location_id': entry.key,
                      'stock': entry.value,
                    });
                  }
                  await controller.loadFeatureRecords('/api/stock');
                }
                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showProductDetail(
    BuildContext context,
    Product product,
    List<FeatureRecord> stocks,
  ) async {
    final controller = AppScope.of(context);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final latestProduct =
                controller.products
                    .where((item) => item.id == product.id)
                    .firstOrNull ??
                product;
            final selectedLocationId =
                controller.selectedProductLocationFilterId;
            final latestStocks =
                _stocksForProduct(
                      latestProduct,
                      controller.featureRecords('/api/stock'),
                    )
                    .where((stock) {
                      if (selectedLocationId == null) return true;
                      return (stock.values['location_id'] as num?)?.toInt() ==
                          selectedLocationId;
                    })
                    .toList(growable: false);
            return AlertDialog(
              title: Text(latestProduct.name),
              content: SizedBox(
                width: 460,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DetailLine(label: 'SKU', value: latestProduct.sku),
                      _DetailLine(
                        label: 'Harga Jual',
                        value: rupiah(latestProduct.price),
                      ),
                      if (latestProduct.purchasePrice > 0)
                        _DetailLine(
                          label: 'Harga Beli',
                          value: rupiah(latestProduct.purchasePrice),
                        ),
                      if (latestProduct.categoryName != null)
                        _DetailLine(
                          label: 'Grup Produk',
                          value: latestProduct.categoryName!,
                        ),
                      if (latestProduct.supplierName != null)
                        _DetailLine(
                          label: 'Suplier',
                          value: latestProduct.supplierName!,
                        ),
                      if ((latestProduct.description ?? '').trim().isNotEmpty)
                        _DetailLine(
                          label: 'Keterangan',
                          value: latestProduct.description!.trim(),
                        ),
                      const SizedBox(height: 16),
                      Text(
                        'Stok Per Lokasi/Gudang',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      if (latestStocks.where(_hasStock).isEmpty)
                        const Text('Belum Ada Data Stok Lokasi/Gudang.')
                      else
                        for (final stock in latestStocks.where(_hasStock))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _WarehouseStockReadTile(record: stock),
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
            );
          },
        );
      },
    );
  }

  Future<String?> _scanBarcode(BuildContext context) {
    return Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const _BarcodeScannerPage()),
    );
  }

  Future<void> _confirmDeleteProduct(
    BuildContext context,
    Product product,
  ) async {
    final controller = AppScope.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus Produk'),
        content: Text('Hapus ${product.name}?'),
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
      await controller.deleteProduct(product);
    }
  }

  Future<void> _showStockDialog(
    BuildContext context, {
    required Product product,
    required List<FeatureRecord> stocks,
  }) async {
    final controller = AppScope.of(context);
    final usedLocationIds = stocks
        .where(_hasStock)
        .map((stock) => (stock.values['location_id'] as num?)?.toInt())
        .whereType<int>()
        .toSet();
    final locations = controller
        .featureRecords('/api/locations')
        .where((location) => !usedLocationIds.contains(location.id))
        .toList(growable: false);
    final locationController = TextEditingController(
      text: locations.isEmpty ? '' : locations.first.id.toString(),
    );
    final stockController = TextEditingController(text: '0');

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Tambah Stok ${product.name}'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (locations.isEmpty)
                const Text('Semua lokasi/gudang sudah memiliki stok.')
              else ...[
                _ReferenceDropdown(
                  controller: locationController,
                  label: 'Lokasi/Gudang',
                  records: locations,
                  labelKeys: const ['nama', 'kode'],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: stockController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Stok'),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: locations.isEmpty
                ? null
                : () async {
                    await _saveLocationStock(
                      context,
                      productId: product.id,
                      locationId:
                          int.tryParse(locationController.text.trim()) ?? 0,
                      stock: int.tryParse(stockController.text.trim()) ?? 0,
                    );
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
                  },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  Future<_DraftLocationStock?> _showDraftStockDialog(
    BuildContext context, {
    required List<FeatureRecord> locations,
    required List<_DraftLocationStock> stocks,
  }) async {
    final usedLocationIds = stocks.map((stock) => stock.locationId).toSet();
    final availableLocations = locations
        .where((location) => !usedLocationIds.contains(location.id))
        .toList(growable: false);
    final locationController = TextEditingController(
      text: availableLocations.isEmpty
          ? ''
          : availableLocations.first.id.toString(),
    );
    final stockController = TextEditingController(text: '0');

    return showDialog<_DraftLocationStock>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Tambah Stok Lokasi/Gudang'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (availableLocations.isEmpty)
                const Text('Semua lokasi/gudang sudah dipilih.')
              else ...[
                _ReferenceDropdown(
                  controller: locationController,
                  label: 'Lokasi/Gudang',
                  records: availableLocations,
                  labelKeys: const ['nama', 'kode'],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: stockController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Stok'),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: availableLocations.isEmpty
                ? null
                : () {
                    final locationId =
                        int.tryParse(locationController.text.trim()) ?? 0;
                    final location = availableLocations.firstWhere(
                      (item) => item.id == locationId,
                    );
                    Navigator.of(dialogContext).pop(
                      _DraftLocationStock(
                        locationId: location.id,
                        locationName: location.label(const ['nama', 'kode']),
                        stock: int.tryParse(stockController.text.trim()) ?? 0,
                      ),
                    );
                  },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  bool _hasStock(FeatureRecord record) {
    return ((record.values['stock'] as num?)?.toInt() ?? 0) > 0;
  }

  Future<void> _saveLocationStock(
    BuildContext context, {
    required int productId,
    required int locationId,
    required int stock,
  }) async {
    final controller = AppScope.of(context);
    await controller.saveFeatureRecord('/api/stock', {
      'product_id': productId,
      'location_id': locationId,
      'stock': stock,
    });
    await controller.loadFeatureRecords('/api/stock');
  }
}

class _InventoryCard extends StatelessWidget {
  const _InventoryCard({
    required this.product,
    required this.canUpdate,
    required this.canDelete,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final Product product;
  final bool canUpdate;
  final bool canDelete;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final lowStock = product.stock <= 10;
    final metaStyle = Theme.of(context).textTheme.bodySmall;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      product.name,
                      style: Theme.of(context).textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (canUpdate)
                    IconButton(
                      tooltip: 'Edit produk',
                      visualDensity: VisualDensity.compact,
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit),
                    ),
                  if (canDelete)
                    IconButton(
                      tooltip: 'Hapus produk',
                      visualDensity: VisualDensity.compact,
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(product.sku, maxLines: 1, overflow: TextOverflow.ellipsis),
              if (product.categoryName != null)
                Text(
                  'Grup Produk: ${product.categoryName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: metaStyle,
                ),
              if (product.supplierName != null)
                Text(
                  'Suplier: ${product.supplierName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: metaStyle,
                ),
              if ((product.description ?? '').trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    product.description!.trim(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: metaStyle,
                  ),
                ),
              if (canUpdate && product.purchasePrice > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Modal ${rupiah(product.purchasePrice)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: metaStyle,
                  ),
                ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      rupiah(product.price),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StockBadge(stock: product.stock, lowStock: lowStock),
                ],
              ),
            ],
          ),
        ),
      ),
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
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _DraftLocationStock {
  _DraftLocationStock({
    required this.locationId,
    required this.locationName,
    required this.stock,
  });

  final int locationId;
  final String locationName;
  int stock;
}

class _NewProductStockEditor extends StatelessWidget {
  const _NewProductStockEditor({
    required this.locations,
    required this.stocks,
    required this.onAddStock,
    required this.onSaveStock,
    required this.onRemoveStock,
  });

  final List<FeatureRecord> locations;
  final List<_DraftLocationStock> stocks;
  final Future<void> Function() onAddStock;
  final void Function(int locationId, int stock) onSaveStock;
  final void Function(int locationId) onRemoveStock;

  @override
  Widget build(BuildContext context) {
    if (locations.isEmpty) {
      return const Text('Tambahkan lokasi/gudang sebelum mengisi stok.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Stok Per Lokasi/Gudang',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton.filledTonal(
              tooltip: 'Tambah Stok Lokasi/Gudang',
              onPressed: stocks.length >= locations.length ? null : onAddStock,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (stocks.isEmpty)
          const Text('Belum Ada Data Stok Lokasi/Gudang.')
        else
          for (final stock in stocks)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _DraftWarehouseStockTile(
                stock: stock,
                onSave: (value) => onSaveStock(stock.locationId, value),
                onRemove: () => onRemoveStock(stock.locationId),
              ),
            ),
      ],
    );
  }
}

class _DraftWarehouseStockTile extends StatelessWidget {
  const _DraftWarehouseStockTile({
    required this.stock,
    required this.onSave,
    required this.onRemove,
  });

  final _DraftLocationStock stock;
  final ValueChanged<int> onSave;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _EditableWarehouseStockTile(
            location: stock.locationName,
            stock: stock.stock,
            canManage: true,
            onSave: onSave,
          ),
        ),
        IconButton(
          tooltip: 'Hapus Lokasi/Gudang',
          onPressed: onRemove,
          icon: const Icon(Icons.delete_outline),
        ),
      ],
    );
  }
}

class _ProductStockEditor extends StatelessWidget {
  const _ProductStockEditor({
    required this.product,
    required this.stocksForProduct,
    required this.hasStock,
    required this.onSaveStock,
    required this.onAddStock,
  });

  final Product product;
  final List<FeatureRecord> Function(Product, List<FeatureRecord>)
  stocksForProduct;
  final bool Function(FeatureRecord) hasStock;
  final Future<void> Function(int locationId, int value) onSaveStock;
  final Future<void> Function(List<FeatureRecord> stocks) onAddStock;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    if (!controller.canViewMenu('inventory')) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final latestProduct =
            controller.products
                .where((item) => item.id == product.id)
                .firstOrNull ??
            product;
        final stocks = stocksForProduct(
          latestProduct,
          controller.featureRecords('/api/stock'),
        );
        final visibleStocks = stocks.where(hasStock).toList(growable: false);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Stok Per Lokasi/Gudang',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (controller.canCreateMenu('inventory'))
                  IconButton.filledTonal(
                    tooltip: 'Tambah Stok Lokasi/Gudang',
                    onPressed: controller.isBusy
                        ? null
                        : () => onAddStock(stocks),
                    icon: const Icon(Icons.add),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (visibleStocks.isEmpty)
              const Text('Belum Ada Data Stok Lokasi/Gudang.')
            else
              for (final stock in visibleStocks)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _WarehouseStockTile(
                    record: stock,
                    canManage: controller.canUpdateMenu('inventory'),
                    onSave: (value) => onSaveStock(
                      (stock.values['location_id'] as num).toInt(),
                      value,
                    ),
                  ),
                ),
          ],
        );
      },
    );
  }
}

class _WarehouseStockReadTile extends StatelessWidget {
  const _WarehouseStockReadTile({required this.record});

  final FeatureRecord record;

  @override
  Widget build(BuildContext context) {
    final location = record.values['location_name']?.toString() ?? 'Lokasi';
    final stock = (record.values['stock'] as num?)?.toInt() ?? 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.warehouse),
          const SizedBox(width: 10),
          Expanded(
            child: Text(location, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          Text(
            '$stock',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _WarehouseStockTile extends StatelessWidget {
  const _WarehouseStockTile({
    required this.record,
    required this.canManage,
    required this.onSave,
  });

  final FeatureRecord record;
  final bool canManage;
  final ValueChanged<int> onSave;

  @override
  Widget build(BuildContext context) {
    final location = record.values['location_name']?.toString() ?? 'Lokasi';
    final stock = (record.values['stock'] as num?)?.toInt() ?? 0;
    return _EditableWarehouseStockTile(
      location: location,
      stock: stock,
      canManage: canManage,
      onSave: onSave,
    );
  }
}

class _EditableWarehouseStockTile extends StatefulWidget {
  const _EditableWarehouseStockTile({
    required this.location,
    required this.stock,
    required this.canManage,
    required this.onSave,
  });

  final String location;
  final int stock;
  final bool canManage;
  final ValueChanged<int> onSave;

  @override
  State<_EditableWarehouseStockTile> createState() =>
      _EditableWarehouseStockTileState();
}

class _EditableWarehouseStockTileState
    extends State<_EditableWarehouseStockTile> {
  late final TextEditingController _stock = TextEditingController(
    text: widget.stock.toString(),
  );
  bool _editing = false;

  @override
  void didUpdateWidget(covariant _EditableWarehouseStockTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_editing && oldWidget.stock != widget.stock) {
      _stock.text = widget.stock.toString();
    }
  }

  @override
  void dispose() {
    _stock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.warehouse),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.location,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (_editing)
            SizedBox(
              width: 82,
              child: TextField(
                controller: _stock,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Stok'),
              ),
            )
          else
            Text(
              '${widget.stock}',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          if (widget.canManage) ...[
            const SizedBox(width: 8),
            if (_editing) ...[
              IconButton(
                tooltip: 'Simpan',
                onPressed: () {
                  widget.onSave(int.tryParse(_stock.text.trim()) ?? 0);
                  setState(() => _editing = false);
                },
                icon: const Icon(Icons.check),
              ),
              IconButton(
                tooltip: 'Batal',
                onPressed: () {
                  _stock.text = widget.stock.toString();
                  setState(() => _editing = false);
                },
                icon: const Icon(Icons.close),
              ),
            ] else
              IconButton(
                tooltip: 'Edit Stok',
                onPressed: () => setState(() => _editing = true),
                icon: const Icon(Icons.edit),
              ),
          ],
        ],
      ),
    );
  }
}

class _ReferenceDropdown extends StatelessWidget {
  const _ReferenceDropdown({
    required this.controller,
    required this.label,
    required this.records,
    required this.labelKeys,
  });

  final TextEditingController controller;
  final String label;
  final List<FeatureRecord> records;
  final List<String> labelKeys;

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: label),
      );
    }

    final current =
        records.any((record) => record.id.toString() == controller.text)
        ? controller.text
        : records.first.id.toString();
    controller.text = current;
    return SearchableDropdown<String>(
      label: label,
      value: current,
      choices: [
        for (final record in records)
          DropdownChoice(
            value: record.id.toString(),
            label: record.label(labelKeys),
          ),
      ],
      onChanged: (value) => controller.text = value,
    );
  }
}

class _StockBadge extends StatelessWidget {
  const _StockBadge({required this.stock, required this.lowStock});

  final int stock;
  final bool lowStock;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final background = lowStock
        ? colors.errorContainer
        : colors.secondaryContainer;
    final foreground = lowStock
        ? colors.onErrorContainer
        : colors.onSecondaryContainer;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            lowStock ? Icons.warning_amber : Icons.inventory,
            size: 16,
            color: foreground,
          ),
          const SizedBox(width: 5),
          Text(
            lowStock ? 'Rendah $stock' : 'Stok $stock',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _BarcodeScannerPage extends StatefulWidget {
  const _BarcodeScannerPage();

  @override
  State<_BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<_BarcodeScannerPage> {
  bool _handled = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Barcode')),
      body: MobileScanner(
        onDetect: (capture) {
          if (_handled) return;
          final code = capture.barcodes
              .map((barcode) => barcode.rawValue)
              .whereType<String>()
              .where((value) => value.trim().isNotEmpty)
              .firstOrNull;
          if (code == null) return;
          _handled = true;
          Navigator.of(context).pop(code);
        },
      ),
    );
  }
}
