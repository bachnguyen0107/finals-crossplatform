import 'package:sembast/sembast.dart';

import '../domain/note.dart';

// Copy of the user's notes stored on this device.
class NotesLocalStore {
  NotesLocalStore(this._db);

  final Database _db;
  final _store = stringMapStoreFactory.store('notes');

  Future<List<Note>> getAll() async {
    final records = await _store.find(_db);
    return records
        .map((record) => Note.fromMap(Map<String, dynamic>.from(record.value)))
        .toList();
  }

  Future<Note?> get(String id) async {
    final value = await _store.record(id).get(_db);
    return value == null ? null : Note.fromMap(Map<String, dynamic>.from(value));
  }

  // Replaces the whole copy with the latest list from the server.
  Future<void> replaceAll(List<Note> notes) {
    return _db.transaction((txn) async {
      await _store.delete(txn);
      for (final note in notes) {
        await _store.record(note.id).put(txn, note.toMap());
      }
    });
  }

  Future<void> upsert(Note note) {
    return _store.record(note.id).put(_db, note.toMap());
  }

  Future<void> delete(String id) {
    return _store.record(id).delete(_db);
  }
}