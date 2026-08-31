import 'package:flutter_test/flutter_test.dart';
import 'package:isimg_app/isimg/svc5_mapper.dart';
import 'package:isimg_app/models/seance.dart';

void main() {
  const slots = [
    '08:15-09:45',
    '09:55-11:25',
    '11:30-13:00',
    '14:00-15:30',
    '15:45-17:15',
  ];

  group('parseSlots', () {
    test('splits the config slot string, dropping the leading empty', () {
      expect(
        Svc5Mapper.parseSlots('#08:15-09:45#09:55-11:25#11:30-13:00#14:00-15:30#15:45-17:15'),
        slots,
      );
      expect(Svc5Mapper.parseSlots(null), isEmpty);
    });
  });

  group('mapCell (real timetable cells)', () {
    Seance cell(Map<String, dynamic> raw) => Svc5Mapper.mapCell(raw, slots);

    test('a course: type, slot, subject, teacher, room', () {
      final s = cell({'jour': 1, 'seance': '2', 'type': '0', 'rattrapagede': '0', 'texte': 'Cours réseaux Tesnim Mekki @A6'});
      expect(s.weekday, 1);
      expect(s.slot, '09:55-11:25');
      expect(s.type, SeanceType.cours);
      expect(s.matiere, 'réseaux');
      expect(s.enseignant, 'Tesnim Mekki');
      expect(s.salle, 'A6');
      expect(s.rattrapage, isFalse);
    });

    test('a TP with a multi-word subject keeps the last two tokens as teacher', () {
      final s = cell({'jour': 2, 'seance': '4', 'type': '2', 'rattrapagede': '0', 'texte': 'TP Base de données Rim Chamsi @Lab12'});
      expect(s.type, SeanceType.tp);
      expect(s.slot, '14:00-15:30');
      expect(s.matiere, 'Base de données');
      expect(s.enseignant, 'Rim Chamsi');
      expect(s.salle, 'Lab12');
    });

    test('subject with an apostrophe still splits correctly', () {
      final s = cell({'jour': 5, 'seance': '3', 'type': '0', 'rattrapagede': '0', 'texte': "Cours Création d'entreprise Rim Kamel @A1"});
      expect(s.matiere, "Création d'entreprise");
      expect(s.enseignant, 'Rim Kamel');
      expect(s.salle, 'A1');
    });

    test('a make-up is flagged by the id and the (Ratt.) suffix is stripped', () {
      final s = cell({'jour': 6, 'seance': '1', 'type': '0', 'rattrapagede': '195310', 'texte': 'Cours Systèmes info Fatma Achour @Lab11 (Ratt.)'});
      expect(s.rattrapage, isTrue);
      expect(s.matiere, 'Systèmes info');
      expect(s.enseignant, 'Fatma Achour');
      expect(s.salle, 'Lab11');
    });

    test('a TD maps to its type', () {
      expect(cell({'jour': 4, 'seance': '1', 'type': '1', 'texte': 'TD Anglais3 Mohamed Nouasria @S11'}).type, SeanceType.td);
    });
  });

  group('mapSchedule', () {
    test('empty week has no sessions', () {
      final s = Svc5Mapper.mapSchedule(const [], slots: slots);
      expect(s.hasSessions, isFalse);
      expect(s.sessions, isEmpty);
    });

    test('populated week reports sessions', () {
      final s = Svc5Mapper.mapSchedule([
        {'jour': 1, 'seance': '2', 'type': '0', 'texte': 'Cours X Ali Ben @A1'},
      ], slots: slots);
      expect(s.hasSessions, isTrue);
      expect(s.sessions, hasLength(1));
    });
  });

  group('mapGrades', () {
    Map<String, dynamic> releve() => {
          'session': 0,
          'affichage': {'afficher_notes_p1': '1'},
          'resultats': {
            'moyenne_p': '11.13', 'credits_p': '48', 'resultat_p': 'Admis en Session Principale',
            'moyenne_c': '0', 'credits_c': '0', 'resultat_c': 'NC',
          },
          'matieres': [
            {
              'unite_id': '510', 'unite_name': 'Uef520 : soa', 'semestre_unite': '1', 'ordre_unite': '2',
              'coeff_unite': '3', 'credits_unite': '6',
              'matiere_id': '9', 'module': 'SOA', 'shortname': 'SOA', 'semestre': '1', 'ordre_element': '1',
              'coeff': '2', 'credits': '4', 'regime': 'RM',
              'epreuves': [],
              'moyenne': {'moy_p': '10', 'moy_c': ''},
              'moyenne_unite': {'moy_p': '10.5', 'moy_c': ''},
            },
            {
              'unite_id': '509', 'unite_name': 'Uef510 : big data', 'semestre_unite': '1', 'ordre_unite': '1',
              'coeff_unite': '2', 'credits_unite': '4',
              'matiere_id': '1', 'module': 'Big Data', 'shortname': 'Big Data', 'semestre': '1', 'ordre_element': '1',
              'coeff': '1', 'credits': '2', 'regime': 'RM',
              'epreuves': [
                {'type': 'DS (0.15)', 'coeff': '0.15', 'note': '14', 'israttrapage': '0'},
                {'type': 'Ex (0.7)', 'coeff': '0.7', 'note': '', 'israttrapage': '0'},
                {'type': 'TP (0.15)', 'coeff': '0.15', 'note': 'Abs', 'israttrapage': '0'},
              ],
              'moyenne': {'moy_p': '13.5', 'moy_c': ''},
              'moyenne_unite': {'moy_p': '12', 'moy_c': ''},
            },
            {
              'unite_id': '669', 'unite_name': 'PFE', 'semestre_unite': '2', 'ordre_unite': '1',
              'coeff_unite': '15', 'credits_unite': '30',
              'matiere_id': '2', 'module': 'PFE', 'shortname': 'PFE', 'semestre': '2', 'ordre_element': '1',
              'coeff': '15', 'credits': '30', 'regime': 'RM',
              'epreuves': [],
              'moyenne': {'moy_p': '', 'moy_c': ''},
              'moyenne_unite': {'moy_p': '', 'moy_c': ''},
            },
          ],
        };

    test('builds two semesters with unites ordered by ordre_unite', () {
      final g = Svc5Mapper.mapGrades(releve(), au: '13', ss: '1');
      expect(g.semesters.map((s) => s.label), ['Semestre 1', 'Semestre 2']);
      final s1 = g.semesters.first;
      expect(s1.unites.map((u) => u.libelle), ['Uef510 : big data', 'Uef520 : soa']);
      final bigData = s1.unites.first;
      expect(bigData.coefficient, 2);
      expect(bigData.credits, 4);
      expect(bigData.moyenne, 12);
    });

    test('maps matière, coefficients and épreuve weights/notes', () {
      final g = Svc5Mapper.mapGrades(releve(), au: '13', ss: '1');
      final mat = g.semesters.first.unites.first.matieres.first;
      expect(mat.libelle, 'Big Data');
      expect(mat.coefficient, 1);
      expect(mat.credits, 2);
      expect(mat.moyenne, 13.5);
      expect(mat.epreuves, hasLength(3));
      expect(mat.epreuves[0].libelle, 'DS (0.15)');
      expect(mat.epreuves[0].poids, 0.15);
      expect(mat.epreuves[0].note, 14);
      expect(mat.epreuves[0].absent, isFalse);

      expect(mat.epreuves[1].note, isNull);
      expect(mat.epreuves[1].absent, isFalse);

      expect(mat.epreuves[2].absent, isTrue);
      expect(mat.epreuves[2].note, isNull);
    });

    test('principale session exposes the published general average', () {
      final g = Svc5Mapper.mapGrades(releve(), au: '13', ss: '1');
      expect(g.moyenneGenerale, '11.13');
      expect(g.credits, '48');
      expect(g.currentAu, '13');
      expect(g.currentSs, '1');
    });

    test('contrôle session (ss=2) reads moy_c and hides the NC general average', () {
      final g = Svc5Mapper.mapGrades(releve(), au: '13', ss: '2');
      expect(g.moyenneGenerale, isNull);
      final mat = g.semesters.first.unites.first.matieres.first;
      expect(mat.moyenne, isNull);
    });

    test('carries identity fields supplied by the caller', () {
      final g = Svc5Mapper.mapGrades(releve(), au: '13', ss: '1', nom: 'Haddaji', niveau: '3');
      expect(g.nom, 'Haddaji');
      expect(g.niveau, '3');
    });
  });

  group('graftEpreuveTemplates', () {
    List<Map<String, dynamic>> current() => [
          {'matiere_id': '1249', 'module': 'Big Data', 'semestre': '1', 'unite_id': '509', 'epreuves': <dynamic>[]},
          {'matiere_id': '9', 'module': 'SOA', 'semestre': '1', 'unite_id': '510', 'epreuves': [
            {'type': 'DS (0.3)', 'coeff': '0.3', 'note': '15', 'israttrapage': '0'},
          ]},
        ];

    List<Map<String, dynamic>> template() => [
          {'matiere_id': '1249', 'epreuves': [
            {'type': 'DS (0.15)', 'coeff': '0.15', 'note': '', 'israttrapage': '0'},
            {'type': 'Ex (0.7)', 'coeff': '0.7', 'note': '', 'israttrapage': '0'},
            {'type': 'TP (0.15)', 'coeff': '0.15', 'note': '', 'israttrapage': '0'},
            {'type': 'Rex (0.7)', 'coeff': '0.7', 'note': '', 'israttrapage': '1'},
          ]},
        ];

    test('grafts non-rattrapage slots onto matières that lack épreuves', () {
      final merged = Svc5Mapper.graftEpreuveTemplates(current(), template());
      final bigData = merged.firstWhere((m) => m['matiere_id'] == '1249');
      final eps = bigData['epreuves'] as List;

      expect(eps, hasLength(3));
      expect(eps.map((e) => e['type']), ['DS (0.15)', 'Ex (0.7)', 'TP (0.15)']);
      expect(eps.every((e) => (e['note'] as String).isEmpty), isTrue);
    });

    test('leaves matières that already have épreuves untouched', () {
      final merged = Svc5Mapper.graftEpreuveTemplates(current(), template());
      final soa = merged.firstWhere((m) => m['matiere_id'] == '9');
      expect((soa['epreuves'] as List), hasLength(1));
      expect((soa['epreuves'] as List).first['note'], '15');
    });

    test('the grafted slots map to editable épreuves', () {
      final merged = Svc5Mapper.graftEpreuveTemplates(current(), template());
      final grades = Svc5Mapper.mapGrades(
        <String, dynamic>{'matieres': merged, 'resultats': <String, dynamic>{}},
        au: '13',
        ss: '1',
      );
      final bigData = grades.semesters
          .expand((s) => s.unites)
          .expand((u) => u.matieres)
          .firstWhere((m) => m.libelle == 'Big Data');
      expect(bigData.epreuves, hasLength(3));

      expect(bigData.epreuves.every((e) => e.isEditable), isTrue);
      expect(bigData.epreuves[0].poids, 0.15);
    });
  });

  group('mapProfile', () {
    test('maps the core identity fields from GetProfileEtu', () {
      final p = Svc5Mapper.mapProfile({
        'prenom': 'Ahmed', 'nom': 'Haddaji', 'cin': '09729031',
        'diplome': '1ère année Licence en Informatique', 'classe_name': 'LSIM3',
      });
      expect(p.prenom, 'Ahmed');
      expect(p.nom, 'Haddaji');
      expect(p.cin, '09729031');
      expect(p.filiere, '1ère année Licence en Informatique');
      expect(p.fullName, 'Ahmed Haddaji');
      expect(p.initials, 'AH');
    });
  });
}
