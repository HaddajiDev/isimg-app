double? _num(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  final s = v.toString().trim();
  if (s.isEmpty) return null;
  return double.tryParse(s.replaceAll(',', '.'));
}

int _int(dynamic v) => _num(v)?.toInt() ?? 0;

String? _str(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

class TypeAbsence {
  final String type;
  final int nbre;

  const TypeAbsence({required this.type, required this.nbre});

  factory TypeAbsence.fromJson(Map<String, dynamic> j) =>
      TypeAbsence(type: _str(j['type']) ?? '', nbre: _int(j['nbre']));

  Map<String, dynamic> toJson() => {'type': type, 'nbre': nbre};
}

class MatiereAbsence {
  final String module;
  final String? matId;

  final double? taux;
  final bool eliminated;

  final String? elimineLabel;
  final List<TypeAbsence> parType;

  const MatiereAbsence({
    required this.module,
    this.matId,
    this.taux,
    this.eliminated = false,
    this.elimineLabel,
    this.parType = const [],
  });

  int get total => parType.fold(0, (sum, t) => sum + t.nbre);

  factory MatiereAbsence.fromJson(Map<String, dynamic> j) => MatiereAbsence(
        module: _str(j['module']) ?? '',
        matId: _str(j['matid']),
        taux: _num(j['taux']),
        eliminated: j['isElimine'] == true || j['isElimine']?.toString() == 'true',
        elimineLabel: _str(j['elimine']),
        parType: (j['MatStatType'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(TypeAbsence.fromJson)
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'module': module,
        'matid': matId,
        'taux': taux,
        'isElimine': eliminated,
        'elimine': elimineLabel,
        'MatStatType': parType.map((t) => t.toJson()).toList(),
      };
}

class AbsenceEntry {
  final String? date;
  final String? seance;
  final String? type;
  final String? enseignant;
  final String? module;

  const AbsenceEntry({this.date, this.seance, this.type, this.enseignant, this.module});

  factory AbsenceEntry.fromJson(Map<String, dynamic> j) => AbsenceEntry(
        date: _str(j['date']),
        seance: _str(j['seance']),
        type: _str(j['type']),
        enseignant: _str(j['prof']),
        module: _str(j['module']),
      );

  Map<String, dynamic> toJson() => {
        'date': date,
        'seance': seance,
        'type': type,
        'prof': enseignant,
        'module': module,
      };
}

class SemestreAbsences {
  final int semestre;

  final double? tauxGlobal;
  final int nbreGlobal;
  final String? elimGlobal;
  final List<AbsenceEntry> entries;
  final List<MatiereAbsence> matieres;

  const SemestreAbsences({
    required this.semestre,
    this.tauxGlobal,
    this.nbreGlobal = 0,
    this.elimGlobal,
    this.entries = const [],
    this.matieres = const [],
  });

  bool get isTracked => matieres.isNotEmpty;

  bool get isClean => nbreGlobal == 0;

  factory SemestreAbsences.fromJson(Map<String, dynamic> j, int semestre) => SemestreAbsences(
        semestre: semestre,
        tauxGlobal: _num(j['tauxglobal']),
        nbreGlobal: _int(j['nbreglobal']),
        elimGlobal: _str(j['elimglobal']),
        entries: (j['liste_absences'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(AbsenceEntry.fromJson)
            .toList(),
        matieres: (j['matieres'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(MatiereAbsence.fromJson)
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'tauxglobal': tauxGlobal,
        'nbreglobal': nbreGlobal,
        'elimglobal': elimGlobal,
        'liste_absences': entries.map((e) => e.toJson()).toList(),
        'matieres': matieres.map((m) => m.toJson()).toList(),
      };
}

class Absences {
  final int currentSemestre;
  final SemestreAbsences? s1;
  final SemestreAbsences? s2;

  final double matiereThreshold;
  final double globalThreshold;

  const Absences({
    this.currentSemestre = 1,
    this.s1,
    this.s2,
    this.matiereThreshold = 20,
    this.globalThreshold = 15,
  });

  Absences copyWith({double? matiereThreshold, double? globalThreshold}) => Absences(
        currentSemestre: currentSemestre,
        s1: s1,
        s2: s2,
        matiereThreshold: matiereThreshold ?? this.matiereThreshold,
        globalThreshold: globalThreshold ?? this.globalThreshold,
      );

  List<SemestreAbsences> get semesters =>
      [s1, s2].whereType<SemestreAbsences>().where((s) => s.isTracked).toList();

  bool get hasData => semesters.isNotEmpty;

  int get totalAbsences =>
      (s1?.nbreGlobal ?? 0) + (s2?.nbreGlobal ?? 0);

  factory Absences.fromJson(Map<String, dynamic> j) => Absences(
        currentSemestre: _int(j['current_semestre']),
        s1: j['bilan_s1'] is Map<String, dynamic>
            ? SemestreAbsences.fromJson(j['bilan_s1'] as Map<String, dynamic>, 1)
            : null,
        s2: j['bilan_s2'] is Map<String, dynamic>
            ? SemestreAbsences.fromJson(j['bilan_s2'] as Map<String, dynamic>, 2)
            : null,
        matiereThreshold: _num(j['matiereThreshold']) ?? 20,
        globalThreshold: _num(j['globalThreshold']) ?? 15,
      );

  Map<String, dynamic> toJson() => {
        'current_semestre': currentSemestre,
        'bilan_s1': s1?.toJson(),
        'bilan_s2': s2?.toJson(),
        'matiereThreshold': matiereThreshold,
        'globalThreshold': globalThreshold,
      };
}
