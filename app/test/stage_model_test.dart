import 'package:flutter_test/flutter_test.dart';
import 'package:isimg_app/models/stage.dart';

void main() {
  group('Stage.fromJson', () {
    test('maps a validated stage with a jury string', () {
      final stage = Stage.fromJson({
        'debut': '2026-07-01',
        'fin': '2026-07-31',
        'lieu': 'Tunisie Telecom',
        'responsable': 'M. Bouzid',
        'adresse': 'Gabès',
        'email': 'a@b.tn',
        'phone': '75000000',
        'fax': '0',
        'sujet': 'Réseau',
        'date_depot': '2026-08-05',
        'validation': '1',
        'evaluation': '4',
        'debut_soutenance': '0000-00-00 00:00:00',
        'salle': '',
        'jury': '[{"prof":"A. Karim","gmail":"k@isimg.tn"},{"prof":"B. Salah","gmail":""}]',
      }, type: StageType.ouvrier);

      expect(stage.type, StageType.ouvrier);
      expect(stage.type.label, 'Stage ouvrier');
      expect(stage.debut, DateTime(2026, 7, 1));
      expect(stage.isValidated, isTrue);
      expect(stage.evaluationLabel, 'Stage validé');
      expect(stage.validationLabel, 'Proposition acceptée');
      expect(stage.soutenance, isNull);
      expect(stage.jury, ['A. Karim (k@isimg.tn)', 'B. Salah']);
      expect(stage.coordonnees, contains('(a@b.tn)'));
      expect(stage.coordonnees, contains('Tél. : 75000000'));
      expect(stage.coordonnees, isNot(contains('Fax')));
    });

    test('round-trips through the cache form', () {
      final original = Stage.fromJson({
        'debut': '2026-07-01',
        'validation': '0',
        'evaluation': '0',
        'jury': '[]',
      }, type: StageType.ingenieur);

      final restored = Stage.fromCache(original.toJson());
      expect(restored.type, StageType.ingenieur);
      expect(restored.debut, DateTime(2026, 7, 1));
      expect(restored.evaluationLabel, 'En instance');
    });
  });
}
