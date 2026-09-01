import 'dart:convert';

String? _str(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

bool _isNum(String? s) {
  final n = s == null ? null : num.tryParse(s);
  return n != null && n != 0;
}

DateTime? _dt(dynamic v) {
  final s = v?.toString().trim() ?? '';
  if (s.isEmpty ||
      s.startsWith('0000-00-00') ||
      s == '2000-01-01 00:00:00') {
    return null;
  }
  return DateTime.tryParse(s);
}

enum StageType {
  ouvrier,
  technicien,
  ingenieur;

  int get code => index;

  String get label => switch (this) {
        StageType.ouvrier => 'Stage ouvrier',
        StageType.technicien => 'Stage technicien',
        StageType.ingenieur => 'Stage ingénieur',
      };
}

class Stage {
  final StageType type;
  final DateTime? debut;
  final DateTime? fin;
  final String? lieu;
  final String? responsable;
  final String? adresse;
  final String? email;
  final String? phone;
  final String? fax;
  final String? sujet;
  final DateTime? dateDepot;
  final int validation;
  final int evaluation;
  final DateTime? soutenance;
  final String? salle;
  final List<String> jury;

  const Stage({
    required this.type,
    this.debut,
    this.fin,
    this.lieu,
    this.responsable,
    this.adresse,
    this.email,
    this.phone,
    this.fax,
    this.sujet,
    this.dateDepot,
    this.validation = 0,
    this.evaluation = 0,
    this.soutenance,
    this.salle,
    this.jury = const [],
  });

  String? get coordonnees {
    final parts = <String>[
      ?adresse,
      if (email != null && email!.contains('@')) '($email)',
      if (_isNum(phone)) 'Tél. : $phone',
      if (_isNum(fax)) 'Fax : $fax',
    ];
    return parts.isEmpty ? null : parts.join(' ');
  }

  String get validationLabel => switch (validation) {
        1 => 'Proposition acceptée',
        2 => 'Proposition refusée',
        _ => 'En instance',
      };

  String get evaluationLabel => switch (evaluation) {
        1 => 'Stage non validé',
        2 || 4 => 'Stage validé',
        3 => 'Stage validé avec corrections',
        _ => 'En instance',
      };

  bool get isValidated => evaluation == 2 || evaluation == 3 || evaluation == 4;
  bool get isRejected => evaluation == 1;

  static List<String> _parseJury(dynamic raw) {
    dynamic arr = raw;
    if (raw is String) {
      try {
        arr = jsonDecode(raw);
      } catch (_) {
        return const [];
      }
    }
    if (arr is! List) return const [];
    return arr.whereType<Map>().map((m) {
      final prof = _str(m['prof']) ?? '';
      final gmail = _str(m['gmail']);
      return gmail == null ? prof : '$prof ($gmail)';
    }).where((s) => s.trim().isNotEmpty).toList();
  }

  factory Stage.fromJson(Map<String, dynamic> j, {required StageType type}) => Stage(
        type: type,
        debut: _dt(j['debut']),
        fin: _dt(j['fin']),
        lieu: _str(j['lieu']),
        responsable: _str(j['responsable']),
        adresse: _str(j['adresse']),
        email: _str(j['email']),
        phone: _str(j['phone']),
        fax: _str(j['fax']),
        sujet: _str(j['sujet']),
        dateDepot: _dt(j['date_depot']),
        validation: int.tryParse(j['validation']?.toString() ?? '') ?? 0,
        evaluation: int.tryParse(j['evaluation']?.toString() ?? '') ?? 0,
        soutenance: _dt(j['debut_soutenance']),
        salle: _str(j['salle']),
        jury: _parseJury(j['jury']),
      );

  Map<String, dynamic> toJson() => {
        'type': type.code,
        'debut': debut?.toIso8601String(),
        'fin': fin?.toIso8601String(),
        'lieu': lieu,
        'responsable': responsable,
        'adresse': adresse,
        'email': email,
        'phone': phone,
        'fax': fax,
        'sujet': sujet,
        'date_depot': dateDepot?.toIso8601String(),
        'validation': validation,
        'evaluation': evaluation,
        'debut_soutenance': soutenance?.toIso8601String(),
        'salle': salle,
        'jury': jury,
      };

  factory Stage.fromCache(Map<String, dynamic> j) => Stage(
        type: StageType.values[(j['type'] as num?)?.toInt() ?? 0],
        debut: _dt(j['debut']),
        fin: _dt(j['fin']),
        lieu: _str(j['lieu']),
        responsable: _str(j['responsable']),
        adresse: _str(j['adresse']),
        email: _str(j['email']),
        phone: _str(j['phone']),
        fax: _str(j['fax']),
        sujet: _str(j['sujet']),
        dateDepot: _dt(j['date_depot']),
        validation: (j['validation'] as num?)?.toInt() ?? 0,
        evaluation: (j['evaluation'] as num?)?.toInt() ?? 0,
        soutenance: _dt(j['debut_soutenance']),
        salle: _str(j['salle']),
        jury: (j['jury'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
      );
}

class Stages {
  final List<Stage> stages;

  const Stages({this.stages = const []});

  bool get isEmpty => stages.isEmpty;

  factory Stages.fromJson(Map<String, dynamic> j) => Stages(
        stages: (j['stages'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(Stage.fromCache)
            .toList(),
      );

  Map<String, dynamic> toJson() => {'stages': stages.map((e) => e.toJson()).toList()};
}
