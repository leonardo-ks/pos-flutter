import '../../shared/api/api_client.dart';
import '../../shared/data/mock_data_store.dart';
import '../models/customer.dart';

abstract class CustomerRepository {
  Future<PagedCustomers> fetchCustomerPage({String? query, String? cursor});
  Future<List<Customer>> fetchCustomers({String? query});
  Future<Customer> upsertCustomer(Customer customer);
  Future<void> deleteCustomer(int id);
}

class PagedCustomers {
  const PagedCustomers({required this.rows, this.nextCursor});

  final List<Customer> rows;
  final String? nextCursor;
}

class MockCustomerRepository implements CustomerRepository {
  MockCustomerRepository(this._store);

  final MockDataStore _store;

  @override
  Future<PagedCustomers> fetchCustomerPage({
    String? query,
    String? cursor,
  }) async {
    final rows = await fetchCustomers(query: query);
    return PagedCustomers(rows: rows, nextCursor: null);
  }

  @override
  Future<List<Customer>> fetchCustomers({String? query}) async {
    final normalized = query?.trim().toLowerCase() ?? '';
    if (normalized.isEmpty) return List.unmodifiable(_store.customers);
    return _store.customers
        .where(
          (customer) =>
              customer.name.toLowerCase().contains(normalized) ||
              customer.phone.contains(normalized),
        )
        .toList(growable: false);
  }

  @override
  Future<Customer> upsertCustomer(Customer customer) async {
    final index = _store.customers.indexWhere((item) => item.id == customer.id);
    if (index == -1 || customer.id == 0) {
      final nextId = _store.customers.isEmpty
          ? 1
          : _store.customers
                    .map((item) => item.id)
                    .reduce((a, b) => a > b ? a : b) +
                1;
      final saved = customer.copyWith(id: nextId);
      _store.customers.add(saved);
      return saved;
    }

    _store.customers[index] = customer;
    return customer;
  }

  @override
  Future<void> deleteCustomer(int id) async {
    _store.customers.removeWhere((customer) => customer.id == id);
  }
}

class ApiCustomerRepository implements CustomerRepository {
  ApiCustomerRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<PagedCustomers> fetchCustomerPage({String? query, String? cursor}) {
    final params = <String, String>{};
    final search = query?.trim();
    if (search != null && search.isNotEmpty) params['q'] = search;
    if (cursor != null && cursor.isNotEmpty) params['cursor'] = cursor;
    return _apiClient.get<PagedCustomers>('/api/customers', (data) {
      final map = data as Map;
      final rows = (map['rows'] as List)
          .map(
            (item) => Customer.fromJson((item as Map).cast<String, Object?>()),
          )
          .toList(growable: false);
      return PagedCustomers(
        rows: rows,
        nextCursor: map['next_cursor'] as String?,
      );
    }, query: params.isEmpty ? null : params);
  }

  @override
  Future<List<Customer>> fetchCustomers({String? query}) {
    return fetchCustomerPage(query: query).then((page) => page.rows);
  }

  @override
  Future<Customer> upsertCustomer(Customer customer) {
    if (customer.id == 0) {
      return _apiClient.post<Customer>(
        '/api/customers',
        customer.toApiJson(),
        (data) => Customer.fromJson((data as Map).cast<String, Object?>()),
      );
    }
    return _apiClient.patch<Customer>(
      '/api/customers/${customer.id}',
      customer.toApiJson(),
      (data) => Customer.fromJson((data as Map).cast<String, Object?>()),
    );
  }

  @override
  Future<void> deleteCustomer(int id) async {
    await _apiClient.delete<void>('/api/customers/$id', (_) {});
  }
}
