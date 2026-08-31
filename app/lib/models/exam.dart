DateTime? _dateTime(dynamic v) {
  final s = v?.toString().trim() ?? '';
  if (s.isEmpty ||
      s == '0000-00-00 00:00:00' ||
      s == '0000-00-00' ||
      s == '2000-01-01 00:00:00') {
    return null;
  }
  return DateTime.tryParse(s);
}

int? _int(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString().trim());
}

bool _bool(dynamic v) => v == true || v == 1 || v?.toString() == '1';

String? _str(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

enum ExamType {
  ds,
  examen,
  controle,
  tp,
  oral,
  test,
  dc,
  pfe,
  expose,
  exercice,
  autre;

  String get label => switch (this) {
        ExamType.ds => 'DS',
        ExamType.examen => 'Examen',
        ExamType.controle => 'Contrôle',
        ExamType.tp => 'TP',
        ExamType.oral => 'Oral',
        ExamType.test => 'Test',
        ExamType.dc => 'DC',
        ExamType.pfe => 'PFE',
        ExamType.expose => 'Exposé',
        ExamType.exercice => 'Exercice',
        ExamType.autre => 'Autre',
      };

  int get code => switch (this) {
        ExamType.ds => 1,
        ExamType.examen => 2,
        ExamType.controle => 3,
        ExamType.tp => 4,
        ExamType.oral => 5,
        ExamType.test => 6,
        ExamType.dc => 7,
        ExamType.pfe => 8,
        ExamType.autre => 9,
        ExamType.expose => 10,
        ExamType.exercice => 11,
      };

  static ExamType fromCode(dynamic code) {
    switch (_int(code)) {
      case 1:
        return ExamType.ds;
      case 2:
        return ExamType.examen;
      case 3:
        return ExamType.controle;
      case 4:
        return ExamType.tp;
      case 5:
        return ExamType.oral;
      case 6:
        return ExamType.test;
      case 7:
        return ExamType.dc;
      case 8:
        return ExamType.pfe;
      case 10:
        return ExamType.expose;
      case 11:
        return ExamType.exercice;
      default:
        return ExamType.autre;
    }
  }
}

class Exam {
  final int? id;
  final String matiere;
  final ExamType type;

  final String? epreuve;

  final DateTime? debut;

  final DateTime? date;

  final String? horaire;

  final int? dureeMinutes;
  final String? salle;
  final String? enseignant;
  final String? classe;

  final bool eliminatoire;

  const Exam({
    this.id,
    required this.matiere,
    this.type = ExamType.autre,
    this.epreuve,
    this.debut,
    this.date,
    this.horaire,
    this.dureeMinutes,
    this.salle,
    this.enseignant,
    this.classe,
    this.eliminatoire = false,
  });

  DateTime get sortKey => debut ?? date ?? DateTime(9999);

  DateTime? get day {
    final d = debut ?? date;
    return d == null ? null : DateTime(d.year, d.month, d.day);
  }

  factory Exam.fromJson(Map<String, dynamic> j) => Exam(
        id: _int(j['id']),
        matiere: _str(j['module']) ?? '',
        type: ExamType.fromCode(j['type']),
        epreuve: _str(j['epreuve']),
        debut: _dateTime(j['debut']),
        date: _dateTime(j['date']),
        horaire: _str(j['horaire']),
        dureeMinutes: _int(j['duree']),
        salle: _str(j['salle']) ?? _str(j['abrev']),
        enseignant: _str(j['prof']),
        classe: _str(j['classe_name']),
        eliminatoire: _bool(j['elim']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'module': matiere,
        'type': type.code,
        'epreuve': epreuve,
        'debut': debut?.toIso8601String(),
        'date': date?.toIso8601String(),
        'horaire': horaire,
        'duree': dureeMinutes,
        'salle': salle,
        'prof': enseignant,
        'classe_name': classe,
        'elim': eliminatoire,
      };
}

class ExamsSchedule {
  final List<Exam> exams;

  const ExamsSchedule({this.exams = const []});

  bool get hasExams => exams.isNotEmpty;

  factory ExamsSchedule.fromJson(Map<String, dynamic> j) => ExamsSchedule(
        exams: (j['exams'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(Exam.fromJson)
            .toList(),
      );

  Map<String, dynamic> toJson() => {'exams': exams.map((e) => e.toJson()).toList()};
}
