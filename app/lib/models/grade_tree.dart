/// Grade hierarchy as published by the relevé page: semestre > unité >
/// matière > épreuve.
///
/// Mid-year the site posts notes as teachers enter them but leaves every
/// average blank until the deliberations, so any average may be null and is
/// filled in by [computeAverages].
library;

double? _num(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) {
    final match = RegExp(r'-?\d+(?:[.,]\d+)?').firstMatch(value);
    if (match != null) return double.tryParse(match[0]!.replaceAll(',', '.'));
  }
  return null;
}

class Epreuve {
  final String libelle;

  /// Share of the matière average, e.g. 0.3 for "DS (0.3)".
  final double? poids;
  final double? note;

  /// The site printed "Abs." — an absence, scored as zero. Distinct from a
  /// blank cell, which only means the mark has not been entered yet.
  final bool absent;

  /// Typed in by the student to project a result. Never present on data that
  /// came from the school.
  final bool isManual;

  const Epreuve({
    required this.libelle,
    this.poids,
    this.note,
    this.absent = false,
    this.isManual = false,
  });

  factory Epreuve.fromJson(Map<String, dynamic> json) => Epreuve(
        libelle: json['libelle'] as String? ?? '',
        poids: _num(json['poids']),
        note: _num(json['note']),
        absent: json['absent'] as bool? ?? false,
      );

  /// Counts towards the average: either a real mark, or a zero for an absence.
  bool get hasNote => note != null || absent;

  /// Value to average with — an absence contributes zero.
  double? get effectiveNote => absent ? (note ?? 0) : note;

  /// True when the student may supply a projection: the school has published
  /// neither a mark nor an absence for this slot.
  bool get isEditable => absent == false && (note == null || isManual);

  /// A rattrapage (session de contrôle) exam. How the school combines these
  /// with the main session is not modelled — see [computeAverages].
  bool get isRattrapage => libelle.toLowerCase().startsWith('rex');

  /// Round-trips through the offline cache. Manual notes are never cached —
  /// they live in their own store and are re-applied on top of fresh data.
  Map<String, dynamic> toJson() => {
        'libelle': libelle,
        'poids': poids,
        'note': note,
        'absent': absent,
      };
}

class Matiere {
  final String libelle;
  final String? regime;
  final double? coefficient;
  final double? credits;

  /// Average as published by the site; null until results are released.
  final double? moyenne;
  final List<Epreuve> epreuves;

  const Matiere({
    required this.libelle,
    this.regime,
    this.coefficient,
    this.credits,
    this.moyenne,
    this.epreuves = const [],
  });

  factory Matiere.fromJson(Map<String, dynamic> json) => Matiere(
        libelle: json['libelle'] as String? ?? '',
        regime: json['regime'] as String?,
        coefficient: _num(json['coefficient']),
        credits: _num(json['credits']),
        moyenne: _num(json['moyenne']),
        epreuves: (json['epreuves'] as List<dynamic>? ?? [])
            .map((e) => Epreuve.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'libelle': libelle,
        'regime': regime,
        'coefficient': coefficient,
        'credits': credits,
        'moyenne': moyenne,
        'epreuves': epreuves.map((e) => e.toJson()).toList(),
      };
}

class Unite {
  final String libelle;
  final double? coefficient;
  final double? credits;
  final double? moyenne;
  final List<Matiere> matieres;

  const Unite({
    required this.libelle,
    this.coefficient,
    this.credits,
    this.moyenne,
    this.matieres = const [],
  });

  factory Unite.fromJson(Map<String, dynamic> json) => Unite(
        libelle: json['libelle'] as String? ?? '',
        coefficient: _num(json['coefficient']),
        credits: _num(json['credits']),
        moyenne: _num(json['moyenne']),
        matieres: (json['matieres'] as List<dynamic>? ?? [])
            .map((m) => Matiere.fromJson(m as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'libelle': libelle,
        'coefficient': coefficient,
        'credits': credits,
        'moyenne': moyenne,
        'matieres': matieres.map((m) => m.toJson()).toList(),
      };
}

class Semestre {
  final String label;
  final List<Unite> unites;

  const Semestre({required this.label, this.unites = const []});

  factory Semestre.fromJson(Map<String, dynamic> json) => Semestre(
        label: json['semestre'] as String? ?? '',
        unites: (json['unites'] as List<dynamic>? ?? [])
            .map((u) => Unite.fromJson(u as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'semestre': label,
        'unites': unites.map((u) => u.toJson()).toList(),
      };
}
