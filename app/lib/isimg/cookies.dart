import 'dart:convert';

/// Minimal cookie jar for the one host we talk to.
///
/// The site sets plain host cookies on path `/`, so a name/value map is enough —
/// and it keeps the jar trivially serialisable into secure storage. Notably the
/// site rotates an anti-replay cookie on many responses, so every response's
/// Set-Cookie headers must be folded back in or the next request is rejected.
class Cookies {
  final Map<String, String> _values;

  Cookies([Map<String, String>? values]) : _values = {...?values};

  static Cookies empty() => Cookies();

  bool get isEmpty => _values.isEmpty;

  String? operator [](String name) => _values[name];

  void set(String name, String value) => _values[name] = value;

  /// Value of the site's "remember this device" cookie, if we hold one.
  String? get trustedDevice => _values['trusted_device'];

  /// Header to send with a request. Empty string when there is nothing to send.
  String get header =>
      _values.entries.map((e) => '${e.key}=${e.value}').join('; ');

  /// Folds `Set-Cookie` response headers into the jar.
  ///
  /// Only the name and value matter here; attributes such as Path, Secure and
  /// HttpOnly are irrelevant because this jar is scoped to a single host and is
  /// never exposed to a browser.
  void applySetCookies(Iterable<String> setCookieHeaders) {
    for (final raw in setCookieHeaders) {
      final firstPart = raw.split(';').first.trim();
      final separator = firstPart.indexOf('=');
      if (separator <= 0) continue;

      final name = firstPart.substring(0, separator).trim();
      final value = firstPart.substring(separator + 1).trim();
      if (name.isEmpty) continue;

      // An expiry in the past is the site clearing a cookie.
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
      // Unreadable storage must not block signing in again.
      return Cookies.empty();
    }
  }
}
