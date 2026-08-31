import 'dart:convert';

class Cookies {
  final Map<String, String> _values;

  Cookies([Map<String, String>? values]) : _values = {...?values};

  static Cookies empty() => Cookies();

  bool get isEmpty => _values.isEmpty;

  String? operator [](String name) => _values[name];

  void set(String name, String value) => _values[name] = value;

  String? get trustedDevice => _values['trusted_device'];

  String get header =>
      _values.entries.map((e) => '${e.key}=${e.value}').join('; ');

  void applySetCookies(Iterable<String> setCookieHeaders) {
    for (final raw in setCookieHeaders) {
      final firstPart = raw.split(';').first.trim();
      final separator = firstPart.indexOf('=');
      if (separator <= 0) continue;

      final name = firstPart.substring(0, separator).trim();
      final value = firstPart.substring(separator + 1).trim();
      if (name.isEmpty) continue;

      if (value.isEmpty || _isExpired(raw)) {
        _values.remove(name);
        continue;
      }
      _values[name] = value;
    }
  }

  static bool _isExpired(String raw) {
    final maxAge = RegExp(r'max-age\s*=\s*(-?\d+)', caseSensitive: false).firstMatch(raw);
    if (maxAge != null) return (int.tryParse(maxAge[1]!) ?? 1) <= 0;
    return false;
  }

  Map<String, String> toMap() => Map.unmodifiable(_values);

  String encode() => base64Encode(utf8.encode(jsonEncode(_values)));

  static Cookies decode(String? encoded) {
    if (encoded == null || encoded.isEmpty) return Cookies.empty();
    try {
      final decoded = jsonDecode(utf8.decode(base64Decode(encoded)));
      if (decoded is! Map) return Cookies.empty();
      return Cookies({
        for (final entry in decoded.entries)
          if (entry.value is String) '${entry.key}': entry.value as String,
      });
    } catch (_) {
      return Cookies.empty();
    }
  }
}
