/// One academic year from the "Mon cursus" table.
class CursusYear {
  final String? annee;
  final String? niveau;
  final String? classe;
  final String? groupe;
  final String? numeroInscription;
  final String? statut;
  final String? inscription;
  final String? moyenne;
  final String? credits;
  final String? resultat;

  CursusYear({
    this.annee,
    this.niveau,
    this.classe,
    this.groupe,
    this.numeroInscription,
    this.statut,
    this.inscription,
    this.moyenne,
    this.credits,
    this.resultat,
  });

  /// Keys mirror the upstream table headers verbatim, accents included.
  factory CursusYear.fromJson(Map<String, dynamic> json) {
    String? read(String key) {
      final value = json[key] as String?;
      return (value == null || value.trim().isEmpty) ? null : value.trim();
    }

    return CursusYear(
      annee: read('AU'),
      niveau: read('Niveau'),
      classe: read('Classe'),
      groupe: read('Groupe'),
      numeroInscription: read('N° Inscription'),
      statut: read('Statut'),
      inscription: read('Inscription'),
      moyenne: read('Moyenne'),
      credits: read('Crédits'),
      resultat: read('Résultat'),
    );
  }

  /// Leading numeric part of the moyenne — the site can append a note such as
  /// "0 (S1)" for a year still in progress.
  double? get moyenneValue {
    final match = RegExp(r'^-?\d+(?:[.,]\d+)?').firstMatch(moyenne ?? '');
    return match == null ? null : double.tryParse(match[0]!.replaceAll(',', '.'));
  }

  bool get isInProgress => resultat == null || resultat == 'NC';

  bool get isPassed {
    final r = resultat?.toLowerCase() ?? '';
    return r.contains('admis');
  }

  bool get isRepeated {
    final r = resultat?.toLowerCase() ?? '';
    return r.contains('redouble');
  }
}

class Profile {
  final String? prenom;
  final String? nom;
  final String? cin;
  final String? filiere;
  final List<CursusYear> years;

  Profile({this.prenom, this.nom, this.cin, this.filiere, required this.years});

  String get fullName => [prenom, nom].whereType<String>().join(' ');

  /// Initials for the avatar, e.g. "AH".
  String get initials {
    final parts = [prenom, nom].whereType<String>().where((p) => p.isNotEmpty);
    return parts.map((p) => p[0].toUpperCase()).take(2).join();
  }

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      prenom: json['prenom'] as String?,
      nom: json['nom'] as String?,
      cin: json['cin'] as String?,
      filiere: json['filiere'] as String?,
      years: (json['years'] as List<dynamic>? ?? [])
          .map((y) => CursusYear.fromJson(y as Map<String, dynamic>))
          .toList(),
    );
  }
}
