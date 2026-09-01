import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/stage.dart';

class CachedStages {
  final Stages stages;
  final DateTime capturedAt;

  const CachedStages({required this.stages, required this.capturedAt});
}

class StageCache {
  static const _key = 'stages_v1';

  Future<void> save(Stages stages) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        jsonEncode({
          'capturedAt': DateTime.now().toIso8601String(),
          'stages': stages.toJson(),
        }),
      );
    } catch (_) {
    }
  }

  Future<CachedStages?> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return null;

      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final capturedAt = DateTime.tryParse(decoded['capturedAt'] as String? ?? '');
      final stages = decoded['stages'];
      if (capturedAt == null || stages is! Map<String, dynamic>) return null;

      return CachedStages(stages: Stages.fromJson(stages), capturedAt: capturedAt);
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {
    }
  }
}
