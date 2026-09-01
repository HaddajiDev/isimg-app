import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';

class StudentAvatar extends StatefulWidget {
  final String seed;
  final double size;

  final String initials;

  const StudentAvatar({
    super.key,
    required this.seed,
    required this.size,
    this.initials = '',
  });

  @visibleForTesting
  static bool debugDisableRemote = false;

  static String canonicalSeed(String name) {
    final words = name.toLowerCase().trim().split(RegExp(r'\s+'))
      ..removeWhere((w) => w.isEmpty)
      ..sort();
    return words.join(' ');
  }

  static Uri avatarUri(String seed) => Uri.https(
        'api.dicebear.com',
        '/10.x/critters/png',
        {'seed': canonicalSeed(seed), 'size': '160'},
      );

  @override
  State<StudentAvatar> createState() => _StudentAvatarState();
}

class _StudentAvatarState extends State<StudentAvatar> {
  static const _cachePrefix = 'avatar_png_v2:';
  static final Map<String, Uint8List> _memoryCache = {};

  Uint8List? _png;

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

  static String _keyFor(String seed) =>
      '$_cachePrefix${StudentAvatar.canonicalSeed(seed)}';

  // The seed can change mid-flight (e.g. a drawer header that starts on a
  // placeholder name, then rebuilds once the real one loads). Snapshot it so a
  // stale fetch never writes its bytes under the new seed's cache key, and only
  // apply the result while this widget still wants that seed.
  Future<void> _resolve() async {
    final seed = widget.seed;
    if (seed.trim().isEmpty || StudentAvatar.debugDisableRemote) return;
    final key = _keyFor(seed);

    final cached = _memoryCache[key] ?? await _readDisk(key);
    if (cached != null) {
      _memoryCache[key] = cached;
      if (mounted && widget.seed == seed) setState(() => _png = cached);
      return;
    }

    final fetched = await _fetch(seed);
    if (fetched == null) return;

    _memoryCache[key] = fetched;
    await _writeDisk(key, fetched);
    if (mounted && widget.seed == seed) setState(() => _png = fetched);
  }

  Future<Uint8List?> _readDisk(String key) async {
    try {
      final encoded = (await SharedPreferences.getInstance()).getString(key);
      return encoded == null ? null : base64Decode(encoded);
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeDisk(String key, Uint8List png) async {
    try {
      await (await SharedPreferences.getInstance())
          .setString(key, base64Encode(png));
    } catch (_) {
    }
  }

  Future<Uint8List?> _fetch(String seed) async {
    final uri = StudentAvatar.avatarUri(seed);
    try {
      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        debugPrint('avatar: ${response.statusCode} from $uri');
        return null;
      }

      final bytes = response.bodyBytes;
      if (bytes.length < 8 ||
          bytes[0] != 0x89 ||
          bytes[1] != 0x50 ||
          bytes[2] != 0x4E ||
          bytes[3] != 0x47) {
        debugPrint('avatar: response was not a PNG');
        return null;
      }
      return bytes;
    } catch (error) {
      debugPrint('avatar: fetch failed for $uri — $error');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final png = _png;

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
      child: png == null
          ? _InitialsAvatar(initials: widget.initials, size: size)
          : ClipOval(
              child: Image.memory(
                png,
                height: size,
                width: size,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                excludeFromSemantics: true,
                errorBuilder: (context, error, stack) =>
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
