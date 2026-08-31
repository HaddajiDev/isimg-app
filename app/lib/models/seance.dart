enum SeanceType {
  cours,
  td,
  tp,
  autre;

  String get label => switch (this) {
        SeanceType.cours => 'Cours',
        SeanceType.td => 'TD',
        SeanceType.tp => 'TP',
        SeanceType.autre => '',
      };

  static SeanceType parse(String? raw) => switch (raw?.toLowerCase().trim()) {
        'cours' => SeanceType.cours,
        'td' => SeanceType.td,
        'tp' => SeanceType.tp,
        _ => SeanceType.autre,
      };
}

class Seance {
  final int weekday;

  final String slot;

  final SeanceType type;
  final String matiere;
  final String? enseignant;
  final String? salle;

  final bool rattrapage;

  const Seance({
    required this.weekday,
    required this.slot,
    required this.type,
    required this.matiere,
    this.enseignant,
    this.salle,
    this.rattrapage = false,
  });

  int get startMinutes {
    final match = RegExp(r'^(\d{1,2})[:h](\d{2})').firstMatch(slot.trim());
    if (match == null) return 24 * 60;
    return int.parse(match[1]!) * 60 + int.parse(match[2]!);
  }

  factory Seance.fromJson(Map<String, dynamic> json) => Seance(
        weekday: (json['weekday'] as num?)?.toInt() ?? 1,
        slot: json['slot'] as String? ?? '',
        type: SeanceType.parse(json['type'] as String?),
        matiere: json['matiere'] as String? ?? '',
        enseignant: json['enseignant'] as String?,
        salle: json['salle'] as String?,
        rattrapage: json['rattrapage'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'weekday': weekday,
        'slot': slot,
        'type': type.name,
        'matiere': matiere,
        'enseignant': enseignant,
        'salle': salle,
        'rattrapage': rattrapage,
      };
}
