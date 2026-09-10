// ignore_for_file: prefer_initializing_formals
// (private fields can't be named parameters, so the initializer list is required)
import 'package:flutter/foundation.dart';

import '../../shared/models/feature_record.dart';
import '../../shared/repositories/feature_repository.dart';
import '../async_guard.dart';
import 'product_controller.dart';

class FeatureRecordController extends ChangeNotifier {
  FeatureRecordController(
    this._guard,
    this._repo, {
    required ProductController products,
  }) : _products = products;

  final AsyncGuard _guard;
  final FeatureRepository _repo;
  final ProductController _products;

  final Map<String, List<FeatureRecord>> _records = {};
  final Map<String, String> _queryKeys = {};
  final Map<String, String?> _nextCursors = {};
  final Map<String, Future<void>> _loadFutures = {};
  String _selectedGenericReport = 'purchases';

  String get selectedGenericReport => _selectedGenericReport;

  List<FeatureRecord> records(String path) =>
      List.unmodifiable(_records[path] ?? const []);

  List<FeatureRecord> get customerGroupDiscounts =>
      records('/api/customer-group-discounts');

  bool canLoadMore(String path, {Map<String, String>? query}) {
    if (_nextCursors[path] == null) return false;
    if (query == null) return true;
    return _queryKeys[path] == _queryKey(query);
  }

  Future<void> load(
    String path, {
    Map<String, String>? query,
    bool force = false,
  }) async {
    final cacheKey = _queryKey(query);
    if (!force && _records.containsKey(path) && _queryKeys[path] == cacheKey) {
      return;
    }
    final loadKey = '$path?$cacheKey';
    final existingLoad = _loadFutures[loadKey];
    if (existingLoad != null) {
      await existingLoad;
      return;
    }
    late Future<void> load;
    load = _guard.run(() async {
      final page = await _repo.listPage(path, query: query);
      _records[path] = page.rows;
      _nextCursors[path] = page.nextCursor;
      _queryKeys[path] = cacheKey;
    });
    _loadFutures[loadKey] = load;
    try {
      await load;
    } finally {
      _loadFutures.remove(loadKey);
    }
  }

  Future<void> loadMore(String path, {Map<String, String>? query}) async {
    final cursor = _nextCursors[path];
    if (cursor == null) return;
    final nextQuery = {...?query, 'cursor': cursor};
    final baseCacheKey = _queryKey(query);
    final loadKey = '$path?more:${_queryKey(nextQuery)}';
    final existingLoad = _loadFutures[loadKey];
    if (existingLoad != null) {
      await existingLoad;
      return;
    }
    late Future<void> load;
    load = _guard.run(() async {
      final page = await _repo.listPage(path, query: nextQuery);
      final current = _records[path] ?? const <FeatureRecord>[];
      _records[path] = [...current, ...page.rows];
      _nextCursors[path] = page.nextCursor;
      _queryKeys[path] = baseCacheKey;
    });
    _loadFutures[loadKey] = load;
    try {
      await load;
    } finally {
      _loadFutures.remove(loadKey);
    }
  }

  Future<FeatureRecord?> save(
    String path,
    Map<String, Object?> body, {
    int? id,
  }) async {
    FeatureRecord? saved;
    await _guard.run(() async {
      saved = await _repo.save(path, body, id: id);
      final page = await _repo.listPage(path);
      _records[path] = page.rows;
      _nextCursors[path] = page.nextCursor;
      _queryKeys[path] = _queryKey(null);
      if (path.contains('purchases') ||
          path.contains('returns') ||
          path == '/api/stock' ||
          path == '/api/cash-entries') {
        await _products.reload();
        invalidateReports();
      }
    });
    return saved;
  }

  Future<void> saveCustomerGroupDiscounts(
    List<Map<String, Object?>> items, {
    List<int> deleteIds = const [],
  }) async {
    await _guard.run(() async {
      await _repo.saveBatch(
        '/api/customer-group-discounts',
        items,
        deleteIds: deleteIds,
      );
      final page = await _repo.listPage('/api/customer-group-discounts');
      _records['/api/customer-group-discounts'] = page.rows;
      _nextCursors['/api/customer-group-discounts'] = page.nextCursor;
      _queryKeys['/api/customer-group-discounts'] = _queryKey(null);
    });
  }

  Future<void> remove(String path, FeatureRecord record) async {
    await _guard.run(() async {
      await _repo.delete(path, record.id);
      final page = await _repo.listPage(path);
      _records[path] = page.rows;
      _nextCursors[path] = page.nextCursor;
      _queryKeys[path] = _queryKey(null);
      invalidateReports();
    });
  }

  Future<List<FeatureRecord>> loadGenericReport(
    String kind,
    Map<String, String> query,
  ) async {
    _selectedGenericReport = kind;
    final path = '/api/reports/$kind';
    await load(path, query: query);
    return records(path);
  }

  Future<void> loadMoreGenericReport(String kind, Map<String, String> query) =>
      loadMore('/api/reports/$kind', query: query);

  Future<List<int>?> exportGenericReport(
    String kind,
    Map<String, String> query,
  ) async {
    List<int>? bytes;
    await _guard.run(() async {
      bytes = await _repo.exportReport(kind, query);
    });
    return bytes;
  }

  void invalidateReports() {
    final reportPaths = _records.keys
        .where((path) => path.startsWith('/api/reports/'))
        .toList(growable: false);
    for (final path in reportPaths) {
      _records.remove(path);
      _queryKeys.remove(path);
      _nextCursors.remove(path);
    }
  }

  String _queryKey(Map<String, String>? query) {
    if (query == null || query.isEmpty) return '';
    final keys = query.keys.toList()..sort();
    return keys.map((key) => '$key=${query[key]}').join('&');
  }

  void reset() {
    _records.clear();
    _queryKeys.clear();
    _nextCursors.clear();
    _loadFutures.clear();
    _selectedGenericReport = 'purchases';
    notifyListeners();
  }
}
