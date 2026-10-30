import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:isimg_app/models/demande.dart';
import 'package:isimg_app/models/pfe.dart';

void main() {
  group('Demande models', () {
    test('field types parse by index or name', () {
      expect(DemandeFieldType.parse('1'), DemandeFieldType.texte);
      expect(DemandeFieldType.parse('7'), DemandeFieldType.select);
      expect(DemandeFieldType.parse('Date'), DemandeFieldType.date);
      expect(DemandeFieldType.parse('FILE'), DemandeFieldType.file);
    });

    test('statut parses by index or name', () {
      expect(DemandeStatut.parse('0'), DemandeStatut.enCours);
      expect(DemandeStatut.parse('1'), DemandeStatut.prete);
      expect(DemandeStatut.parse('Refusée'), DemandeStatut.refusee);
    });

    test('model decodes its fields from a JSON string, with choices', () {
      final m = DemandeModel.fromJson({
        'id': '4',
        'name': 'Attestation',
        'titre': 'Attestation de présence',
        'fields': jsonEncode([
          {'id': '10', 'field_id': '1', 'libele': 'Exemplaires', 'input': '7', 'options': '1, 2,3', 'valeurs': ''},
          {'id': '11', 'field_id': '2', 'libele': 'Justificatif', 'input': '3', 'options': '', 'valeurs': ''},
        ]),
      });
      expect(m.fields, hasLength(2));
      expect(m.fields.first.type, DemandeFieldType.select);
      expect(m.fields.first.choices, ['1', '2', '3']);
      expect(m.needsFile, isTrue);
    });

    test('model with null fields has none', () {
      expect(DemandeModel.fromJson({'id': '1', 'name': 'X', 'fields': 'null'}).fields, isEmpty);
    });

    test('request decodes JSON content, status and unread reply', () {
      final d = Demande.fromJson({
        'did': '77',
        'modele_id': '4',
        'name': 'Attestation',
        'status': '0',
        'content': jsonEncode([
          {'label': 'Motif', 'value': 'Bourse', 'file': false},
          {'label': 'Vide', 'value': '', 'file': false},
        ]),
        'created': '2026-10-01 09:00:00',
        'updated': '0000-00-00 00:00:00',
        'owner_last_visit': '2026-10-02 10:00:00',
        'convs': '2026-10-03 11:00:00',
      });
      expect(d.id, '77');
      expect(d.values.map((v) => v.label), ['Motif']);
      expect(d.updated, isNull);
      expect(d.hasUnreadReply, isTrue);
      expect(d.canDelete, isTrue);
    });

    test('legacy plain-text content is kept raw', () {
      final d = Demande.fromJson({'did': '1', 'name': 'X', 'status': '1', 'content': 'ancien format'});
      expect(d.values, isEmpty);
      expect(d.rawContent, 'ancien format');
      expect(d.canDelete, isFalse);
    });

    test('messages from the student are tagged me', () {
      expect(DemandeMessage.fromJson({'who': 'me', 'message': 'ok'}).fromMe, isTrue);
      expect(DemandeMessage.fromJson({'who': 'admin', 'message': 'ok'}).fromMe, isFalse);
    });
  });

  group('Pfe', () {
    test('strips HTML, joins supervisors, hides an ungraded 0', () {
      final p = Pfe.fromJson({
        'sujet': 'App mobile',
        'lieu': 'ISIMG',
        'description': '<p>Ligne&nbsp;1<br/>Ligne 2</p>',
        'travail': '',
        'outils': 'Flutter',
        'enc': 'A. Prof',
        'coenc': '',
        'enc_ext': 'B. Ext',
        'debut': '2026-06-20 10:00:00',
        'duree': '45',
        'salle': 'A12',
        'date_depot': '',
        'plagiat': '',
        'president': '',
        'rapporteur': '',
        'note': '0',
        'mention': '',
      });
      expect(p.description, 'Ligne 1\nLigne 2');
      expect(p.travail, isNull);
      expect(p.encadreurs, ['A. Prof', 'B. Ext']);
      expect(p.note, isNull);
      expect(p.soutenance, DateTime(2026, 6, 20, 10));
      expect(p.hasDefense, isTrue);
    });
  });
}
