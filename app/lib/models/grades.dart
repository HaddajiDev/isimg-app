import 'grade_tree.dart';

class SelectOption {
  final String code;
  final String label;
  final bool selected;

  SelectOption({required this.code, required this.label, required this.selected});

  factory SelectOption.fromJson(Map<String, dynamic> json) {
    return SelectOption(
      code: json['code'] as String,
      label: json['label'] as String,
      selected: json['selected'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {'code': code, 'label': label, 'selected': selected};
}

class Grades {
  final String? nom;
  final String? cin;
  final String? filiere;
  final String? niveau;
  final String? moyenneGenerale;
  final String? credits;
  final String? rang;
  final List<Semestre> semesters;
  final List<SelectOption> annees;
  final List<SelectOption> sessions;

  final String? currentAu;
  final String? currentSs;

  Grades({
    this.nom,
    this.cin,
    this.filiere,
    this.niveau,
    this.moyenneGenerale,
    this.credits,
    this.rang,
    this.semesters = const [],
    this.annees = const [],
    this.sessions = const [],
    this.currentAu,
    this.currentSs,
  });

  factory Grades.fromJson(Map<String, dynamic> json) {
    return Grades(
      nom: json['nom'] as String?,
      cin: json['cin'] as String?,
      filiere: json['filiere'] as String?,
      niveau: json['niveau'] as String?,
      moyenneGenerale: json['moyenneGenerale'] as String?,
      credits: json['credits'] as String?,
      rang: json['rang'] as String?,
      semesters: (json['semesters'] as List<dynamic>? ?? [])
          .map((s) => Semestre.fromJson(s as Map<String, dynamic>))
          .toList(),
      annees: _options(json['annees']),
      sessions: _options(json['sessions']),
      currentAu: json['currentAu'] as String?,
      currentSs: json['currentSs'] as String?,
    );
  }

  static List<SelectOption> _options(dynamic raw) {
    return (raw as List<dynamic>? ?? [])
        .map((o) => SelectOption.fromJson(o as Map<String, dynamic>))
        .toList();
  }

  Map<String, dynamic> toJson() => {
        'nom': nom,
        'cin': cin,
        'filiere': filiere,
        'niveau': niveau,
        'moyenneGenerale': moyenneGenerale,
        'credits': credits,
        'rang': rang,
        'semesters': semesters.map((s) => s.toJson()).toList(),
        'annees': annees.map((o) => o.toJson()).toList(),
        'sessions': sessions.map((o) => o.toJson()).toList(),
        'currentAu': currentAu,
        'currentSs': currentSs,
      };
}
