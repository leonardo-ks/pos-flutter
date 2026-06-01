import '../api/api_client.dart';
import '../models/feature_record.dart';

class PagedFeatureRecords {
  const PagedFeatureRecords({required this.rows, this.nextCursor});

  final List<FeatureRecord> rows;
  final String? nextCursor;
}

abstract class FeatureRepository {
  Future<List<FeatureRecord>> list(String path, {Map<String, String>? query});
  Future<PagedFeatureRecords> listPage(
    String path, {
    Map<String, String>? query,
  });
  Future<FeatureRecord> save(String path, Map<String, Object?> body, {int? id});
  Future<List<FeatureRecord>> saveBatch(
    String path,
    List<Map<String, Object?>> items, {
    List<int> deleteIds = const [],
  });
  Future<void> delete(String path, int id);
  Future<List<int>> exportReport(String kind, Map<String, String> query);
}

class MockFeatureRepository implements FeatureRepository {
  final Map<String, List<FeatureRecord>> _records = {
    '/api/suppliers': [
      const FeatureRecord({
        'id': 1,
        'kode': 'SUP-001',
        'nama': 'Suplier Utama',
        'telepon': '08123456789',
        'keterangan': 'Demo',
      }),
    ],
    '/api/locations': [
      const FeatureRecord({
        'id': 1,
        'kode': 'UTM',
        'nama': 'Gudang Utama',
        'keterangan': 'Lokasi bawaan',
      }),
    ],
    '/api/product-categories': [
      const FeatureRecord({
        'id': 1,
        'kode': 'UMUM',
        'nama': 'Umum',
        'keterangan': 'Kategori bawaan',
      }),
    ],
    '/api/customer-group-discounts': [
      const FeatureRecord({
        'id': 1,
        'customer_id': 1,
        'customer_name': 'Rani Wijaya',
        'category_id': 1,
        'category_name': 'Umum',
        'rate': 0.10,
        'keterangan': 'Diskon pelanggan VIP untuk grup umum',
      }),
      const FeatureRecord({
        'id': 2,
        'customer_id': 3,
        'customer_name': 'Maya Pratama',
        'category_id': 1,
        'category_name': 'Umum',
        'rate': 0.15,
        'keterangan': 'Diskon pelanggan Gold untuk grup umum',
      }),
    ],
    '/api/discount-categories': [
      const FeatureRecord({
        'id': 1,
        'kode': 'Reguler',
        'nama': 'Reguler',
        'rate': 0,
        'keterangan': 'Tanpa diskon',
      }),
      const FeatureRecord({
        'id': 2,
        'kode': 'VIP',
        'nama': 'VIP',
        'rate': 0.10,
        'keterangan': 'Diskon VIP',
      }),
      const FeatureRecord({
        'id': 3,
        'kode': 'Gold',
        'nama': 'Gold',
        'rate': 0.15,
        'keterangan': 'Diskon Gold',
      }),
    ],
    '/api/payables': [],
    '/api/receivables': [],
    '/api/cash-entries': [],
    '/api/purchases': [],
    '/api/purchase-returns': [],
    '/api/sales-returns': [],
    '/api/users': [
      const FeatureRecord({
        'id': 1,
        'nama': 'Dewi Kasir',
        'username': 'kasir',
        'role': 'kasir',
      }),
      const FeatureRecord({
        'id': 2,
        'nama': 'Bima Manajer',
        'username': 'manajer',
        'role': 'manajer',
      }),
      const FeatureRecord({
        'id': 3,
        'nama': 'Ari Administrator',
        'username': 'admin',
        'role': 'administrator',
      }),
    ],
    '/api/roles': [
      const FeatureRecord({
        'id': 1,
        'kode': 'kasir',
        'nama': 'Kasir',
        'keterangan': 'Akses kasir operasional.',
        'system_role': true,
      }),
      const FeatureRecord({
        'id': 2,
        'kode': 'manajer',
        'nama': 'Manajer',
        'keterangan': 'Akses manajemen toko.',
        'system_role': true,
      }),
      const FeatureRecord({
        'id': 3,
        'kode': 'administrator',
        'nama': 'Administrator',
        'keterangan': 'Akses penuh sistem.',
        'system_role': true,
      }),
    ],
    '/api/role-permissions': [
      const FeatureRecord({
        'id': 1,
        'role': 'administrator',
        'section': 'authorization',
        'can_view': true,
        'can_create': true,
        'can_update': true,
        'can_delete': true,
      }),
    ],
    '/api/stock': [],
  };

  @override
  Future<List<FeatureRecord>> list(
    String path, {
    Map<String, String>? query,
  }) async {
    return (await listPage(path, query: query)).rows;
  }

  @override
  Future<PagedFeatureRecords> listPage(
    String path, {
    Map<String, String>? query,
  }) async {
    if (path.startsWith('/api/reports/')) {
      return const PagedFeatureRecords(rows: []);
    }
    return PagedFeatureRecords(
      rows: List.unmodifiable(_records[path] ?? const []),
    );
  }

  @override
  Future<FeatureRecord> save(
    String path,
    Map<String, Object?> body, {
    int? id,
  }) async {
    final list = _records.putIfAbsent(path, () => []);
    final nextId = id ?? (list.length + 1);
    final saved = FeatureRecord({'id': nextId, ...body});
    final index = list.indexWhere((record) => record.id == nextId);
    if (index == -1) {
      list.add(saved);
    } else {
      list[index] = saved;
    }
    return saved;
  }

  @override
  Future<List<FeatureRecord>> saveBatch(
    String path,
    List<Map<String, Object?>> items, {
    List<int> deleteIds = const [],
  }) async {
    for (final id in deleteIds) {
      await delete(path, id);
    }
    final saved = <FeatureRecord>[];
    for (final item in items) {
      saved.add(await save(path, item, id: item['id'] as int?));
    }
    return saved;
  }

  @override
  Future<void> delete(String path, int id) async {
    final list = _records[path];
    list?.removeWhere((record) => record.id == id);
  }

  @override
  Future<List<int>> exportReport(String kind, Map<String, String> query) async {
    return const [];
  }
}

class ApiFeatureRepository implements FeatureRepository {
  ApiFeatureRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<List<FeatureRecord>> list(String path, {Map<String, String>? query}) {
    return listPage(path, query: query).then((page) => page.rows);
  }

  @override
  Future<PagedFeatureRecords> listPage(
    String path, {
    Map<String, String>? query,
  }) {
    return _apiClient.get<PagedFeatureRecords>(path, (data) {
      if (data is Map && data['rows'] is List) {
        return PagedFeatureRecords(
          rows: (data['rows'] as List)
              .map(
                (item) => FeatureRecord((item as Map).cast<String, Object?>()),
              )
              .toList(growable: false),
          nextCursor: data['next_cursor'] as String?,
        );
      }
      return PagedFeatureRecords(
        rows: (data as List)
            .map((item) => FeatureRecord((item as Map).cast<String, Object?>()))
            .toList(growable: false),
      );
    }, query: query);
  }

  @override
  Future<FeatureRecord> save(
    String path,
    Map<String, Object?> body, {
    int? id,
  }) {
    if (id == null || id == 0) {
      return _apiClient.post<FeatureRecord>(
        path,
        body,
        (data) => FeatureRecord((data as Map).cast<String, Object?>()),
      );
    }
    return _apiClient.patch<FeatureRecord>(
      '$path/$id',
      body,
      (data) => FeatureRecord((data as Map).cast<String, Object?>()),
    );
  }

  @override
  Future<List<FeatureRecord>> saveBatch(
    String path,
    List<Map<String, Object?>> items, {
    List<int> deleteIds = const [],
  }) {
    return _apiClient.post<List<FeatureRecord>>(
      path,
      {'items': items, 'delete_ids': deleteIds},
      (data) => (data as List)
          .map((item) => FeatureRecord((item as Map).cast<String, Object?>()))
          .toList(growable: false),
    );
  }

  @override
  Future<void> delete(String path, int id) async {
    await _apiClient.delete<void>('$path/$id', (_) {});
  }

  @override
  Future<List<int>> exportReport(String kind, Map<String, String> query) {
    return _apiClient.download('/api/reports/$kind/export', query: query);
  }
}
