import 'package:flutter_test/flutter_test.dart';
import 'package:isimg_app/models/news.dart';
import 'package:isimg_app/models/notifications.dart';
import 'package:isimg_app/models/stage.dart';

void main() {
  group('NewsItem.fromJson', () {
    test('maps the svc5 GetNews fields and strips HTML from the body', () {
      final item = NewsItem.fromJson({
        'id': '42',
        'auteur': 'Administration',
        'titre': 'Reprise des cours',
        'description': 'Les cours reprennent lundi.',
        'sujet': '<p>Bonjour&nbsp;à&nbsp;tous.</p><br/>Rendez-vous <b>lundi</b>.',
        'groups': '1,2,3',
        'created': '2026-01-05 09:30:00',
      });

      expect(item.id, '42');
      expect(item.auteur, 'Administration');
      expect(item.titre, 'Reprise des cours');
      expect(item.description, 'Les cours reprennent lundi.');
      expect(item.body, isNot(contains('<')));
      expect(item.body, contains('Bonjour à tous.'));
      expect(item.body, contains('Rendez-vous lundi.'));
      expect(item.groupes, ['1', '2', '3']);
      expect(item.created, DateTime(2026, 1, 5, 9, 30));
    });

    test('survives blank dates and empty groups', () {
      final item = NewsItem.fromJson({
        'id': '1',
        'titre': 'X',
        'sujet': '',
        'groups': '',
        'created': '0000-00-00 00:00:00',
      });
      expect(item.created, isNull);
      expect(item.groupes, isEmpty);
      expect(item.body, '');
    });
  });

  group('NotifData.fromJson', () {
    test('reads notifs and per-type counts', () {
      final data = NotifData.fromJson({
        'notifs': [
          {'title': 'Note', 'message': 'Nouvelle note', 'pageid': '-1', 'extrainfos': ''},
          {'title': 'Actu', 'message': 'Annonce', 'pageid': '1', 'extrainfos': 'x'},
        ],
        'nbres': [
          {'type': '1', 'nbre': '2'},
          {'type': '5', 'nbre': '3'},
        ],
      });

      expect(data.items, hasLength(2));
      expect(data.items.first.title, 'Note');
      expect(data.items[1].kind, NotifKind.news);
      expect(data.total, 5);
      expect(data.counts.first.kind, NotifKind.news);
      expect(data.counts.first.count, 2);
      expect(data.counts[1].kind, NotifKind.notes);
    });
  });

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
