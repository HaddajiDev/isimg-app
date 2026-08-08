/// A single class on the timetable.
///
/// The site renders these as coloured cells in a day × time-slot grid. Only the
/// demo account produces them so far: the real parser is still pending a
/// captured week that actually has classes in it.
enum SeanceType {
  cours,
  td,
  tp,
  autre;

  /// Prefix the school writes in the cell, e.g. "TD Analyse 1".
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
  /// 1 = Monday … 6 = Saturday, matching [DateTime.weekday].
  final int weekday;

  /// Slot as printed in the leftmost column, e.g. "08:15-09:45".
  final String slot;

  final SeanceType type;
  final String matiere;
  final String? enseignant;
  final String? salle;

  const Seance({
    required this.weekday,
    required this.slot,
    required this.type,
    required this.matiere,
    this.enseignant,
    this.salle,
  });

  /// Minutes since midnight, used to order the slot rows. Falls back to a large
  /// value so an unparseable slot sinks to the bottom rather than reordering
  /// everything above it.
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
      );

  Map<String, dynamic> toJson() => {
        'weekday': weekday,
        'slot': slot,
        'type': type.name,
        'matiere': matiere,
        'enseignant': enseignant,
        'salle': salle,
      };
}
