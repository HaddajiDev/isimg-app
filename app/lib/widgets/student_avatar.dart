import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/app_theme.dart';

/// Avatar generated from the student's name via DiceBear.
///
/// The same name always yields the same critter, so a student's avatar is
/// stable across sessions without us storing anything.
///
/// Note: the API's SVG carries CSS `@keyframes`, which flutter_svg does not
/// run — the critter renders as a static image.
class StudentAvatar extends StatelessWidget {
  /// Name used as the generator seed. Falls back to initials when empty.
  final String seed;
  final double size;

  /// Shown while loading and if the request fails (offline, API down).
  final String initials;

  const StudentAvatar({
    super.key,
    required this.seed,
    required this.size,
    this.initials = '',
  });

  /// Test-only: skips the network fetch and renders the initials fallback.
  /// Widget tests answer every request with an empty 400, which the SVG parser
  /// rejects asynchronously and reports as an unrelated test failure.
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

  static Uri avatarUri(String seed) {
    return Uri.https('api.dicebear.com', '/10.x/critters/svg', {
      'animationVariant': 'fast:1,fastest:1,medium:1,none:1,slow:1,slowest:1',
      'tags': 'animation',
      'seed': canonicalSeed(seed),
    });
  }

  @override
  Widget build(BuildContext context) {
    final fallback = _InitialsAvatar(initials: initials, size: size);

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
      child: seed.trim().isEmpty || debugDisableRemote
          ? fallback
          : ClipOval(
              child: SvgPicture.network(
                avatarUri(seed).toString(),
                height: size,
                width: size,
                fit: BoxFit.cover,
                placeholderBuilder: (_) => fallback,
                // Decorative: the name is always shown next to it.
                excludeFromSemantics: true,
                errorBuilder: (_, _, _) => fallback,
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
