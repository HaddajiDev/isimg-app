import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:isimg_app/models/manual_note.dart';
import 'package:isimg_app/providers/manual_notes_provider.dart';

const _storageKey = 'manual_notes_v1';

ManualNoteKey key(String matiere, int index) => ManualNoteKey(
      annee: '13',
      session: '1',
      semestre: '1',
      unite: 'Uef410',
      matiere: matiere,
      epreuveIndex: index,
    );

/// Reads what actually landed in device storage.
Future<Map<String, dynamic>> storedJson() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_storageKey);
  return raw == null ? {} : jsonDecode(raw) as Map<String, dynamic>;
}

Future<ManualNotes> loadFresh() async {
  // A new container stands in for a cold app start.
  final container = ProviderContainer();
  addTearDown(container.dispose);
  return container.read(manualNotesProvider.future);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('a saved note is written to device storage', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(manualNotesProvider.future);

    await container.read(manualNotesProvider.notifier).setNote(key('Qualité', 1), 14.5);

    expect(await storedJson(), {'13§1§1§Uef410§Qualité§1': 14.5});
  });

  test('notes survive an app restart', () async {
    final first = ProviderContainer();
    addTearDown(first.dispose);
    await first.read(manualNotesProvider.future);
    await first.read(manualNotesProvider.notifier).setNote(key('Qualité', 1), 14.5);
    await first.read(manualNotesProvider.notifier).setNote(key('Anglais 3', 0), 8);

    // Cold start: nothing carried over in memory, only what was persisted.
    final restored = await loadFresh();
    expect(restored.length, 2);
    expect(restored.noteFor(key('Qualité', 1)), 14.5);
    expect(restored.noteFor(key('Anglais 3', 0)), 8);
  });

  test('a deleted note does not come back after a restart', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(manualNotesProvider.future);

    final notifier = container.read(manualNotesProvider.notifier);
    await notifier.setNote(key('Qualité', 1), 14.5);
    await notifier.removeNote(key('Qualité', 1));

    expect(await storedJson(), isEmpty);
    expect((await loadFresh()).isEmpty, isTrue);
  });

  test('clearing one année leaves the others on disk', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(manualNotesProvider.future);

    final notifier = container.read(manualNotesProvider.notifier);
    await notifier.setNote(key('Qualité', 1), 14.5);
    await notifier.setNote(
      const ManualNoteKey(
        annee: '12',
        session: '1',
        semestre: '1',
        unite: 'U',
        matiere: 'M',
        epreuveIndex: 0,
      ),
      11,
    );

    await notifier.clearFor(annee: '13', session: '1');

    final restored = await loadFresh();
    expect(restored.length, 1);
    expect(restored.countFor(annee: '12', session: '1'), 1);
  });

  test('notes are clamped to the 0-20 range before being stored', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(manualNotesProvider.future);

    final notifier = container.read(manualNotesProvider.notifier);
    await notifier.setNote(key('A', 0), 25);
    await notifier.setNote(key('B', 0), -3);

    final restored = await loadFresh();
    expect(restored.noteFor(key('A', 0)), 20);
    expect(restored.noteFor(key('B', 0)), 0);
  });

  test('corrupt storage degrades to empty instead of breaking the screen', () async {
    SharedPreferences.setMockInitialValues({_storageKey: 'not json at all'});
    expect((await loadFresh()).isEmpty, isTrue);
  });

  test('non-numeric stored values are discarded', () async {
    SharedPreferences.setMockInitialValues({
      _storageKey: jsonEncode({
        '13§1§1§Uef410§Qualité§1': 14.5,
        '13§1§1§Uef410§Bogus§0': 'oops',
      }),
    });

    final restored = await loadFresh();
    expect(restored.length, 1);
    expect(restored.noteFor(key('Qualité', 1)), 14.5);
  });
}
