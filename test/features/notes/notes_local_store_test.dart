import 'package:finals/features/notes/data/notes_local_store.dart';
import 'package:finals/features/notes/domain/note.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

Note makeNote(String id, {String content = 'text', bool locked = false}) {
  return Note(
    id: id,
    ownerId: 'user-1',
    title: 'Note $id',
    content: content,
    isPinned: false,
    pinnedAt: null,
    isLocked: locked,
    version: 1,
    createdAt: DateTime.utc(2026, 11, 1),
    updatedAt: DateTime.utc(2026, 11, 2),
  );
}

var _dbCount = 0;

Future<NotesLocalStore> openTestStore() async {
  final db = await databaseFactoryMemory.openDatabase('test_${_dbCount++}.db');
  addTearDown(db.close);
  return NotesLocalStore(db);
}

void main() {
  test('replaceAll keeps exactly the latest server notes', () async {
    final store = await openTestStore();
    await store.replaceAll([makeNote('old')]);
    await store.replaceAll([makeNote('a'), makeNote('b')]);

    final ids = (await store.getAll()).map((n) => n.id).toSet();
    expect(ids, {'a', 'b'});
  });

  test('locked note content is never written to the device', () async {
    final store = await openTestStore();
    await store.upsert(makeNote('secret', content: 'bank pin', locked: true));

    final saved = await store.get('secret');
    expect(saved!.isLocked, isTrue);
    expect(saved.content, isEmpty);
  });

  test('upsert updates one note and delete removes it', () async {
    final store = await openTestStore();
    await store.upsert(makeNote('a', content: 'first'));
    await store.upsert(makeNote('a', content: 'second'));
    expect((await store.get('a'))!.content, 'second');

    await store.delete('a');
    expect(await store.get('a'), isNull);
  });
}