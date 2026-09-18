final _yearPrefix = RegExp(
  r'^\s*\d+\s*(?:ère|ere|ème|eme|e)?\s*année\s+',
  caseSensitive: false,
);

/// ISIMG names a diploma with a fixed "Nème année " prefix (e.g. "1ère année
/// Licence en Informatique et Multimédia") that has nothing to do with the
/// student's actual level — so it contradicts the "Niveau N" shown beside it.
/// Strip that leading prefix for display.
String? cleanFiliere(String? raw) {
  if (raw == null) return null;
  final cleaned = raw.replaceFirst(_yearPrefix, '').trim();
  return cleaned.isEmpty ? raw.trim() : cleaned;
}
