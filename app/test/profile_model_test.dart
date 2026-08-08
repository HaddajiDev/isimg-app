import 'package:flutter_test/flutter_test.dart';
import 'package:isimg_app/models/profile.dart';

CursusYear year(Map<String, dynamic> overrides) {
  return CursusYear.fromJson({
    'AU': '2025-2026',
    'Niveau': '2',
    'Classe': 'LSIM2',
    'Groupe': 'C',
    'N° Inscription': '2024666',
    'Statut': 'Nouveau',
    'Inscription': 'Confirmée',
    'Moyenne': '11.13',
    'Crédits': '48',
    'Résultat': 'Admis en session Principale',
    ...overrides,
  });
}

void main() {
  test('maps accented upstream headers', () {
    final y = year({});
    expect(y.annee, '2025-2026');
    expect(y.credits, '48');
    expect(y.resultat, 'Admis en session Principale');
    expect(y.numeroInscription, '2024666');
  });

  test('blank cells become null rather than empty strings', () {
    expect(year({'Groupe': ''}).groupe, isNull);
    expect(year({'Groupe': '   '}).groupe, isNull);
  });

  test('parses a moyenne carrying a trailing note', () {
    // A year still in progress reports e.g. "0 (S1)".
    expect(year({'Moyenne': '0 (S1)'}).moyenneValue, 0);
    expect(year({'Moyenne': '11.13'}).moyenneValue, 11.13);
    expect(year({'Moyenne': '10,56'}).moyenneValue, 10.56);
    expect(year({'Moyenne': ''}).moyenneValue, isNull);
  });

  test('classifies each résultat', () {
    expect(year({'Résultat': 'NC'}).isInProgress, isTrue);
    expect(year({'Résultat': ''}).isInProgress, isTrue);

    expect(year({'Résultat': 'Admis'}).isPassed, isTrue);
    expect(year({'Résultat': 'Admis en session Principale'}).isPassed, isTrue);
    expect(year({'Résultat': 'Admis'}).isInProgress, isFalse);

    expect(year({'Résultat': 'Redouble'}).isRepeated, isTrue);
    expect(year({'Résultat': 'Redouble'}).isPassed, isFalse);
  });

  test('builds name and initials', () {
    final profile = Profile.fromJson({
      'prenom': 'Ahmed',
      'nom': 'Haddaji',
      'years': <dynamic>[],
    });
    expect(profile.fullName, 'Ahmed Haddaji');
    expect(profile.initials, 'AH');
  });

  test('tolerates missing identity fields', () {
    final profile = Profile.fromJson({'years': <dynamic>[]});
    expect(profile.fullName, '');
    expect(profile.initials, '');
    expect(profile.cin, isNull);
  });
}
