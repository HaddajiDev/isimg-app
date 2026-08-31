import '../models/grades.dart';
import '../models/grade_tree.dart';
import '../models/profile.dart';
import '../models/schedule.dart';
import '../models/seance.dart';

class Svc5Mapper {
  const Svc5Mapper._();

  static String? _str(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  static double? _num(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    final m = RegExp(r'-?\d+(?:[.,]\d+)?').firstMatch(s);
    return m == null ? null : double.tryParse(m[0]!.replaceAll(',', '.'));
  }

  static List<String> parseSlots(String? seances) {
    if (seances == null) return const [];
    return seances.split('#').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  }

  static SeanceType _typeFromCode(dynamic code) => switch (code?.toString().trim()) {
        '0' => SeanceType.cours,
        '1' => SeanceType.td,
        '2' => SeanceType.tp,
        _ => SeanceType.autre,
      };

  static Seance mapCell(Map<String, dynamic> cell, List<String> slots) {
    final weekday = _num(cell['jour'])?.toInt() ?? 1;
    final slotIndex = _num(cell['seance'])?.toInt() ?? 0;
    final slot = (slotIndex >= 1 && slotIndex <= slots.length) ? slots[slotIndex - 1] : '';
    final type = _typeFromCode(cell['type']);

    var text = (cell['texte'] ?? '').toString().trim();

    final rattFlag = (cell['rattrapagede']?.toString() ?? '0');
    final rattrapage = (rattFlag.isNotEmpty && rattFlag != '0') ||
        RegExp(r'\(ratt\.?\)', caseSensitive: false).hasMatch(text);
    text = text.replaceAll(RegExp(r'\s*\(ratt\.?\)\s*$', caseSensitive: false), '').trim();

    String? salle;
    final at = text.lastIndexOf('@');
    if (at != -1) {
      salle = text.substring(at + 1).trim();
      text = text.substring(0, at).trim();
    }

    text = text.replaceFirst(RegExp(r'^(cours|td|tp)\s+', caseSensitive: false), '').trim();

    String matiere = text;
    String? enseignant;
    final tokens = text.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    if (tokens.length >= 3) {
      enseignant = tokens.sublist(tokens.length - 2).join(' ');
      matiere = tokens.sublist(0, tokens.length - 2).join(' ');
    }

    return Seance(
      weekday: weekday,
      slot: slot,
      type: type,
      matiere: matiere,
      enseignant: enseignant,
      salle: (salle != null && salle.isEmpty) ? null : salle,
      rattrapage: rattrapage,
    );
  }

  static Schedule mapSchedule(List<dynamic> cells, {required List<String> slots}) {
    final sessions = cells
        .whereType<Map<String, dynamic>>()
        .map((c) => mapCell(c, slots))
        .toList();
    return Schedule(hasSessions: sessions.isNotEmpty, sessions: sessions);
  }

  static Profile mapProfile(Map<String, dynamic> r, {List<CursusYear> years = const []}) {
    return Profile(
      prenom: _str(r['prenom']),
      nom: _str(r['nom']),
      cin: _str(r['cin']),
      filiere: _str(r['diplome']),
      years: years,
    );
  }

  static List<Map<String, dynamic>> graftEpreuveTemplates(
    List<dynamic> current,
    List<dynamic> template,
  ) {
    final byId = <String, Map<String, dynamic>>{};
    for (final m in template.whereType<Map<String, dynamic>>()) {
      final id = m['matiere_id']?.toString();
      if (id != null) byId[id] = m;
    }

    return current.whereType<Map<String, dynamic>>().map((m) {
      final existing = m['epreuves'];
      if (existing is List && existing.isNotEmpty) return m;

      final tmpl = byId[m['matiere_id']?.toString()];
      if (tmpl == null) return m;

      final slots = (tmpl['epreuves'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .where((e) =>
              e['israttrapage']?.toString() != '1' &&
              !(e['type']?.toString().toLowerCase().startsWith('rex') ?? false))
          .map((e) => {...e, 'note': ''})
          .toList();
      if (slots.isEmpty) return m;

      return {...m, 'epreuves': slots};
    }).toList();
  }

  static bool _controle(String? ss) => ss == '2';

  static Grades mapGrades(
    Map<String, dynamic> releve, {
    String? au,
    String? ss,
    String? nom,
    String? cin,
    String? filiere,
    String? niveau,
    List<SelectOption> annees = const [],
    List<SelectOption> sessions = const [],
  }) {
    final controle = _controle(ss);
    final matieres = (releve['matieres'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();

    final bySemestre = <int, Map<String, _UnitAcc>>{};
    for (final m in matieres) {
      final sem = _num(m['semestre'])?.toInt() ?? _num(m['semestre_unite'])?.toInt() ?? 0;
      final uid = (m['unite_id'] ?? '').toString();
      final unit = bySemestre
          .putIfAbsent(sem, () => {})
          .putIfAbsent(uid, () => _UnitAcc(m, controle));
      unit.matieres.add(_matiere(m, controle));
    }

    final semesters = <Semestre>[];
    final semKeys = bySemestre.keys.toList()..sort();
    for (final sem in semKeys) {
      final units = bySemestre[sem]!.values.toList()
        ..sort((a, b) => a.ordre.compareTo(b.ordre));
      semesters.add(Semestre(
        label: 'Semestre $sem',
        unites: units.map((u) => u.build()).toList(),
      ));
    }

    final results = releve['resultats'] as Map<String, dynamic>? ?? const {};
    final resultat = _str(results[controle ? 'resultat_c' : 'resultat_p']);
    final published = resultat != null && resultat.toUpperCase() != 'NC';
    final moyenne = _str(results[controle ? 'moyenne_c' : 'moyenne_p']);
    final credits = _str(results[controle ? 'credits_c' : 'credits_p']);

    return Grades(
      nom: nom,
      cin: cin,
      filiere: filiere,
      niveau: niveau,
      moyenneGenerale: published ? moyenne : null,
      credits: published ? credits : null,
      rang: null,
      semesters: semesters,
      annees: annees,
      sessions: sessions,
      currentAu: au,
      currentSs: ss,
    );
  }

  static Matiere _matiere(Map<String, dynamic> m, bool controle) {
    final moy = m['moyenne'] as Map<String, dynamic>? ?? const {};
    final epreuves = (m['epreuves'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(_epreuve)
        .toList();
    return Matiere(
      libelle: _str(m['module']) ?? _str(m['shortname']) ?? '',
      regime: _str(m['regime']),
      coefficient: _num(m['coeff']),
      credits: _num(m['credits']),
      moyenne: _num(moy[controle ? 'moy_c' : 'moy_p']),
      epreuves: epreuves,
    );
  }

  static Epreuve _epreuve(Map<String, dynamic> e) {
    final rawNote = e['note']?.toString().trim() ?? '';
    final absent = RegExp(r'^abs', caseSensitive: false).hasMatch(rawNote);
    return Epreuve(
      libelle: _str(e['type']) ?? '',
      poids: _num(e['coeff']),
      note: absent ? null : _num(e['note']),
      absent: absent,
    );
  }
}

class _UnitAcc {
  final String libelle;
  final int ordre;
  final double? coefficient;
  final double? credits;
  final double? moyenne;
  final List<Matiere> matieres = [];

  _UnitAcc(Map<String, dynamic> m, bool controle)
      : libelle = Svc5Mapper._str(m['unite_name']) ?? '',
        ordre = Svc5Mapper._num(m['ordre_unite'])?.toInt() ?? 0,
        coefficient = Svc5Mapper._num(m['coeff_unite']),
        credits = Svc5Mapper._num(m['credits_unite']),
        moyenne = Svc5Mapper._num(
          (m['moyenne_unite'] as Map<String, dynamic>? ?? const {})[
              controle ? 'moy_c' : 'moy_p'],
        );

  Unite build() => Unite(
        libelle: libelle,
        coefficient: coefficient,
        credits: credits,
        moyenne: moyenne,
        matieres: matieres,
      );
}
