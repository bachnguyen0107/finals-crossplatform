import 'package:finals/features/notes/application/notes_providers.dart';
import 'package:finals/features/notes/data/notes_local_store.dart';
import 'package:finals/features/notes/data/notes_repository.dart';
import 'package:finals/features/notes/domain/note.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

var _dbCounter = 0;

Future<NotesLocalStore> openTestStore() async {
  final db = await databaseFactoryMemory.openDatabase(
    'sync_test_${_dbCounter++}.db',
  );
  addTearDown(db.close);
  return NotesLocalStore(db);
}

Note makeNote(
  String id, {
  String title = 'Title',
  String content = 'Body',
  int version = 1,
  bool isLocked = false,
}) {
  final time = DateTime.utc(2026, 11, 1);
  return Note(
    id: id,
    ownerId: 'user-1',
    title: title,
    content: content,
    isPinned: false,
    pinnedAt: null,
    isLocked: isLocked,
    version: version,
    createdAt: time,
    updatedAt: time,
  );
}

class FakeSyncRepository extends Fake implements NotesRepository {
  FakeSyncRepository({this.online = true});

  bool online;
  final serverNotes = <String, Note>{};
  final created = <Note>[];

  void _checkOnline() {
    if (!online) {
      throw const NotesFailure('Unable to reach the server.', isNetwork: true);
    }
  }

  @override
  Future<List<Note>> fetchNotes() async {
    _checkOnline();
    return sortNotes(serverNotes.values);
  }

  @override
  Future<Note> updateNote(String id, {String? title, String? content}) async {
    _checkOnline();
    throw UnimplementedError();
  }

  @override
  Future<Note?> updateNoteIfVersion(
    String id, {
    required String title,
    required String content,
    required int baseVersion,
  }) async {
    _checkOnline();
    final current = serverNotes[id];
    if (current == null || current.version != baseVersion) return null;
    final saved = makeNote(
      id,
      title: title,
      content: content,
      version: current.version + 1,
    );
    serverNotes[id] = saved;
    return saved;
  }

  @override
  Future<Note> createNote({
    String? id,
    required String title,
    String content = '',
  }) async {
    _checkOnline();
    final note = makeNote(
      id ?? 'server-${created.length}',
      title: title,
      content: content,
    );
    created.add(note);
    serverNotes[note.id] = note;
    return note;
  }
}

ProviderContainer makeContainer(
  FakeSyncRepository repository,
  NotesLocalStore store,
) {
  final container = ProviderContainer(
    overrides: [
      notesUserIdProvider.overrideWithValue('user-1'),
      notesRepositoryProvider.overrideWithValue(repository),
      notesLocalStoreProvider.overrideWith((ref) async => store),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('offline edit is kept on the device and queued', () async {
    final store = await openTestStore();
    await store.replaceAll([makeNote('n1', version: 3)]);
    final container = makeContainer(FakeSyncRepository(online: false), store);
    await container.read(notesControllerProvider.future);

    await container
        .read(notesControllerProvider.notifier)
        .saveNote('n1', title: 'New', content: 'Offline edit');

    final pending = await store.pendingChanges();
    expect(pending.single.kind, PendingKind.update);
    expect(pending.single.baseVersion, 3);
    expect((await store.get('n1'))!.content, 'Offline edit');
    expect(container.read(notesPendingCountProvider), 1);
  });

  test('queued edit is sent when back online', () async {
    final store = await openTestStore();
    await store.replaceAll([makeNote('n1', version: 3)]);
    await store.queueUpdate(
      makeNote('n1', title: 'New', content: 'Offline edit', version: 3),
    );
    final repository = FakeSyncRepository()
      ..serverNotes['n1'] = makeNote('n1', version: 3);
    final container = makeContainer(repository, store);

    final notes = await container.read(notesControllerProvider.future);

    expect(notes.single.content, 'Offline edit');
    expect(await store.pendingChanges(), isEmpty);
    expect(repository.created, isEmpty);
  });

  test('conflict: server version is kept and ours becomes a copy', () async {
    final store = await openTestStore();
    await store.replaceAll([makeNote('n1', version: 3)]);
    await store.queueUpdate(
      makeNote('n1', title: 'New', content: 'Offline edit', version: 3),
    );
    final repository = FakeSyncRepository()
      ..serverNotes['n1'] = makeNote('n1', content: 'Edited elsewhere', version: 4);
    final container = makeContainer(repository, store);

    final notes = await container.read(notesControllerProvider.future);

    expect(notes, hasLength(2));
    expect(repository.serverNotes['n1']!.content, 'Edited elsewhere');
    expect(repository.created.single.title, 'New (conflict copy)');
    expect(container.read(notesConflictCopiesProvider), 1);
  });

  test('note created offline is sent with the same id', () async {
    final store = await openTestStore();
    await store.replaceAll([makeNote('n1')]);
    final repository = FakeSyncRepository(online: false);
    final container = makeContainer(repository, store);
    await container.read(notesControllerProvider.future);

    final note = await container
        .read(notesControllerProvider.notifier)
        .create(title: 'Made offline');
    repository.online = true;
    container.invalidate(notesControllerProvider);
    await container.read(notesControllerProvider.future);

    expect(repository.created.single.id, note.id);
    expect(await store.pendingChanges(), isEmpty);
  });

  test('locked notes cannot be edited offline', () async {
    final store = await openTestStore();
    await store.replaceAll([makeNote('n1', isLocked: true)]);
    final container = makeContainer(FakeSyncRepository(online: false), store);
    await container.read(notesControllerProvider.future);

    expect(
      container
          .read(notesControllerProvider.notifier)
          .saveNote('n1', title: 'x', content: 'y'),
      throwsA(isA<NotesFailure>()),
    );
  });
}