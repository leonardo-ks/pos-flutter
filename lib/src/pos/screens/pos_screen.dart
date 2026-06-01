import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../customers/models/customer.dart';
import '../../inventory/models/product.dart';
import '../../reports/models/sale_transaction.dart';
import '../../shared/formatters.dart';
import '../../shared/widgets/debounced_text_field.dart';
import '../../shared/printing/receipt_printer.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/searchable_dropdown.dart';
import '../models/cart_line.dart';

class PosScreen extends StatelessWidget {
  const PosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= AppBreakpoints.splitPane;
        final products = _ProductPicker(products: controller.filteredProducts);
        final cart = const _CartPanel();

        if (wide) {
          return Row(
            children: [
              Expanded(child: products),
              const VerticalDivider(width: 1),
              const SizedBox(width: 420, child: _CartPanel()),
            ],
          );
        }

        return ListView(
          children: [
            SizedBox(height: 520, child: products),
            const Divider(height: 1),
            SizedBox(height: 560, child: cart),
          ],
        );
      },
    );
  }
}

class _ProductPicker extends StatefulWidget {
  const _ProductPicker({required this.products});

  final List<Product> products;

  @override
  State<_ProductPicker> createState() => _ProductPickerState();
}

class _ProductPickerState extends State<_ProductPicker> {
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final products = widget.products;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: DebouncedTextField(
                  controller: _search,
                  onChanged: controller.setProductSearch,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    labelText: 'Cari Produk Atau SKU',
                    suffixIcon: controller.productSearch.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Bersihkan',
                            onPressed: () {
                              _search.clear();
                              controller.setProductSearch('');
                            },
                            icon: const Icon(Icons.close),
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              controller.isBusy
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text('${products.length} Produk'),
            ],
          ),
        ),
        Expanded(
          child: products.isEmpty
              ? const EmptyState(
                  icon: Icons.search_off,
                  title: 'Produk Tidak Ditemukan',
                  message: 'Coba kata kunci lain atau periksa inventaris.',
                )
              : ListView.separated(
                  addAutomaticKeepAlives: false,
                  addSemanticIndexes: false,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount:
                      products.length +
                      (controller.canLoadMoreProducts ? 1 : 0),
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    if (index == products.length) {
                      return SizedBox(
                        width: double.infinity,
                        child: Center(
                          child: OutlinedButton.icon(
                            onPressed: controller.isBusy
                                ? null
                                : controller.loadMoreProducts,
                            icon: const Icon(Icons.expand_more),
                            label: const Text('Muat Lagi'),
                          ),
                        ),
                      );
                    }
                    return RepaintBoundary(
                      child: _ProductTile(product: products[index]),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final lowStock = product.stock <= 10;

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          child: Text(product.name.characters.first.toUpperCase()),
        ),
        title: Text(product.name),
        subtitle: Text('${product.sku} - ${rupiah(product.price)}'),
        trailing: Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Chip(
              avatar: Icon(
                lowStock ? Icons.warning_amber : Icons.check_circle,
                size: 18,
              ),
              label: Text('Stok ${product.stock}'),
            ),
            IconButton.filledTonal(
              key: Key('add-product-${product.id}'),
              tooltip: 'Tambah ke keranjang',
              onPressed: product.stock == 0
                  ? null
                  : () => controller.addToCart(product),
              icon: const Icon(Icons.add_shopping_cart),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartPanel extends StatelessWidget {
  const _CartPanel();

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: SearchableDropdown<int?>(
            key: const Key('customer-select'),
            label: 'Pelanggan',
            value: controller.selectedCustomer?.id,
            prefixIcon: Icons.person_search,
            choices: [
              const DropdownChoice<int?>(value: null, label: 'Tanpa Pelanggan'),
              for (final customer in controller.customers)
                DropdownChoice<int?>(value: customer.id, label: customer.name),
            ],
            onChanged: (id) {
              Customer? customer;
              if (id != null) {
                customer = controller.customers.firstWhere(
                  (item) => item.id == id,
                );
              }
              controller.selectCustomer(customer);
            },
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: controller.cartLines.isEmpty
              ? const EmptyState(
                  icon: Icons.shopping_cart_outlined,
                  title: 'Keranjang kosong',
                  message: 'Tambahkan produk untuk mulai transaksi.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: controller.cartLines.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final line = controller.cartLines[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(line.product.name),
                      subtitle: Text(rupiah(line.subtotal)),
                      trailing: Wrap(
                        spacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          IconButton(
                            tooltip: 'Kurangi',
                            onPressed: () =>
                                controller.decrementCart(line.product),
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                          SizedBox(
                            width: 62,
                            child: _QuantityInput(line: line),
                          ),
                          IconButton(
                            tooltip: 'Tambah',
                            onPressed: () => controller.addToCart(line.product),
                            icon: const Icon(Icons.add_circle_outline),
                          ),
                          IconButton(
                            tooltip: 'Hapus',
                            onPressed: () =>
                                controller.removeFromCart(line.product),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        _PaymentSummary(
          onCheckout: () async {
            final transaction = await controller.checkout();
            if (transaction != null) {
              if (!context.mounted) return;
              showDialog<void>(
                context: context,
                builder: (_) => _ReceiptDialog(transaction: transaction),
              );
            }
          },
        ),
      ],
    );
  }
}

class _QuantityInput extends StatefulWidget {
  const _QuantityInput({required this.line});

  final CartLine line;

  @override
  State<_QuantityInput> createState() => _QuantityInputState();
}

class _QuantityInputState extends State<_QuantityInput> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.line.quantity.toString(),
  );

  @override
  void didUpdateWidget(covariant _QuantityInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.line.quantity != widget.line.quantity &&
        _controller.text != widget.line.quantity.toString()) {
      _controller.text = widget.line.quantity.toString();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    return TextField(
      controller: _controller,
      textAlign: TextAlign.center,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: const InputDecoration(
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      ),
      onChanged: (value) {
        controller.setCartQuantity(widget.line.product, value);
        final clamped = controller.cartLines
            .where((line) => line.product.id == widget.line.product.id)
            .firstOrNull
            ?.quantity;
        if (clamped != null && clamped.toString() != value) {
          _controller.text = clamped.toString();
          _controller.selection = TextSelection.collapsed(
            offset: _controller.text.length,
          );
        }
      },
      onTapOutside: (_) => FocusScope.of(context).unfocus(),
    );
  }
}

class _PaymentSummary extends StatelessWidget {
  const _PaymentSummary({required this.onCheckout});

  final Future<void> Function() onCheckout;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final discountLabel = controller.selectedCustomer == null
        ? 'Diskon'
        : 'Diskon per grup produk';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: Column(
        children: [
          _SummaryRow(label: 'Subtotal', value: rupiah(controller.subtotal)),
          _SummaryRow(
            label: discountLabel,
            value: '-${rupiah(controller.discountAmount)}',
          ),
          const Divider(),
          _SummaryRow(
            label: 'Total Akhir',
            value: rupiah(controller.grandTotal),
            prominent: true,
          ),
          const SizedBox(height: 10),
          SearchableDropdown<String>(
            label: 'Metode Pembayaran',
            value: controller.selectedPaymentMethod,
            prefixIcon: Icons.account_balance_wallet,
            choices: const [
              DropdownChoice(value: 'cash', label: 'Tunai'),
              DropdownChoice(value: 'qris', label: 'QRIS'),
              DropdownChoice(value: 'debit', label: 'Debit'),
              DropdownChoice(value: 'transfer', label: 'Transfer'),
            ],
            onChanged: controller.isBusy
                ? null
                : controller.selectPaymentMethod,
          ),
          if (controller.selectedPaymentMethod == 'cash') ...[
            const SizedBox(height: 10),
            TextField(
              key: const Key('cash-received-input'),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.payments),
                labelText: 'Uang Diterima',
              ),
              onChanged: controller.setCashReceived,
            ),
            const SizedBox(height: 8),
            _SummaryRow(
              label: 'Kembalian',
              value: rupiah(controller.cashChange.clamp(0, double.infinity)),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const Key('checkout-button'),
              onPressed: controller.canCheckout ? onCheckout : null,
              icon: const Icon(Icons.payments),
              label: Text(
                controller.isBusy ? 'Memproses...' : 'Selesaikan Pembayaran',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.prominent = false,
  });

  final String label;
  final String value;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    final style = prominent
        ? Theme.of(context).textTheme.titleLarge
        : Theme.of(context).textTheme.bodyMedium;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }
}

class _ReceiptDialog extends StatelessWidget {
  const _ReceiptDialog({required this.transaction});

  final SaleTransaction transaction;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.check_circle),
      title: const Text('Transaksi Berhasil'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('No. Struk: #${transaction.id}'),
          Text('Item: ${transaction.itemCount}'),
          Text('Total: ${rupiah(transaction.totalFinal)}'),
          Text('Pembayaran: ${_paymentLabel(transaction.paymentMethod)}'),
          if (transaction.paymentMethod == 'cash') ...[
            Text('Uang Diterima: ${rupiah(transaction.cashReceived ?? 0)}'),
            Text('Kembalian: ${rupiah(transaction.changeAmount)}'),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Tutup'),
        ),
        FilledButton.icon(
          onPressed: () => printReceipt(transaction),
          icon: const Icon(Icons.print),
          label: const Text('Cetak'),
        ),
      ],
    );
  }

  String _paymentLabel(String method) {
    return switch (method) {
      'qris' => 'QRIS',
      'debit' => 'Debit',
      'transfer' => 'Transfer',
      _ => 'Tunai',
    };
  }
}
