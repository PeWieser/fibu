/// Formatiert eine Byte-Anzahl menschenlesbar (B, KB, MB, GB, TB).
/// Basis 1024, iOS/Apple-konforme Kurzform.
String formatBytes(int bytes) {
  if (bytes < 0) return '0 B';
  if (bytes < 1024) return '$bytes B';
  const units = ['KB', 'MB', 'GB', 'TB'];
  var value = bytes / 1024.0;
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024.0;
    unit++;
  }
  final formatted = value >= 100 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
  return '$formatted ${units[unit]}';
}
