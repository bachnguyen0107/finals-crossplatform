import 'package:finals/features/auth/application/auth_providers.dart';
import 'package:finals/features/notes/application/notes_providers.dart';
import 'package:finals/features/notes/data/notes_repository.dart';
import 'package:finals/features/notes/domain/note.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-memory repository so the controller can be tested without Supabase.
class FakeNotesRepository extends Fake implements NotesRepository {
  final _notes = <String, Note>{};
  var _nextId = 0;
  var _clock = DateTime.utc(2026, 11, 1);

  DateTime _tick() => _clock = _clock.add(const Duration(minutes: 1));

  @override
  Future<List<Note>> fetchNotes() async => sortNotes(_notes.values);

  @override
  Future<Note> createNote({required String title, String content = ''}) async {
    final now = _tick();
    final note = Note(
      id: 'n${_nextId++}',
      ownerId: 'user-1',
      title: title,
      content: content,
      isPinned: false,
      pinnedAt: null,
      isLocked: false,
      version: 1,
      createdAt: now,
      updatedAt: now,
    );
    _notes[note.id] = note;
    return note;
  }

  @override
  Future<Note> setPinned(String id, {required bool pinned}) async {
    final old = _notes[id]!;
    final note = Note(
      id: old.id,
      ownerId: old.ownerId,
      title: old.title,
      content: old.content,
      isPinned: pinned,
      pinnedAt: pinned ? _tick() : null,
      isLocked: old.isLocked,
      version: old.version + 1,
      createdAt: old.createdAt,
      updatedAt: old.updatedAt,
    );
    _notes[id] = note;
    return note;
  }
}

Future<NotesController> makeController() async {
  final container = ProviderContainer(
    overrides: [
      currentUserProvider.overrideWithValue(null),
      notesRepositoryProvider.overrideWithValue(FakeNotesRepository()),
    ],
  );
  addTearDown(container.dispose);
  await container.read(notesControllerProvider.future);
  return container.read(notesControllerProvider.notifier);
}

List<String> titles(NotesController controller) =>
    controller.state.value!.map((n) => n.title).toList();

void main() {
  test('pinning an older note moves it above newer notes', () async {
    final controller = await makeController();
    final older = await controller.create(title: 'Older');
    await controller.create(title: 'Newer');
    expect(titles(controller), ['Newer', 'Older']);

    await controller.setPinned(older.id, pinned: true);

    expect(titles(controller), ['Older', 'Newer']);
  });

  test('unpinning puts the note back in last-modified order', () async {
    final controller = await makeController();
    final older = await controller.create(title: 'Older');
    await controller.create(title: 'Newer');

    await controller.setPinned(older.id, pinned: true);
    await controller.setPinned(older.id, pinned: false);

    expect(titles(controller), ['Newer', 'Older']);
  });

  test('the most recently pinned note comes first', () async {
    final controller = await makeController();
    final a = await controller.create(title: 'A');
    final b = await controller.create(title: 'B');

    await controller.setPinned(b.id, pinned: true);
    await controller.setPinned(a.id, pinned: true);

    expect(titles(controller), ['A', 'B']);
  });
}