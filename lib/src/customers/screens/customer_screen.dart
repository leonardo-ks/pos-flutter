import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_controller.dart';
import '../../app/app_scope.dart';
import '../../shared/models/feature_record.dart';
import '../../shared/widgets/debounced_text_field.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/searchable_dropdown.dart';
import '../models/customer.dart';

class CustomerScreen extends StatefulWidget {
  const CustomerScreen({super.key});

  @override
  State<CustomerScreen> createState() => _CustomerScreenState();
}

class _CustomerScreenState extends State<CustomerScreen> {
  bool _loadedDiscounts = false;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loadedDiscounts) {
      _loadedDiscounts = true;
      final controller = AppScope.of(context);
      Future.microtask(() async {
        await controller.loadFeatureRecords('/api/product-categories');
        await controller.loadFeatureRecords('/api/customer-group-discounts');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final customers = controller.customers;
    if (!controller.canViewMenu('customers')) {
      return const EmptyState(
        icon: Icons.lock,
        title: 'Akses Ditolak',
        message: 'Data pelanggan hanya dapat dikelola oleh Manajer.',
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        body: Column(
          children: [
            const TabBar(
              tabs: [
                Tab(text: 'Pelanggan'),
                Tab(text: 'Kategori Diskon Pelanggan'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final search = DebouncedTextField(
                              controller: _searchController,
                              onChanged: (value) {
                                setState(() => _query = value);
                                controller.searchCustomers(value);
                              },
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.search),
                                labelText: 'Cari Pelanggan',
                                suffixIcon: _query.isEmpty
                                    ? null
                                    : IconButton(
                                        tooltip: 'Bersihkan',
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() => _query = '');
                                          controller.searchCustomers('');
                                        },
                                        icon: const Icon(Icons.close),
                                      ),
                              ),
                            );
                            final addButton = FilledButton.icon(
                              onPressed:
                                  controller.isBusy ||
                                      !controller.canCreateMenu('customers')
                                  ? null
                                  : () => _showCustomerDialog(context),
                              icon: const Icon(Icons.person_add),
                              label: const Text('Pelanggan'),
                            );
                            if (!controller.canCreateMenu('customers')) {
                              return search;
                            }
                            if (constraints.maxWidth < 560) {
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
                      Expanded(
                        child: customers.isEmpty
                            ? const EmptyState(
                                icon: Icons.search_off,
                                title: 'Pelanggan Tidak Ditemukan',
                                message: 'Coba kata kunci lain.',
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.all(16),
                                itemCount:
                                    customers.length +
                                    (controller.canLoadMoreCustomers ? 1 : 0),
                                separatorBuilder: (context, index) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  if (index == customers.length) {
                                    return SizedBox(
                                      width: double.infinity,
                                      child: Center(
                                        child: OutlinedButton.icon(
                                          onPressed: controller.isBusy
                                              ? null
                                              : () => controller
                                                    .loadMoreCustomers(
                                                      query: _query,
                                                    ),
                                          icon: const Icon(Icons.expand_more),
                                          label: const Text('Muat Lagi'),
                                        ),
                                      ),
                                    );
                                  }
                                  final customer = customers[index];
                                  return Card(
                                    child: ListTile(
                                      onTap: () => _showCustomerDetail(
                                        context,
                                        customer,
                                      ),
                                      leading: const CircleAvatar(
                                        child: Icon(Icons.person),
                                      ),
                                      title: Text(customer.name),
                                      subtitle: Text(
                                        _formatPhone(customer.phone),
                                      ),
                                      trailing: Wrap(
                                        spacing: 4,
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        children: [
                                          if (controller.canUpdateMenu(
                                            'customers',
                                          ))
                                            IconButton(
                                              tooltip: 'Edit pelanggan',
                                              onPressed: () =>
                                                  _showCustomerDialog(
                                                    context,
                                                    customer: customer,
                                                  ),
                                              icon: const Icon(Icons.edit),
                                            ),
                                          if (controller.canDeleteMenu(
                                            'customers',
                                          ))
                                            IconButton(
                                              tooltip: 'Hapus pelanggan',
                                              onPressed: () => _confirmDelete(
                                                context,
                                                customer,
                                              ),
                                              icon: const Icon(
                                                Icons.delete_outline,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                  const _CustomerDiscountTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCustomerDetail(
    BuildContext context,
    Customer customer,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(customer.name),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _CustomerDetailLine(
                label: 'Nomor HP',
                value: _formatPhone(customer.phone),
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

  Future<void> _confirmDelete(BuildContext context, Customer customer) async {
    final controller = AppScope.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus Pelanggan'),
        content: Text('Hapus ${customer.name}?'),
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
      await controller.deleteCustomer(customer);
    }
  }

  Future<void> _showCustomerDialog(
    BuildContext context, {
    Customer? customer,
  }) async {
    final controller = AppScope.of(context);
    final name = TextEditingController(text: customer?.name ?? '');
    final phone = TextEditingController(
      text: _formatPhone(customer?.phone ?? ''),
    );

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(customer == null ? 'Tambah Pelanggan' : 'Edit Pelanggan'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Nama'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s]')),
                    _PhoneFormatter(),
                  ],
                  decoration: const InputDecoration(labelText: 'Nomor HP'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () async {
                await controller.saveCustomer(
                  Customer(
                    id: customer?.id ?? 0,
                    name: name.text.trim().isEmpty
                        ? 'Pelanggan Baru'
                        : name.text.trim(),
                    phone: _phoneDigits(phone.text).isEmpty
                        ? '-'
                        : _phoneDigits(phone.text),
                    discountCategory: 'Per Grup',
                  ),
                );
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  String _phoneDigits(String value) => value.replaceAll(RegExp(r'[^0-9]'), '');

  String _formatPhone(String value) {
    final digits = _phoneDigits(value);
    if (digits.length <= 4) return digits;
    if (digits.length <= 8) {
      return '${digits.substring(0, 4)}-${digits.substring(4)}';
    }
    return '${digits.substring(0, 4)}-${digits.substring(4, 8)}-${digits.substring(8)}';
  }
}

class _CustomerDiscountTab extends StatefulWidget {
  const _CustomerDiscountTab();

  @override
  State<_CustomerDiscountTab> createState() => _CustomerDiscountTabState();
}

class _CustomerDiscountTabState extends State<_CustomerDiscountTab> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final customers = controller.customers
        .where((customer) {
          final hasDiscount = controller.customerGroupDiscounts.any(
            (record) =>
                (record.values['customer_id'] as num?)?.toInt() == customer.id,
          );
          if (!hasDiscount) return false;
          return _query.trim().isEmpty ||
              customer.name.toLowerCase().contains(_query.toLowerCase()) ||
              customer.phone.contains(_query);
        })
        .toList(growable: false);
    final canCreate = controller.canCreateMenu('customers');

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: DebouncedTextField(
                  controller: _search,
                  onChanged: (value) {
                    setState(() => _query = value);
                    controller.searchCustomers(value);
                  },
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    labelText: 'Cari Pelanggan',
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Bersihkan',
                            onPressed: () {
                              _search.clear();
                              setState(() => _query = '');
                              controller.searchCustomers('');
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
                      : () => _showDiscountDialog(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Diskon'),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: customers.isEmpty
              ? const EmptyState(
                  icon: Icons.search_off,
                  title: 'Pelanggan Tidak Ditemukan',
                  message: 'Coba kata kunci lain.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount:
                      customers.length +
                      (controller.canLoadMoreCustomers ? 1 : 0),
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    if (index == customers.length) {
                      return SizedBox(
                        width: double.infinity,
                        child: Center(
                          child: OutlinedButton.icon(
                            onPressed: controller.isBusy
                                ? null
                                : () => controller.loadMoreCustomers(
                                    query: _query,
                                  ),
                            icon: const Icon(Icons.expand_more),
                            label: const Text('Muat Lagi'),
                          ),
                        ),
                      );
                    }
                    final customer = customers[index];
                    final discountCount = controller.customerGroupDiscounts
                        .where(
                          (record) =>
                              (record.values['customer_id'] as num?)?.toInt() ==
                              customer.id,
                        )
                        .length;
                    return Card(
                      child: ListTile(
                        onTap: () =>
                            _showDiscountDialog(context, customer: customer),
                        leading: const CircleAvatar(
                          child: Icon(Icons.discount),
                        ),
                        title: Text(customer.name),
                        subtitle: Text('ID ${customer.id}'),
                        trailing: Text('$discountCount Grup'),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _showDiscountDialog(BuildContext context, {Customer? customer}) {
    return showDialog<void>(
      context: context,
      builder: (_) => _CustomerDiscountDialog(customer: customer),
    );
  }
}

class _CustomerDiscountDialog extends StatefulWidget {
  const _CustomerDiscountDialog({this.customer});

  final Customer? customer;

  @override
  State<_CustomerDiscountDialog> createState() =>
      _CustomerDiscountDialogState();
}

class _CustomerDiscountDialogState extends State<_CustomerDiscountDialog> {
  int? _customerId;
  int? _loadedCustomerId;
  List<_CustomerDiscountDraft> _drafts = [];
  final Set<int> _deletedDraftIds = {};

  @override
  void initState() {
    super.initState();
    _customerId = widget.customer?.id;
  }

  @override
  void dispose() {
    for (final draft in _drafts) {
      draft.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final customers = controller.customers;
    final categories = controller.featureRecords('/api/product-categories');
    _syncDrafts(controller);

    return AlertDialog(
      title: const Text('Kategori Diskon Pelanggan'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SearchableDropdown<int?>(
                label: 'Pelanggan',
                value: _customerId,
                prefixIcon: Icons.person,
                choices: [
                  for (final customer in customers)
                    DropdownChoice<int?>(
                      value: customer.id,
                      label: '${customer.name} - ID ${customer.id}',
                    ),
                ],
                onChanged: (value) {
                  setState(() {
                    _customerId = value;
                    _replaceDrafts(const []);
                    _deletedDraftIds.clear();
                    _loadedCustomerId = null;
                  });
                },
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed:
                      _customerId == null ||
                          _drafts.length >= categories.length ||
                          !controller.canCreateMenu('customers')
                      ? null
                      : () async {
                          final draft = await _showAddCategoryDialog(
                            context,
                            categories,
                          );
                          if (draft != null) {
                            setState(() {
                              _drafts = [..._drafts, draft];
                              _loadedCustomerId = _customerId;
                            });
                          }
                        },
                  icon: const Icon(Icons.add),
                  label: const Text('Tambah Grup Produk'),
                ),
              ),
              const SizedBox(height: 8),
              if (_customerId == null)
                const Text('Pilih pelanggan lebih dulu.')
              else if (_drafts.isEmpty)
                Text(
                  _deletedDraftIds.isEmpty
                      ? 'Belum Ada Diskon Grup Produk.'
                      : 'Semua diskon grup produk akan dihapus saat disimpan.',
                )
              else
                for (final draft in _drafts)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _CustomerDiscountTile(
                      draft: draft,
                      onDelete: () {
                        setState(() {
                          final id = draft.id;
                          if (id != null) _deletedDraftIds.add(id);
                          _drafts = _drafts
                              .where((item) => item != draft)
                              .toList(growable: false);
                          draft.dispose();
                        });
                      },
                    ),
                  ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Tutup'),
        ),
        FilledButton(
          onPressed:
              _customerId == null ||
                  (_drafts.isEmpty && _deletedDraftIds.isEmpty)
              ? null
              : () async {
                  await _saveAllDrafts(context);
                  if (context.mounted) Navigator.of(context).pop();
                },
          child: const Text('Simpan'),
        ),
      ],
    );
  }

  void _syncDrafts(AppController controller) {
    final customerId = _customerId;
    if (customerId == null || _loadedCustomerId == customerId) return;
    final records = controller.customerGroupDiscounts
        .where(
          (record) =>
              (record.values['customer_id'] as num?)?.toInt() == customerId,
        )
        .toList(growable: false);
    _replaceDrafts(
      records
          .map(
            (record) => _CustomerDiscountDraft(
              id: record.id,
              categoryId: (record.values['category_id'] as num).toInt(),
              categoryName:
                  record.values['category_name']?.toString() ?? 'Grup Produk',
              rate: _percentText(record.values['rate']),
            ),
          )
          .toList(growable: false),
    );
    _loadedCustomerId = customerId;
  }

  Future<_CustomerDiscountDraft?> _showAddCategoryDialog(
    BuildContext context,
    List<FeatureRecord> categories,
  ) async {
    final used = _drafts.map((draft) => draft.categoryId).toSet();
    final available = categories
        .where((category) => !used.contains(category.id))
        .toList(growable: false);
    int? categoryId = available.isEmpty ? null : available.first.id;
    final rate = TextEditingController(text: '0');
    final result = await showDialog<_CustomerDiscountDraft>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Tambah Grup Produk'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (available.isEmpty)
                const Text('Semua grup produk sudah dipilih.')
              else ...[
                StatefulBuilder(
                  builder: (context, setDialogState) {
                    return SearchableDropdown<int?>(
                      label: 'Grup Produk',
                      value: categoryId,
                      prefixIcon: Icons.category,
                      choices: [
                        for (final category in available)
                          DropdownChoice<int?>(
                            value: category.id,
                            label: category.label(const ['nama', 'kode']),
                          ),
                      ],
                      onChanged: (value) =>
                          setDialogState(() => categoryId = value),
                    );
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: rate,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Diskon (%)'),
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
            onPressed: categoryId == null
                ? null
                : () {
                    final category = available.firstWhere(
                      (item) => item.id == categoryId,
                    );
                    Navigator.of(dialogContext).pop(
                      _CustomerDiscountDraft(
                        categoryId: category.id,
                        categoryName: category.label(const ['nama', 'kode']),
                        rate: rate.text.trim(),
                      ),
                    );
                  },
            child: const Text('Tambah'),
          ),
        ],
      ),
    );
    rate.dispose();
    return result;
  }

  Future<void> _saveAllDrafts(BuildContext context) async {
    final customerId = _customerId;
    if (customerId == null) return;
    final controller = AppScope.of(context);
    await controller.saveCustomerGroupDiscounts([
      for (final draft in _drafts)
        {
          'id': draft.id,
          'customer_id': customerId,
          'category_id': draft.categoryId,
          'rate': (double.tryParse(draft.rate.text.trim()) ?? 0) / 100,
          'keterangan': '',
        },
    ], deleteIds: _deletedDraftIds.toList(growable: false));
  }

  void _replaceDrafts(List<_CustomerDiscountDraft> drafts) {
    for (final draft in _drafts) {
      draft.dispose();
    }
    _drafts = drafts;
    _deletedDraftIds.clear();
  }
}

class _CustomerDiscountDraft {
  _CustomerDiscountDraft({
    this.id,
    required this.categoryId,
    required this.categoryName,
    required String rate,
  }) : rate = TextEditingController(text: rate);

  int? id;
  final int categoryId;
  final String categoryName;
  final TextEditingController rate;

  void dispose() => rate.dispose();
}

class _CustomerDiscountTile extends StatelessWidget {
  const _CustomerDiscountTile({required this.draft, required this.onDelete});

  final _CustomerDiscountDraft draft;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(child: Text(draft.categoryName)),
          const SizedBox(width: 10),
          SizedBox(
            width: 120,
            child: TextField(
              controller: draft.rate,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Diskon %'),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Hapus Grup Produk',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }
}

String _percentText(Object? value) {
  final number = value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '') ?? 0;
  return (number * 100).toStringAsFixed(number == 0 ? 0 : 2);
}

class _CustomerDetailLine extends StatelessWidget {
  const _CustomerDetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 112,
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
    final formatted = _format(digits);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  String _format(String digits) {
    if (digits.length <= 4) return digits;
    if (digits.length <= 8) {
      return '${digits.substring(0, 4)}-${digits.substring(4)}';
    }
    return '${digits.substring(0, 4)}-${digits.substring(4, 8)}-${digits.substring(8)}';
  }
}
