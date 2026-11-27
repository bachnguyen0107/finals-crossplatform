import 'package:finals/features/notes/application/notes_providers.dart';
import 'package:finals/features/notes/data/notes_local_store.dart';
import 'package:finals/features/notes/data/notes_repository.dart';
import 'package:finals/features/notes/domain/note.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'notes_local_store_test.dart' show makeNote, openTestStore;

class OfflineNotesRepository extends Fake implements NotesRepository {
  @override
  Future<List<Note>> fetchNotes() async =>
      throw const NotesFailure('Unable to reach the server.');
}

class OnlineNotesRepository extends Fake implements NotesRepository {
  OnlineNotesRepository(this.notes);

  final List<Note> notes;

  @override
  Future<List<Note>> fetchNotes() async => notes;
}

ProviderContainer makeContainer(NotesRepository repo, NotesLocalStore store) {
  final container = ProviderContainer(
    overrides: [
      notesUserIdProvider.overrideWithValue('user-1'),
      notesRepositoryProvider.overrideWithValue(repo),
      notesLocalStoreProvider.overrideWith((ref) async => store),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('offline: shows the notes saved on this device', () async {
    final store = await openTestStore();
    await store.replaceAll([makeNote('a')]);
    final container = makeContainer(OfflineNotesRepository(), store);

    final notes = await container.read(notesControllerProvider.future);

    expect(notes.map((n) => n.id), ['a']);
    expect(container.read(notesOfflineProvider), isTrue);
  });

  test('online: the device copy is replaced with the server list', () async {
    final store = await openTestStore();
    await store.replaceAll([makeNote('old')]);
    final container =
        makeContainer(OnlineNotesRepository([makeNote('new')]), store);

    await container.read(notesControllerProvider.future);

    expect((await store.getAll()).map((n) => n.id), ['new']);
    expect(container.read(notesOfflineProvider), isFalse);
  });

  test('offline with nothing saved: shows the error', () async {
    final store = await openTestStore();
    final container = makeContainer(OfflineNotesRepository(), store);

    await expectLater(
      container.read(notesControllerProvider.future),
      throwsA(isA<NotesFailure>()),
    );
  });
}