import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/note.dart';

class NotesFailure implements Exception {
  const NotesFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

class NotesRepository {
  NotesRepository(this._client);

  final SupabaseClient _client;

  static const _table = 'notes';
  static const _columns =
      'id, owner_id, title, content, is_pinned, pinned_at, is_locked, '
      'version, created_at, updated_at';

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) {
      throw const NotesFailure('You need to log in to view your notes.');
    }
    return id;
  }

  Future<List<Note>> fetchNotes() {
    return _run(() async {
      final rows = await _client
          .from(_table)
          .select(_columns)
          .eq('owner_id', _userId);
      return sortNotes(rows.map(Note.fromMap));
    });
  }

  Future<Note> createNote({required String title, String content = ''}) {
    return _run(() async {
      final row = await _client
          .from(_table)
          .insert({'title': title, 'content': content})
          .select(_columns)
          .single();
      return Note.fromMap(row);
    });
  }

  Future<Note> updateNote(String id, {String? title, String? content}) {
    final changes = <String, dynamic>{
      'title': ?title,
      'content': ?content,
    };
    return _run(() async {
      final row = await _client
          .from(_table)
          .update(changes)
          .eq('id', id)
          .select(_columns)
          .single();
      return Note.fromMap(row);
    });
  }

  Future<Note> setPinned(String id, {required bool pinned}) {
    return _run(() async {
      final row = await _client
          .from(_table)
          .update({
            'is_pinned': pinned,
            'pinned_at':
                pinned ? DateTime.now().toUtc().toIso8601String() : null,
          })
          .eq('id', id)
          .select(_columns)
          .single();
      return Note.fromMap(row);
    });
  }

  Future<void> deleteNote(String id) {
    return _run(() => _client.from(_table).delete().eq('id', id));
  }

  Future<T> _run<T>(Future<T> Function() action) async {
    try {
        return await action().timeout(const Duration(seconds: 15));
    } on NotesFailure {
      rethrow;
    } on PostgrestException catch (e) {
      throw NotesFailure('Could not save or load notes: ${e.message}');
    } catch (_) {
      throw const NotesFailure(
        'Unable to reach the server. Check your connection and try again.',
      );
    }
  }
}