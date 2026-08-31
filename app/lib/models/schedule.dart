import 'seance.dart';

class Schedule {
  final String? weekLabel;

  final bool hasSessions;

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

  Map<String, dynamic> toJson() => {
        'weekLabel': weekLabel,
        'hasSessions': hasSessions,
        'sessions': sessions.map((s) => s.toJson()).toList(),
      };
}
