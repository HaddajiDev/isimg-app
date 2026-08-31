import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/manual_note.dart';

const _storageKey = 'manual_notes_v1';

class ManualNotesNotifier extends AsyncNotifier<ManualNotes> {
  @override
  Future<ManualNotes> build() => _load();

  Future<ManualNotes> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null) return ManualNotes.empty;

      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return ManualNotes({
        for (final entry in decoded.entries)
          if (entry.value is num) entry.key: (entry.value as num).toDouble(),
      });
    } catch (_) {
      return ManualNotes.empty;
    }
  }

  Future<void> _persist(ManualNotes notes) async {
    state = AsyncData(notes);
    try {
      final prefs = await SharedPreferences.getInstance();
      if (notes.isEmpty) {
        await prefs.remove(_storageKey);
      } else {
        await prefs.setString(_storageKey, jsonEncode(notes.asMap));
      }
    } catch (_) {
    }
  }

  ManualNotes get _current => state.value ?? ManualNotes.empty;

  Future<void> setNote(ManualNoteKey key, double note) =>
      _persist(_current.set(key, note.clamp(0, 20)));

  Future<void> removeNote(ManualNoteKey key) => _persist(_current.remove(key));

  Future<void> clearFor({required String annee, required String session}) =>
      _persist(_current.clearFor(annee: annee, session: session));
}

final manualNotesProvider =
    AsyncNotifierProvider<ManualNotesNotifier, ManualNotes>(ManualNotesNotifier.new);
