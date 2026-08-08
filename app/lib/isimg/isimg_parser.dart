import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

import '../models/grade_tree.dart';
import '../models/grades.dart';
import '../models/profile.dart';
import '../models/schedule.dart';

/// Turns ISIMG's HTML into the app's models.
///
/// Ported from the retired backend. The quirks encoded here were each found the
/// hard way against the live site, so they are worth keeping intact:
///
///  * Denied or unknown routes answer 200 with the generic homepage rather than
///    an error, so every parse checks it landed on the expected page.
///  * The grades table repeats unit and subject cells with rowspan, so it must
///    be expanded into a grid before reading.
///  * "Abs." in a note cell is a scored zero, not a missing mark.
class IsimgParser {
  const IsimgParser();

  static final _number = RegExp(r'-?\d+(?:[.,]\d+)?');

  static double? _firstNumber(String? text) {
    final match = _number.firstMatch(text ?? '');
    if (match == null) return null;
    return double.tryParse(match[0]!.replaceAll(',', '.'));
  }

  static String _squash(String text) => text.replaceAll(RegExp(r'\s+'), ' ').trim();

  static bool _isUnauthorized(String body) => body.contains("Vous n'êtes pas autorisé");

  // ---- grades ----

  bool looksLikeGradesPage(String body) => body.contains('ISIMG - Relevés des Notes');

  Grades parseGrades(String body, {String? currentAu, String? currentSs}) {
    final doc = html_parser.parse(body);
    final content = doc.querySelector('#content');
    final contentText = content?.text ?? '';

    String? field(String label) {
      final match = RegExp('$label\\s*:\\s*([^\\n]+)').firstMatch(contentText);
      return match == null ? null : match[1]!.trim();
    }

    return Grades(
      nom: field('Nom Prénom'),
      cin: field(r'CIN \(code\)'),
      filiere: field('Filière'),
      niveau: field('Niveau'),
      moyenneGenerale: field('Moyenne générale'),
      credits: field('Crédits'),
      rang: field('Rang'),
      semesters: _parseGradeTree(doc),
      annees: _parseSelectOptions(doc, 'f_au'),
      sessions: _parseSelectOptions(doc, 'f_ss'),
      currentAu: currentAu,
      currentSs: currentSs,
    );
  }

  List<SelectOption> _parseSelectOptions(Document doc, String name) {
    final select = doc.querySelector('select[name="$name"]');
    if (select == null) return const [];

    return select
        .querySelectorAll('option')
        .map((option) {
          final code = option.attributes['value'];
          if (code == null || code.isEmpty) return null;
          return SelectOption(
            code: code,
            label: _squash(option.text),
            selected: option.attributes.containsKey('selected'),
          );
        })
        .whereType<SelectOption>()
        .toList();
  }

  /// Expands a table with rowspan/colspan into a plain grid of cell text.
  List<List<String>> _tableToGrid(Element table) {
    final grid = <int, Map<int, String>>{};

    final rows = table.querySelectorAll('tr');
    for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
      grid.putIfAbsent(rowIndex, () => {});
      var col = 0;

      for (final cell in rows[rowIndex].children.where(
        (e) => e.localName == 'td' || e.localName == 'th',
      )) {
        while (grid[rowIndex]!.containsKey(col)) {
          col++;
        }

        final rowspan = int.tryParse(cell.attributes['rowspan'] ?? '1') ?? 1;
        final colspan = int.tryParse(cell.attributes['colspan'] ?? '1') ?? 1;

        // <br> separates values that would otherwise run together.
        for (final br in cell.querySelectorAll('br')) {
          br.replaceWith(Text(' '));
        }
        final text = _squash(cell.text);

        for (var r = 0; r < rowspan; r++) {
          grid.putIfAbsent(rowIndex + r, () => {});
          for (var c = 0; c < colspan; c++) {
            grid[rowIndex + r]![col + c] = text;
          }
        }
        col += colspan;
      }
    }

    final result = <List<String>>[];
    final orderedRows = grid.keys.toList()..sort();
    for (final rowIndex in orderedRows) {
      final row = grid[rowIndex]!;
      if (row.isEmpty) continue;
      final width = (row.keys.reduce((a, b) => a > b ? a : b)) + 1;
      result.add(List.generate(width, (i) => row[i] ?? ''));
    }
    return result;
  }

  List<Semestre> _parseGradeTree(Document doc) {
    // The desktop table is the one carrying the coefficient columns.
    final table = doc.querySelector('#large table.mytable');
    if (table == null) return const [];

    final grid = _tableToGrid(table);
    if (grid.isEmpty) return const [];

    final header = grid.first;
    int col(String name) => header.indexOf(name);
    final idx = {
      'sem': col('Sem.'),
      'unite': col('Unité'),
      'coefUnite': col('Coef. Unité'),
      'matiere': col('Matière'),
      'regime': col('Régime'),
      'coefMatiere': col('Coeff'),
      'credits': col('Crédits'),
      'epreuve': col('Epreuve'),
      'note': col('Note'),
      'moyMatiere': col('Moy. Mat.'),
      'moyUnite': col('Moy. Unité.'),
    };

    // Ordered accumulation so semesters and units keep their printed order.
    final semesters = <String, Map<String, _UniteDraft>>{};

    for (final row in grid.skip(1)) {
      String cell(String key) {
        final i = idx[key]!;
        return (i >= 0 && i < row.length) ? row[i] : '';
      }

      final sem = cell('sem').trim();
      final uniteLabel = cell('unite').trim();
      final matiereLabel = cell('matiere').trim();
      if (sem.isEmpty && uniteLabel.isEmpty && matiereLabel.isEmpty) continue;

      final unites = semesters.putIfAbsent(sem, () => {});
      final unite = unites.putIfAbsent(uniteLabel, () {
        final credits = RegExp(r'Crédits\s*=\s*([\d.,]+)').firstMatch(uniteLabel);
        return _UniteDraft(
          libelle: uniteLabel.replaceAll(RegExp(r'\s*Crédits\s*=.*$'), '').trim(),
          coefficient: _firstNumber(cell('coefUnite')),
          credits: _firstNumber(credits?[1]),
          moyenne: _firstNumber(cell('moyUnite')),
        );
      });

      final matiere = unite.matieres.putIfAbsent(
        matiereLabel,
        () => _MatiereDraft(
          libelle: matiereLabel,
          regime: cell('regime').trim().isEmpty ? null : cell('regime').trim(),
          coefficient: _firstNumber(cell('coefMatiere')),
          credits: _firstNumber(cell('credits')),
          moyenne: _firstNumber(cell('moyMatiere')),
        ),
      );

      final epreuveLabel = cell('epreuve').trim();
      if (epreuveLabel.isNotEmpty) {
        final noteCell = cell('note').trim();
        final weight = RegExp(r'\(([^)]+)\)').firstMatch(epreuveLabel);
        matiere.epreuves.add(
          Epreuve(
            libelle: epreuveLabel,
            poids: _firstNumber(weight?[1]),
            note: _firstNumber(noteCell),
            // "Abs." is an absence the school scores as zero, quite different
            // from a blank cell meaning "not marked yet".
            absent: RegExp(r'^abs', caseSensitive: false).hasMatch(noteCell),
          ),
        );
      }
    }

    return semesters.entries
        .map(
          (sem) => Semestre(
            label: sem.key,
            unites: sem.value.values
                .map(
                  (u) => Unite(
                    libelle: u.libelle,
                    coefficient: u.coefficient,
                    credits: u.credits,
                    moyenne: u.moyenne,
                    matieres: u.matieres.values
                        .map(
                          (m) => Matiere(
                            libelle: m.libelle,
                            regime: m.regime,
                            coefficient: m.coefficient,
                            credits: m.credits,
                            moyenne: m.moyenne,
                            epreuves: m.epreuves,
                          ),
                        )
                        .toList(),
                  ),
                )
                .toList(),
          ),
        )
        .toList();
  }

  /// The value the site marks selected, else the first option.
  String? selectedCode(List<SelectOption> options) {
    for (final option in options) {
      if (option.selected) return option.code;
    }
    return null;
  }

  // ---- cursus / profile ----

  bool looksLikeCursusPage(String body) => body.contains('<title>ISIMG - Cursus</title>');

  Profile parseCursus(String body) {
    final doc = html_parser.parse(body);
    final content = doc.querySelector('#content');

    String? field(String label) {
      for (final p in content?.querySelectorAll('p.text-slate-500') ?? <Element>[]) {
        if (_squash(p.text) != label) continue;
        final whole = _squash(p.parent?.text ?? '');
        final value = whole.substring(label.length).trim();
        return value.isEmpty ? null : value;
      }
      return null;
    }

    final table = content?.querySelector('table');
    final years = <CursusYear>[];

    if (table != null) {
      final rows = table.querySelectorAll('tr');
      if (rows.isNotEmpty) {
        final headers = rows.first.children
            .where((e) => e.localName == 'th' || e.localName == 'td')
            .map((e) => _squash(e.text))
            .toList();

        for (final row in rows.skip(1)) {
          final cells = row.children
              .where((e) => e.localName == 'td' || e.localName == 'th')
              .map((e) => _squash(e.text))
              .toList();
          if (cells.isEmpty) continue;

          years.add(
            CursusYear.fromJson({
              for (var i = 0; i < headers.length; i++)
                headers[i]: i < cells.length ? cells[i] : null,
            }),
          );
        }
      }
    }

    final filiere = content?.querySelector('h2');

    return Profile(
      prenom: field('Prénom'),
      nom: field('Nom'),
      cin: field('CIN'),
      filiere: filiere == null ? null : _squash(filiere.text),
      years: years,
    );
  }

  // ---- schedule ----

  bool looksLikeSchedulePage(String body) => body.contains('id="desktop-view"');

  Schedule parseSchedule(String body) {
    final doc = html_parser.parse(body);
    // Month names carry accents, so \w+ would not match "août".
    final week = RegExp(r'(\d{2}\s*→\s*\d{2}\s+\p{L}+\s+\d{4})', unicode: true)
        .firstMatch(body);
    final noSessions =
        body.contains('Aucune séance') || body.contains('Aucun cours cette semaine');

    return Schedule(
      weekLabel: week?[1],
      hasSessions: !noSessions,
      rawContentHtml: doc.querySelector('#desktop-view')?.innerHtml,
    );
  }

  bool isUnauthorized(String body) => _isUnauthorized(body);
}

class _UniteDraft {
  final String libelle;
  final double? coefficient;
  final double? credits;
  final double? moyenne;
  final Map<String, _MatiereDraft> matieres = {};

  _UniteDraft({
    required this.libelle,
    this.coefficient,
    this.credits,
    this.moyenne,
  });
}

class _MatiereDraft {
  final String libelle;
  final String? regime;
  final double? coefficient;
  final double? credits;
  final double? moyenne;
  final List<Epreuve> epreuves = [];

  _MatiereDraft({
    required this.libelle,
    this.regime,
    this.coefficient,
    this.credits,
    this.moyenne,
  });
}
