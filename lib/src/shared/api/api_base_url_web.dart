const _configuredApiBaseUrl = String.fromEnvironment('API_BASE_URL');

String get defaultApiBaseUrl {
  return defaultApiBaseUrls.first;
}

List<String> get defaultApiBaseUrls {
  if (_configuredApiBaseUrl.isNotEmpty) {
    return [_configuredApiBaseUrl];
  }
  return ['http://localhost:3000'];
}
