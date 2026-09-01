String? _str(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

DateTime? _dt(dynamic v) {
  final s = v?.toString().trim() ?? '';
  if (s.isEmpty || s.startsWith('0000-00-00')) return null;
  return DateTime.tryParse(s);
}

final _tag = RegExp(r'<[^>]*>');
final _spaces = RegExp(r'[ \t]+');
final _blankLines = RegExp(r'\n{3,}');

String _plain(dynamic v) {
  var s = v?.toString() ?? '';
  if (s.isEmpty) return '';
  s = s
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n\n')
      .replaceAll(RegExp(r'</li>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<li[^>]*>', caseSensitive: false), '• ')
      .replaceAll(_tag, '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll(_spaces, ' ')
      .replaceAll(_blankLines, '\n\n');
  return s.trim();
}

class NewsItem {
  final String id;
  final String? auteur;
  final String titre;
  final String? description;
  final String body;
  final List<String> groupes;
  final DateTime? created;

  const NewsItem({
    required this.id,
    this.auteur,
    required this.titre,
    this.description,
    this.body = '',
    this.groupes = const [],
    this.created,
  });

  factory NewsItem.fromJson(Map<String, dynamic> j) => NewsItem(
        id: _str(j['id']) ?? '',
        auteur: _str(j['auteur']),
        titre: _str(j['titre']) ?? 'Actualité',
        description: _str(j['description']),
        body: _plain(j['sujet']),
        groupes: (_str(j['groups']) ?? '')
            .split(',')
            .map((g) => g.trim())
            .where((g) => g.isNotEmpty)
            .toList(),
        created: _dt(j['created']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'auteur': auteur,
        'titre': titre,
        'description': description,
        'sujet': body,
        'groups': groupes.join(','),
        'created': created?.toIso8601String(),
      };
}

class NewsFeed {
  final List<NewsItem> items;

  const NewsFeed({this.items = const []});

  bool get isEmpty => items.isEmpty;

  factory NewsFeed.fromJson(Map<String, dynamic> j) => NewsFeed(
        items: (j['items'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(NewsItem.fromJson)
            .toList(),
      );

  Map<String, dynamic> toJson() => {'items': items.map((e) => e.toJson()).toList()};
}
