import 'package:sembast/sembast.dart';

import '../domain/note.dart';

enum PendingKind { create, update, delete }

// A change made without a connection, waiting to be sent to the server.
class PendingChange {
  const PendingChange({
    required this.noteId,
    required this.kind,
    required this.queuedAt,
    this.title = '',
    this.content = '',
    this.baseVersion = 0,
  });

  factory PendingChange.fromMap(String noteId, Map<String, Object?> map) {
    return PendingChange(
      noteId: noteId,
      kind: PendingKind.values.byName(map['kind']! as String),
      queuedAt: DateTime.parse(map['queued_at']! as String),
      title: map['title'] as String? ?? '',
      content: map['content'] as String? ?? '',
      baseVersion: (map['base_version'] as num?)?.toInt() ?? 0,
    );
  }

  final String noteId;
  final PendingKind kind;
  final DateTime queuedAt;
  final String title;
  final String content;

  // Server version the offline edits started from, used to spot conflicts.
  final int baseVersion;

  Map<String, Object?> toMap() => {
    'kind': kind.name,
    'queued_at': queuedAt.toUtc().toIso8601String(),
    'title': title,
    'content': content,
    'base_version': baseVersion,
  };
}

class NotesLocalStore {
  NotesLocalStore(this._db);

  final Database _db;
  final _store = stringMapStoreFactory.store('notes');
  final _pending = stringMapStoreFactory.store('pending');

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

  // Oldest first so changes reach the server in the order they were made.
  Future<List<PendingChange>> pendingChanges() async {
    final records = await _pending.find(
      _db,
      finder: Finder(sortOrders: [SortOrder('queued_at')]),
    );
    return records
        .map((record) => PendingChange.fromMap(record.key, record.value))
        .toList();
  }

  Future<int> pendingCount() => _pending.count(_db);

  Future<PendingChange?> pendingFor(String noteId) async {
    final value = await _pending.record(noteId).get(_db);
    return value == null ? null : PendingChange.fromMap(noteId, value);
  }

  Future<void> queueCreate(Note note) {
    return _putPending(
      PendingChange(
        noteId: note.id,
        kind: PendingKind.create,
        queuedAt: DateTime.now().toUtc(),
        title: note.title,
        content: note.content,
      ),
    );
  }

  Future<void> queueUpdate(Note note) async {
    final existing = await pendingFor(note.id);
    final isNew = existing?.kind == PendingKind.create;
    await _putPending(
      PendingChange(
        noteId: note.id,
        kind: isNew ? PendingKind.create : PendingKind.update,
        queuedAt: existing?.queuedAt ?? DateTime.now().toUtc(),
        title: note.title,
        content: note.content,
        baseVersion: existing?.baseVersion ?? note.version,
      ),
    );
  }

  Future<void> queueDelete(String noteId) async {
    final existing = await pendingFor(noteId);
    if (existing?.kind == PendingKind.create) {
      await removePending(noteId);
      return;
    }
    await _putPending(
      PendingChange(
        noteId: noteId,
        kind: PendingKind.delete,
        queuedAt: existing?.queuedAt ?? DateTime.now().toUtc(),
      ),
    );
  }

  Future<void> removePending(String noteId) {
    return _pending.record(noteId).delete(_db);
  }

  Future<void> _putPending(PendingChange change) {
    return _pending.record(change.noteId).put(_db, change.toMap());
  }
}