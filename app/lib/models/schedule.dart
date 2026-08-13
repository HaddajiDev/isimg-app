import 'seance.dart';

class Schedule {
  final String? weekLabel;

  /// False only when the site printed its "nothing scheduled" placeholder for
  /// this week. Distinct from an empty [sessions] — that also happens when the
  /// grid was there but could not be read, which the screen reports as a
  /// failure rather than as a free week.
  final bool hasSessions;

  /// The classes read off the timetable, in the site's own order.
  final List<Seance> sessions;

  Schedule({
    this.weekLabel,
    required this.hasSessions,
    this.sessions = const [],
  });

  factory Schedule.fromJson(Map<String, dynamic> json) {
    return Schedule(
      weekLabel: json['weekLabel'] as String?,
      hasSessions: json['hasSessions'] as bool? ?? false,
      sessions: (json['sessions'] as List<dynamic>? ?? [])
          .map((s) => Seance.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Round-trips through the offline cache.
  Map<String, dynamic> toJson() => {
        'weekLabel': weekLabel,
        'hasSessions': hasSessions,
        'sessions': sessions.map((s) => s.toJson()).toList(),
      };
}
