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

  /// [date] as a calendar day, or null when it can't be read.
  DateTime? get day => _parseDate(date);

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

  /// A key for one absent class slot: its date plus the 1-based séance index,
  /// e.g. `2026-9-12#3`. Used to flag the matching cell in the timetable.
  static String slotKey(DateTime date, int seanceIndex) =>
      '${date.year}-${date.month}-${date.day}#$seanceIndex';

  /// Every recorded individual absence, keyed the same way, across both
  /// semesters. Empty when the server returned no per-class list.
  Set<String> get absentSlots {
    final keys = <String>{};
    for (final sem in [s1, s2].whereType<SemestreAbsences>()) {
      for (final e in sem.entries) {
        final date = e.day;
        final seance = int.tryParse(e.seance?.trim() ?? '');
        if (date != null && seance != null) {
          keys.add(slotKey(date, seance));
        }
      }
    }
    return keys;
  }

  /// Every recorded absence as a date (duplicates kept — one per missed class),
  /// across both semesters. Feeds the attendance-streak computation.
  List<DateTime> get absentDates {
    final out = <DateTime>[];
    for (final sem in [s1, s2].whereType<SemestreAbsences>()) {
      for (final e in sem.entries) {
        final date = e.day;
        if (date != null) out.add(date);
      }
    }
    return out;
  }

  SubjectAbsences forSubject(String name) {
    final ordered = [
      ...[s1, s2].whereType<SemestreAbsences>().where((s) => s.semestre == currentSemestre),
      ...[s1, s2].whereType<SemestreAbsences>().where((s) => s.semestre != currentSemestre),
    ];

    final candidates = <String>{
      for (final sem in ordered) ...[
        for (final m in sem.matieres) _subjectKey(m.module),
        for (final e in sem.entries)
          if (e.module != null) _subjectKey(e.module!),
      ],
    }..remove('');
    final match = _bestSubjectMatch(_subjectKey(name), candidates);

    bool same(String? other) => match != null && other != null && _subjectKey(other) == match;

    MatiereAbsence? stats;
    for (final sem in ordered) {
      stats = sem.matieres.where((m) => same(m.module)).firstOrNull;
      if (stats != null) break;
    }

    final entries = [
      for (final sem in ordered)
        for (final e in sem.entries)
          if (same(e.module)) e,
    ]..sort((a, b) {
        final da = a.day, db = b.day;
        if (da == null || db == null) return da == null ? (db == null ? 0 : 1) : -1;
        final byDay = db.compareTo(da);
        if (byDay != 0) return byDay;
        return (int.tryParse(a.seance ?? '') ?? 0).compareTo(int.tryParse(b.seance ?? '') ?? 0);
      });

    return SubjectAbsences(stats: stats, entries: entries, threshold: matiereThreshold);
  }

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

/// Parses the API's absence date, tolerating both `yyyy-MM-dd` (with an optional
/// time) and `dd/MM/yyyy`.
DateTime? _parseDate(String? raw) {
  final s = raw?.trim() ?? '';
  if (s.isEmpty) return null;
  final iso = DateTime.tryParse(s);
  if (iso != null) return DateTime(iso.year, iso.month, iso.day);
  final parts = s.split(RegExp(r'[/\-.]'));
  if (parts.length == 3) {
    final a = int.tryParse(parts[0]);
    final b = int.tryParse(parts[1]);
    final c = int.tryParse(parts[2]);
    if (a != null && b != null && c != null) {
      // dd/MM/yyyy
      return DateTime(c, b, a);
    }
  }
  return null;
}

class SubjectAbsences {
  final MatiereAbsence? stats;
  final List<AbsenceEntry> entries;
  final double threshold;

  const SubjectAbsences({required this.stats, required this.entries, required this.threshold});

  bool get isTracked => stats != null || entries.isNotEmpty;

  int get count => stats?.total ?? entries.length;
}

String _subjectKey(String raw) {
  const accents = {
    'à': 'a', 'â': 'a', 'ä': 'a', 'á': 'a',
    'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
    'î': 'i', 'ï': 'i', 'í': 'i',
    'ô': 'o', 'ö': 'o', 'ó': 'o',
    'û': 'u', 'ü': 'u', 'ù': 'u', 'ú': 'u',
    'ç': 'c',
  };
  final lower = raw.toLowerCase();
  final buf = StringBuffer();
  String? previous;
  for (final ch in lower.split('')) {
    final c = accents[ch] ?? ch;
    final isLetter = RegExp(r'[a-z]').hasMatch(c);
    final isDigit = RegExp(r'[0-9]').hasMatch(c);
    if (!isLetter && !isDigit) {
      buf.write(' ');
      previous = null;
      continue;
    }
    final kind = isLetter ? 'a' : '0';
    if (previous != null && previous != kind) buf.write(' ');
    buf.write(c);
    previous = kind;
  }
  return buf.toString().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).join(' ');
}

const _stopWords = {
  'a', 'au', 'aux', 'd', 'de', 'des', 'du', 'en', 'et', 'l', 'la', 'le', 'les', 'pour', 'sur',
};

int _subjectScore(String short, String official) {
  if (short == official) return 3;
  final shortWords = short.split(' ');
  final officialWords = official.split(' ').toSet();
  if (shortWords.every(officialWords.contains)) return 2;
  if (shortWords.length == 1 && short.length >= 2 && short.length <= 5) {
    final initials = official
        .split(' ')
        .where((w) => !_stopWords.contains(w) && RegExp(r'^[a-z]').hasMatch(w))
        .map((w) => w[0])
        .join();
    if (initials == short) return 2;
  }
  return 0;
}

String? _bestSubjectMatch(String short, Set<String> candidates) {
  if (short.isEmpty) return null;
  var words = short.split(' ');
  while (words.isNotEmpty) {
    final key = words.join(' ');
    var best = 0;
    final winners = <String>[];
    for (final c in candidates) {
      final score = _subjectScore(key, c);
      if (score == 0 || score < best) continue;
      if (score > best) {
        best = score;
        winners.clear();
      }
      winners.add(c);
    }
    if (winners.length == 1) return winners.single;
    if (winners.length > 1) return null;
    words = words.sublist(0, words.length - 1);
    if (words.join(' ').length < 5) return null;
  }
  return null;
}
