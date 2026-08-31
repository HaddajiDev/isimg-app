import '../models/grade_tree.dart';

class ManualNoteKey {
  final String annee;
  final String session;
  final String semestre;
  final String unite;
  final String matiere;
  final int epreuveIndex;

  const ManualNoteKey({
    required this.annee,
    required this.session,
    required this.semestre,
    required this.unite,
    required this.matiere,
    required this.epreuveIndex,
  });

  String get storageKey =>
      [annee, session, semestre, unite, matiere, '$epreuveIndex'].join('§');

  static ManualNoteKey? tryParse(String raw) {
    final parts = raw.split('§');
    if (parts.length != 6) return null;
    final index = int.tryParse(parts[5]);
    if (index == null) return null;
    return ManualNoteKey(
      annee: parts[0],
      session: parts[1],
      semestre: parts[2],
      unite: parts[3],
      matiere: parts[4],
      epreuveIndex: index,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ManualNoteKey && other.storageKey == storageKey;

  @override
  int get hashCode => storageKey.hashCode;

  @override
  String toString() => storageKey;
}

class ManualNotes {
  final Map<String, double> _byKey;

  const ManualNotes(this._byKey);

  static const empty = ManualNotes({});

  double? noteFor(ManualNoteKey key) => _byKey[key.storageKey];

  bool get isEmpty => _byKey.isEmpty;
  int get length => _byKey.length;

  Map<String, double> get asMap => Map.unmodifiable(_byKey);

  ManualNotes set(ManualNoteKey key, double note) =>
      ManualNotes({..._byKey, key.storageKey: note});

  ManualNotes remove(ManualNoteKey key) {
    final next = {..._byKey}..remove(key.storageKey);
    return ManualNotes(next);
  }

  ManualNotes clearFor({required String annee, required String session}) {
    final prefix = '$annee§$session§';
    final next = {..._byKey}..removeWhere((key, _) => key.startsWith(prefix));
    return ManualNotes(next);
  }

  int countFor({required String annee, required String session}) {
    final prefix = '$annee§$session§';
    return _byKey.keys.where((key) => key.startsWith(prefix)).length;
  }
}

List<Semestre> applyManualNotes({
  required List<Semestre> semesters,
  required ManualNotes manual,
  required String annee,
  required String session,
}) {
  if (manual.isEmpty) return semesters;

  return semesters
      .map((semestre) => Semestre(
            label: semestre.label,
            unites: semestre.unites
                .map((unite) => Unite(
                      libelle: unite.libelle,
                      coefficient: unite.coefficient,
                      credits: unite.credits,
                      moyenne: unite.moyenne,
                      matieres: unite.matieres
                          .map((matiere) => Matiere(
                                libelle: matiere.libelle,
                                regime: matiere.regime,
                                coefficient: matiere.coefficient,
                                credits: matiere.credits,
                                moyenne: matiere.moyenne,
                                epreuves: _mergeEpreuves(
                                  matiere: matiere,
                                  unite: unite,
                                  semestre: semestre,
                                  manual: manual,
                                  annee: annee,
                                  session: session,
                                ),
                              ))
                          .toList(),
                    ))
                .toList(),
          ))
      .toList();
}

List<Epreuve> _mergeEpreuves({
  required Matiere matiere,
  required Unite unite,
  required Semestre semestre,
  required ManualNotes manual,
  required String annee,
  required String session,
}) {
  return List.generate(matiere.epreuves.length, (index) {
    final epreuve = matiere.epreuves[index];

    if (epreuve.note != null || epreuve.absent) return epreuve;

    final note = manual.noteFor(manualKeyFor(
      annee: annee,
      session: session,
      semestre: semestre,
      unite: unite,
      matiere: matiere,
      epreuveIndex: index,
    ));
    if (note == null) return epreuve;

    return Epreuve(
      libelle: epreuve.libelle,
      poids: epreuve.poids,
      note: note,
      isManual: true,
    );
  });
}

ManualNoteKey manualKeyFor({
  required String annee,
  required String session,
  required Semestre semestre,
  required Unite unite,
  required Matiere matiere,
  required int epreuveIndex,
}) {
  return ManualNoteKey(
    annee: annee,
    session: session,
    semestre: semestre.label,
    unite: unite.libelle,
    matiere: matiere.libelle,
    epreuveIndex: epreuveIndex,
  );
}
