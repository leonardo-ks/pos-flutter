class FeatureRecord {
  const FeatureRecord(this.values);

  final Map<String, Object?> values;

  int get id => (values['id'] as num?)?.toInt() ?? 0;

  String label(List<String> preferredKeys) {
    for (final key in preferredKeys) {
      final value = values[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }
    return id == 0 ? 'Data baru' : '#$id';
  }
}
