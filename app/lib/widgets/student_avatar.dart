import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';

/// Avatar generated from the student's name via DiceBear.
///
/// The same name always yields the same critter, so a student's avatar is
/// stable across sessions without us storing anything about them.
///
/// The image is fetched here rather than with `SvgPicture.network` for two
/// reasons: that loader hands the response body to the SVG parser without
/// checking the status code, so any error page surfaces as a baffling "invalid
/// SVG" instead of a network problem; and it offers nowhere to cache. Once a
/// critter has been fetched it is kept on the device, so a flaky or blocked
/// connection still shows the right face.
///
/// Note the SVG carries CSS `@keyframes`, which flutter_svg does not run — the
/// critter renders as a still image.
class StudentAvatar extends StatefulWidget {
  /// Name used as the generator seed. Falls back to initials when empty.
  final String seed;
  final double size;

  /// Shown while loading and if the avatar cannot be fetched.
  final String initials;

  const StudentAvatar({
    super.key,
    required this.seed,
    required this.size,
    this.initials = '',
  });

  /// Test-only: skips the network fetch and renders the initials fallback.
  @visibleForTesting
  static bool debugDisableRemote = false;

  /// Word order differs between pages — the cursus page gives "Ahmed Haddaji"
  /// while the relevé gives "Haddaji Ahmed". Sorting the lowercased words makes
  /// both produce the same seed, so a student keeps one avatar everywhere.
  static String canonicalSeed(String name) {
    final words = name.toLowerCase().trim().split(RegExp(r'\s+'))
      ..removeWhere((w) => w.isEmpty)
      ..sort();
    return words.join(' ');
  }

  /// Only the seed is sent. The animation parameters were dropped: flutter_svg
  /// cannot play CSS animations anyway, and some encodings of them made the API
  /// reject the request outright.
  static Uri avatarUri(String seed) => Uri.https(
        'api.dicebear.com',
        '/10.x/critters/svg',
        {'seed': canonicalSeed(seed)},
      );

  @override
  State<StudentAvatar> createState() => _StudentAvatarState();
}

class _StudentAvatarState extends State<StudentAvatar> {
  static const _cachePrefix = 'avatar_svg_v1:';
  static final Map<String, String> _memoryCache = {};

  String? _svg;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(StudentAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.seed != widget.seed) _resolve();
  }

  String get _cacheKey => '$_cachePrefix${StudentAvatar.canonicalSeed(widget.seed)}';

  Future<void> _resolve() async {
    if (widget.seed.trim().isEmpty || StudentAvatar.debugDisableRemote) return;

    final cached = _memoryCache[_cacheKey] ?? await _readDisk();
    if (cached != null) {
      _memoryCache[_cacheKey] = cached;
      if (mounted) setState(() => _svg = cached);
      return;
    }

    final fetched = await _fetch();
    if (fetched == null) return;

    _memoryCache[_cacheKey] = fetched;
    await _writeDisk(fetched);
    if (mounted) setState(() => _svg = fetched);
  }

  Future<String?> _readDisk() async {
    try {
      return (await SharedPreferences.getInstance()).getString(_cacheKey);
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeDisk(String svg) async {
    try {
      await (await SharedPreferences.getInstance()).setString(_cacheKey, svg);
    } catch (_) {
      // Cache is a nicety; the avatar still works without it.
    }
  }

  Future<String?> _fetch() async {
    final uri = StudentAvatar.avatarUri(widget.seed);
    try {
      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: 10));

      // Checking this is the whole point: an error body is not an SVG, and
      // feeding it to the parser only produces a misleading failure.
      if (response.statusCode != 200) {
        debugPrint('avatar: ${response.statusCode} from $uri');
        return null;
      }

      final body = utf8.decode(response.bodyBytes, allowMalformed: true);
      if (!body.contains('<svg')) {
        debugPrint('avatar: response was not an SVG');
        return null;
      }
      return body;
    } catch (error) {
      // Offline, blocked, DNS failure, timeout: keep the initials.
      debugPrint('avatar: fetch failed for $uri — $error');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final svg = _svg;

    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.purple, AppColors.purpleDeep]),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.purple.withValues(alpha: 0.30),
            blurRadius: size * 0.32,
            spreadRadius: -4,
          ),
        ],
      ),
      child: svg == null
          ? _InitialsAvatar(initials: widget.initials, size: size)
          : ClipOval(
              child: SvgPicture.string(
                svg,
                height: size,
                width: size,
                fit: BoxFit.cover,
                // Decorative: the name is always shown next to it.
                excludeFromSemantics: true,
                placeholderBuilder: (_) =>
                    _InitialsAvatar(initials: widget.initials, size: size),
              ),
            ),
    );
  }
}

class _InitialsAvatar extends StatelessWidget {
  final String initials;
  final double size;

  const _InitialsAvatar({required this.initials, required this.size});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: initials.isEmpty
          ? Icon(Icons.person_rounded, size: size * 0.5, color: Colors.white)
          : Text(
              initials,
              style: TextStyle(
                fontSize: size * 0.36,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
    );
  }
}
