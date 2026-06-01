import 'dart:io';

const _configuredApiBaseUrl = String.fromEnvironment('API_BASE_URL');

String get defaultApiBaseUrl {
  return defaultApiBaseUrls.first;
}

List<String> get defaultApiBaseUrls {
  if (_configuredApiBaseUrl.isNotEmpty) {
    if (Platform.isAndroid) {
      return _uniqueUrls([
        'http://127.0.0.1:3000',
        'http://localhost:3000',
        _configuredApiBaseUrl,
        'http://10.0.2.2:3000',
        'http://10.0.3.2:3000',
      ]);
    }
    return [_configuredApiBaseUrl];
  }
  if (Platform.isAndroid) {
    return [
      'http://127.0.0.1:3000',
      'http://localhost:3000',
      'http://10.0.2.2:3000',
      'http://10.0.3.2:3000',
    ];
  }
  return ['http://localhost:3000'];
}

List<String> _uniqueUrls(List<String> urls) {
  final seen = <String>{};
  return [
    for (final url in urls)
      if (seen.add(url)) url,
  ];
}
