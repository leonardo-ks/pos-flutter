import '../../auth/models/app_user.dart';
import '../../customers/models/customer.dart';
import '../../inventory/models/product.dart';
import '../../reports/models/sale_transaction.dart';
import '../../reports/models/transaction_item.dart';

class MockDataStore {
  MockDataStore({
    required this.products,
    required this.customers,
    required this.transactions,
  });

  factory MockDataStore.seeded() {
    final manager = const AppUser(
      id: 2,
      name: 'Bima Manajer',
      role: UserRole.manager,
    );
    final customer = const Customer(
      id: 1,
      name: 'Rani Wijaya',
      phone: '081210002000',
      discountCategory: 'VIP',
    );
    final products = [
      const Product(
        id: 1,
        name: 'Kopi Susu Botol',
        sku: 'DRK-001',
        price: 18000,
        stock: 34,
        categoryId: 1,
      ),
      const Product(
        id: 2,
        name: 'Roti Cokelat',
        sku: 'BKR-014',
        price: 12000,
        stock: 18,
        categoryId: 1,
      ),
      const Product(
        id: 3,
        name: 'Beras Premium 5kg',
        sku: 'GRC-500',
        price: 72000,
        stock: 12,
        categoryId: 1,
      ),
      const Product(
        id: 4,
        name: 'Minyak Goreng 1L',
        sku: 'GRC-110',
        price: 21000,
        stock: 24,
        categoryId: 1,
      ),
      const Product(
        id: 5,
        name: 'Sabun Cair',
        sku: 'HHC-020',
        price: 16500,
        stock: 9,
        categoryId: 1,
      ),
      const Product(
        id: 6,
        name: 'Teh Melati Dus',
        sku: 'DRK-044',
        price: 32000,
        stock: 16,
        categoryId: 1,
      ),
    ];
    final transactions = [
      SaleTransaction(
        id: 1001,
        time: DateTime.now().subtract(const Duration(hours: 2)),
        customer: customer,
        user: manager,
        items: const [
          TransactionItem(
            productId: 1,
            productName: 'Kopi Susu Botol',
            unitPrice: 18000,
            quantity: 3,
          ),
          TransactionItem(
            productId: 2,
            productName: 'Roti Cokelat',
            unitPrice: 12000,
            quantity: 2,
          ),
        ],
        totalBeforeDiscount: 78000,
        discount: 7800,
        totalFinal: 70200,
      ),
      SaleTransaction(
        id: 1002,
        time: DateTime.now().subtract(const Duration(days: 5)),
        customer: null,
        user: manager,
        items: const [
          TransactionItem(
            productId: 3,
            productName: 'Beras Premium 5kg',
            unitPrice: 72000,
            quantity: 1,
          ),
          TransactionItem(
            productId: 4,
            productName: 'Minyak Goreng 1L',
            unitPrice: 21000,
            quantity: 2,
          ),
        ],
        totalBeforeDiscount: 114000,
        discount: 0,
        totalFinal: 114000,
      ),
    ];

    return MockDataStore(
      products: products,
      customers: [
        customer,
        const Customer(
          id: 2,
          name: 'Agus Santoso',
          phone: '081344441111',
          discountCategory: 'Reguler',
        ),
        const Customer(
          id: 3,
          name: 'Maya Pratama',
          phone: '081922223333',
          discountCategory: 'Gold',
        ),
      ],
      transactions: transactions,
    );
  }

  final List<Product> products;
  final List<Customer> customers;
  final List<SaleTransaction> transactions;
}
