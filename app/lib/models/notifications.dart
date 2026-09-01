String? _str(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

int _int(dynamic v) {
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString().trim() ?? '') ?? 0;
}

enum NotifKind {
  news,
  absence,
  demande,
  exam,
  notes,
  autre;

  static NotifKind fromCode(dynamic code) {
    switch (_int(code)) {
      case 1:
        return NotifKind.news;
      case 2:
        return NotifKind.absence;
      case 3:
        return NotifKind.demande;
      case 4:
        return NotifKind.exam;
      case 5:
        return NotifKind.notes;
      default:
        return NotifKind.autre;
    }
  }

  String get label => switch (this) {
        NotifKind.news => 'Actualités',
        NotifKind.absence => 'Absences',
        NotifKind.demande => 'Demandes',
        NotifKind.exam => 'Examens',
        NotifKind.notes => 'Notes',
        NotifKind.autre => 'Autre',
      };
}

class NotifItem {
  final String title;
  final String message;
  final int pageId;
  final String? extraInfos;

  const NotifItem({
    required this.title,
    required this.message,
    this.pageId = -1,
    this.extraInfos,
  });

  NotifKind get kind => switch (pageId) {
        1 => NotifKind.news,
        6 => NotifKind.exam,
        _ => NotifKind.autre,
      };

  factory NotifItem.fromJson(Map<String, dynamic> j) => NotifItem(
        title: _str(j['title']) ?? '',
        message: _str(j['message']) ?? '',
        pageId: _int(j['pageid']),
        extraInfos: _str(j['extrainfos']),
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        'message': message,
        'pageid': pageId,
        'extrainfos': extraInfos,
      };
}

class NotifCount {
  final NotifKind kind;
  final int count;

  const NotifCount({required this.kind, required this.count});

  factory NotifCount.fromJson(Map<String, dynamic> j) => NotifCount(
        kind: NotifKind.fromCode(j['type']),
        count: _int(j['nbre']),
      );

  Map<String, dynamic> toJson() => {
        'type': switch (kind) {
          NotifKind.news => 1,
          NotifKind.absence => 2,
          NotifKind.demande => 3,
          NotifKind.exam => 4,
          NotifKind.notes => 5,
          NotifKind.autre => 0,
        },
        'nbre': count,
      };
}

class NotifData {
  final List<NotifItem> items;
  final List<NotifCount> counts;

  const NotifData({this.items = const [], this.counts = const []});

  bool get isEmpty => items.isEmpty;

  int get total => counts.fold(0, (sum, c) => sum + c.count);

  factory NotifData.fromJson(Map<String, dynamic> j) => NotifData(
        items: (j['notifs'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(NotifItem.fromJson)
            .toList(),
        counts: (j['nbres'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(NotifCount.fromJson)
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'notifs': items.map((e) => e.toJson()).toList(),
        'nbres': counts.map((e) => e.toJson()).toList(),
      };
}
