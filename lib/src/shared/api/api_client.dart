import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_base_url.dart';

class ApiClient {
  ApiClient({String? baseUrl, http.Client? httpClient})
    : baseUrls = baseUrl == null ? defaultApiBaseUrls : [baseUrl],
      _httpClient = httpClient ?? http.Client();

  String get baseUrl => baseUrls.first;

  final List<String> baseUrls;
  final http.Client _httpClient;
  String? _userId;
  String? _bearerToken;

  void setUserId(int? userId) {
    _userId = userId?.toString();
  }

  void setBearerToken(String? token) {
    _bearerToken = token;
  }

  Future<T> get<T>(
    String path,
    T Function(Object? data) parse, {
    Map<String, String>? query,
  }) async {
    final response = await _send(
      path,
      query: query,
      request: (uri) => _httpClient.get(uri, headers: _headers()),
    );
    return _decode(response, parse);
  }

  Future<T> post<T>(
    String path,
    Object body,
    T Function(Object? data) parse,
  ) async {
    final response = await _send(
      path,
      request: (uri) =>
          _httpClient.post(uri, headers: _headers(), body: jsonEncode(body)),
    );
    return _decode(response, parse);
  }

  Future<T> patch<T>(
    String path,
    Object body,
    T Function(Object? data) parse,
  ) async {
    final response = await _send(
      path,
      request: (uri) =>
          _httpClient.patch(uri, headers: _headers(), body: jsonEncode(body)),
    );
    return _decode(response, parse);
  }

  Future<T> delete<T>(String path, T Function(Object? data) parse) async {
    final response = await _send(
      path,
      request: (uri) => _httpClient.delete(uri, headers: _headers()),
    );
    return _decode(response, parse);
  }

  Future<List<int>> download(String path, {Map<String, String>? query}) async {
    final response = await _send(
      path,
      query: query,
      request: (uri) => _httpClient.get(uri, headers: _headers()),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _decode<void>(response, (_) {});
    }
    return response.bodyBytes;
  }

  Future<http.Response> _send(
    String path, {
    Map<String, String>? query,
    required Future<http.Response> Function(Uri uri) request,
  }) async {
    Object? lastError;
    for (final baseUrl in baseUrls) {
      try {
        return await request(_uri(baseUrl, path, query));
      } catch (error) {
        lastError = error;
      }
    }
    throw ApiException(
      'Tidak bisa terhubung ke API. Pastikan backend berjalan dan koneksi emulator aktif.',
      0,
      cause: lastError,
    );
  }

  Uri _uri(String baseUrl, String path, [Map<String, String>? query]) {
    final normalizedBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return Uri.parse(
      '$normalizedBase$path',
    ).replace(queryParameters: query?.isEmpty ?? true ? null : query);
  }

  Map<String, String> _headers() {
    final headers = {'content-type': 'application/json'};
    final userId = _userId;
    if (userId != null) {
      headers['x-user-id'] = userId;
    }
    final bearerToken = _bearerToken;
    if (bearerToken != null) {
      headers['authorization'] = 'Bearer $bearerToken';
    }
    return headers;
  }

  T _decode<T>(http.Response response, T Function(Object? data) parse) {
    final body = response.body.isEmpty
        ? <String, Object?>{}
        : jsonDecode(response.body) as Map<String, Object?>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = body['error'];
      if (error is Map<String, Object?> && error['message'] is String) {
        throw ApiException(error['message'] as String, response.statusCode);
      }
      throw ApiException('Request API gagal.', response.statusCode);
    }
    return parse(body['data']);
  }
}

class ApiException implements Exception {
  const ApiException(this.message, this.statusCode, {this.cause});

  final String message;
  final int statusCode;
  final Object? cause;

  @override
  String toString() => message;
}
