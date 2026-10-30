String? _str(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return (s.isEmpty || s == 'null') ? null : s;
}

/// Strips HTML the way the official app's `HTMLToText` does: `<br>` becomes a
/// newline, every other tag is dropped, common entities are decoded.
String? _text(dynamic v) {
  final s = _str(v);
  if (s == null) return null;
  final out = s
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
  return out.isEmpty ? null : out;
}

/// The student's final-year project (PFE), from `GetPFE`.
class Pfe {
  final String? sujet;
  final String? lieu;
  final List<String> encadreurs;
  final String? description;
  final String? travail;
  final String? outils;

  final DateTime? soutenance;
  final int? dureeMinutes;
  final String? salle;
  final DateTime? dateDepot;
  final String? plagiat;
  final String? president;
  final String? rapporteur;
  final double? note;
  final String? mention;

  const Pfe({
    this.sujet,
    this.lieu,
    this.encadreurs = const [],
    this.description,
    this.travail,
    this.outils,
    this.soutenance,
    this.dureeMinutes,
    this.salle,
    this.dateDepot,
    this.plagiat,
    this.president,
    this.rapporteur,
    this.note,
    this.mention,
  });

  bool get hasDefense =>
      soutenance != null || president != null || rapporteur != null || note != null;

  factory Pfe.fromJson(Map<String, dynamic> j) {
    final noteRaw = _str(j['note'])?.replaceAll(',', '.');
    final note = noteRaw == null ? null : double.tryParse(noteRaw);
    final plagiat = _str(j['plagiat']);
    return Pfe(
      sujet: _str(j['sujet']),
      lieu: _str(j['lieu']),
      encadreurs: [
        _str(j['enc']),
        _str(j['coenc']),
        _str(j['enc_ext']),
      ].whereType<String>().toList(),
      description: _text(j['description']),
      travail: _text(j['travail']),
      outils: _str(j['outils']),
      soutenance: DateTime.tryParse(_str(j['debut']) ?? ''),
      dureeMinutes: int.tryParse(_str(j['duree']) ?? ''),
      salle: _str(j['salle']),
      dateDepot: DateTime.tryParse(_str(j['date_depot']) ?? ''),
      plagiat: plagiat == null ? null : '$plagiat %',
      president: _str(j['president']),
      rapporteur: _str(j['rapporteur']),
      // The server sends 0 before the defense is graded.
      note: (note == null || note == 0) ? null : note,
      mention: _str(j['mention']),
    );
  }
}
