import 'dart:convert';

String? _str(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return (s.isEmpty || s == 'null') ? null : s;
}

/// The server sends `yyyy-MM-dd HH:mm:ss`; zero dates mean "never".
DateTime? _date(dynamic v) {
  final s = _str(v);
  if (s == null || s.startsWith('0000') || s.startsWith('0001')) return null;
  return DateTime.tryParse(s);
}

/// Mirrors the official `Demande_Statut` enum (En_cours, Prête, Refusée), which
/// the server may send by index or by name.
enum DemandeStatut {
  enCours('En cours'),
  prete('Prête'),
  refusee('Refusée');

  final String label;
  const DemandeStatut(this.label);

  static DemandeStatut parse(dynamic raw) {
    final s = (_str(raw) ?? '').toLowerCase();
    if (s == '1' || s.startsWith('pr')) return prete;
    if (s == '2' || s.startsWith('ref')) return refusee;
    return enCours;
  }
}

/// Mirrors the official `TypeInput` enum (1-based), sent by index or name.
enum DemandeFieldType {
  texte,
  checkbox,
  file,
  label,
  radio,
  date,
  select;

  static DemandeFieldType parse(dynamic raw) {
    final s = (_str(raw) ?? '').toLowerCase();
    final n = int.tryParse(s);
    if (n != null && n >= 1 && n <= values.length) return values[n - 1];
    return values.firstWhere((t) => t.name == s, orElse: () => texte);
  }
}

class DemandeField {
  final String id;
  final String fieldId;
  final String label;
  final DemandeFieldType type;
  final List<String> choices;

  const DemandeField({
    required this.id,
    required this.fieldId,
    required this.label,
    required this.type,
    this.choices = const [],
  });

  /// Whether the student fills this field in (labels are display-only).
  bool get isInput => type != DemandeFieldType.label;

  factory DemandeField.fromJson(Map<String, dynamic> j) {
    final opts = _str(j['options']) ?? _str(j['valeurs']);
    return DemandeField(
      id: _str(j['id']) ?? '',
      fieldId: _str(j['field_id']) ?? '',
      label: _str(j['libele']) ?? '',
      type: DemandeFieldType.parse(j['input']),
      choices: opts == null
          ? const []
          : opts.split(',').map((c) => c.trim()).where((c) => c.isNotEmpty).toList(),
    );
  }
}

/// A request template ("Attestation de présence", …) with its form fields.
class DemandeModel {
  final String id;
  final String name;
  final String? titre;
  final List<DemandeField> fields;

  const DemandeModel({required this.id, required this.name, this.titre, this.fields = const []});

  /// File uploads aren't supported here — the official app uploads them in a
  /// separate step we haven't reverse-engineered.
  bool get needsFile => fields.any((f) => f.type == DemandeFieldType.file);

  factory DemandeModel.fromJson(Map<String, dynamic> j) {
    var fields = const <DemandeField>[];
    final raw = j['fields'];
    final list = raw is List ? raw : (raw is String && raw.trim().startsWith('[') ? jsonDecode(raw) : null);
    if (list is List) {
      fields = list.whereType<Map<String, dynamic>>().map(DemandeField.fromJson).toList();
    }
    return DemandeModel(
      id: _str(j['id']) ?? '',
      name: _str(j['name']) ?? 'Demande',
      titre: _str(j['titre']),
      fields: fields,
    );
  }
}

/// One answered field in a submitted request (`content` is a JSON array).
class DemandeValue {
  final String label;
  final String value;
  const DemandeValue({required this.label, required this.value});
}

class Demande {
  final String id;
  final String modeleId;
  final String name;
  final DemandeStatut statut;
  final List<DemandeValue> values;
  final String? rawContent;
  final DateTime? created;
  final DateTime? updated;
  final DateTime? ownerLastVisit;
  final DateTime? lastReply;

  const Demande({
    required this.id,
    required this.modeleId,
    required this.name,
    required this.statut,
    this.values = const [],
    this.rawContent,
    this.created,
    this.updated,
    this.ownerLastVisit,
    this.lastReply,
  });

  /// The administration replied after the student last opened it.
  bool get hasUnreadReply =>
      lastReply != null && (ownerLastVisit == null || lastReply!.isAfter(ownerLastVisit!));

  /// The official app only lets a pending request be cancelled.
  bool get canDelete => statut == DemandeStatut.enCours;

  factory Demande.fromJson(Map<String, dynamic> j) {
    final content = _str(j['content']);
    var values = const <DemandeValue>[];
    if (content != null && content.startsWith('[')) {
      try {
        values = (jsonDecode(content) as List)
            .whereType<Map<String, dynamic>>()
            .map((m) => DemandeValue(label: _str(m['label']) ?? '', value: _str(m['value']) ?? ''))
            .where((v) => v.value.isNotEmpty)
            .toList();
      } catch (_) {}
    }
    return Demande(
      id: _str(j['did']) ?? _str(j['id']) ?? '',
      modeleId: _str(j['modele_id']) ?? '',
      name: _str(j['name']) ?? 'Demande',
      statut: DemandeStatut.parse(j['status']),
      values: values,
      rawContent: values.isEmpty ? content : null,
      created: _date(j['created']),
      updated: _date(j['updated']),
      ownerLastVisit: _date(j['owner_last_visit']),
      lastReply: _date(j['convs']),
    );
  }
}

class DemandeMessage {
  final String who;
  final String message;
  final DateTime? when;

  const DemandeMessage({required this.who, required this.message, this.when});

  /// The official app tags the student's own messages `me`.
  bool get fromMe => who == 'me';

  factory DemandeMessage.fromJson(Map<String, dynamic> j) => DemandeMessage(
        who: _str(j['who']) ?? '',
        message: _str(j['message']) ?? '',
        when: _date(j['created']),
      );
}
