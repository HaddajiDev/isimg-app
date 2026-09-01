DateTime? _date(dynamic v) {
  final s = v?.toString().trim() ?? '';
  if (s.isEmpty || s == '0000-00-00' || s == '0000-00-00 00:00:00') return null;
  return DateTime.tryParse(s);
}

int _int(dynamic v) {
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString().trim() ?? '') ?? 0;
}

String? _str(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

class CalendarEvent {
  final int? id;
  final String name;
  final int semestre;
  final String? concerned;
  final DateTime? start;
  final DateTime? end;
  final int ordre;

  const CalendarEvent({
    this.id,
    required this.name,
    this.semestre = 0,
    this.concerned,
    this.start,
    this.end,
    this.ordre = 0,
  });

  bool get isRange {
    final s = start, e = end;
    if (s == null || e == null) return false;
    return s.year != e.year || s.month != e.month || s.day != e.day;
  }

  DateTime get sortKey => start ?? DateTime(9999);

  bool isPast(DateTime now) {
    final e = end ?? start;
    if (e == null) return false;
    return DateTime(e.year, e.month, e.day).isBefore(DateTime(now.year, now.month, now.day));
  }

  bool isOngoing(DateTime now) {
    final s = start, e = end ?? start;
    if (s == null || e == null) return false;
    final t = DateTime(now.year, now.month, now.day);
    return !t.isBefore(DateTime(s.year, s.month, s.day)) &&
        !t.isAfter(DateTime(e.year, e.month, e.day));
  }

  factory CalendarEvent.fromJson(Map<String, dynamic> j) => CalendarEvent(
        id: _int(j['id']),
        name: _str(j['champ']) ?? '',
        semestre: _int(j['semestre']),
        concerned: _str(j['classetype']),
        start: _date(j['debut']),
        end: _date(j['fin']),
        ordre: _int(j['ordre']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'champ': name,
        'semestre': semestre,
        'classetype': concerned,
        'debut': start?.toIso8601String(),
        'fin': end?.toIso8601String(),
        'ordre': ordre,
      };
}

class UniversityCalendar {
  final List<CalendarEvent> events;

  const UniversityCalendar({this.events = const []});

  bool get hasEvents => events.isNotEmpty;

  List<CalendarEvent> forSemestre(int s) =>
      events.where((e) => e.semestre == s).toList();

  factory UniversityCalendar.fromJson(Map<String, dynamic> j) => UniversityCalendar(
        events: (j['events'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(CalendarEvent.fromJson)
            .toList(),
      );

  Map<String, dynamic> toJson() => {'events': events.map((e) => e.toJson()).toList()};
}
