import 'package:flutter/foundation.dart';

import '../../customers/models/customer.dart';
import '../../customers/repositories/customer_repository.dart';
import '../async_guard.dart';

class CustomerController extends ChangeNotifier {
  CustomerController(
    this._guard,
    this._repo, {
    List<Customer> initialItems = const [],
  }) : _items = initialItems;

  final AsyncGuard _guard;
  final CustomerRepository _repo;

  List<Customer> _items;
  String? _nextCursor;
  Customer? _selected;

  List<Customer> get items => List.unmodifiable(_items);
  bool get canLoadMore => _nextCursor != null;
  Customer? get selected => _selected;

  void select(Customer? customer) {
    _selected = customer;
    notifyListeners();
  }

  Future<void> search(String value) async {
    try {
      _nextCursor = null;
      notifyListeners();
      final page = await _repo.fetchCustomerPage(query: value);
      _items = page.rows;
      _nextCursor = page.nextCursor;
      notifyListeners();
    } catch (error) {
      _guard.reportError(error);
    }
  }

  Future<bool> loadMore({String? query}) async {
    final cursor = _nextCursor;
    if (cursor == null) return false;
    await _guard.run(() async {
      final page = await _repo.fetchCustomerPage(query: query, cursor: cursor);
      _items = [..._items, ...page.rows];
      _nextCursor = page.nextCursor;
    });
    return true;
  }

  Future<Customer?> save(Customer customer) async {
    Customer? saved;
    await _guard.run(() async {
      saved = await _repo.upsertCustomer(customer);
      await _loadPage();
      if (_selected?.id == saved?.id) _selected = saved;
    });
    return saved;
  }

  Future<void> remove(Customer customer) async {
    await _guard.run(() async {
      await _repo.deleteCustomer(customer.id);
      await _loadPage();
      if (_selected?.id == customer.id) _selected = null;
    });
  }

  Future<void> reload() => _guard.run(_loadPage);

  Future<void> _loadPage({String? query}) async {
    final page = await _repo.fetchCustomerPage(query: query);
    _items = page.rows;
    _nextCursor = page.nextCursor;
  }

  void reset() {
    _items = const [];
    _nextCursor = null;
    _selected = null;
    notifyListeners();
  }
}
