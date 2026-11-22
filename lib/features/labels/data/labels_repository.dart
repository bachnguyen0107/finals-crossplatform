import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/label.dart';

class LabelsFailure implements Exception {
  const LabelsFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

class LabelsRepository {
  LabelsRepository(this._client);

  final SupabaseClient _client;

  static const _table = 'labels';
  static const _noteLabelsTable = 'note_labels';
  static const _columns = 'id, owner_id, name, created_at';

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) {
      throw const LabelsFailure('You need to log in to view your labels.');
    }
    return id;
  }

  Future<List<Label>> fetchLabels() {
    return _run(() async {
      final rows = await _client
          .from(_table)
          .select(_columns)
          .eq('owner_id', _userId)
          .order('name', ascending: true);
      return rows.map(Label.fromMap).toList();
    });
  }

  Future<Label> createLabel({required String name}) {
    return _run(() async {
      final row = await _client
          .from(_table)
          .insert({'name': name.trim()})
          .select(_columns)
          .single();
      return Label.fromMap(row);
    });
  }

  Future<Label> renameLabel({required String id, required String name}) {
    return _run(() async {
      final row = await _client
          .from(_table)
          .update({'name': name.trim()})
          .eq('id', id)
          .select(_columns)
          .single();
      return Label.fromMap(row);
    });
  }

  Future<void> deleteLabel(String id) {
    return _run(() => _client.from(_table).delete().eq('id', id));
  }

  Future<Set<String>> fetchLabelIdsForNote(String noteId) {
    return _run(() async {
      final rows = await _client
          .from(_noteLabelsTable)
          .select('label_id')
          .eq('note_id', noteId);
      return (rows as List<dynamic>)
          .map((row) => (row as Map<String, dynamic>)['label_id'] as String)
          .toSet();
    });
  }

  Future<Map<String, Set<String>>> fetchAllNoteLabelLinks() {
    return _run(() async {
      final rows = await _client
          .from(_noteLabelsTable)
          .select('note_id, label_id');
      final map = <String, Set<String>>{};
      for (final raw in rows as List<dynamic>) {
        final row = raw as Map<String, dynamic>;
        final noteId = row['note_id'] as String;
        final labelId = row['label_id'] as String;
        map.putIfAbsent(noteId, () => <String>{}).add(labelId);
      }
      return map;
    });
  }

  Future<void> setLabelAttached({
    required String noteId,
    required String labelId,
    required bool attached,
  }) {
    return _run(() async {
      if (attached) {
        await _client.from(_noteLabelsTable).upsert(
          {'note_id': noteId, 'label_id': labelId},
          onConflict: 'note_id,label_id',
        );
      } else {
        await _client
            .from(_noteLabelsTable)
            .delete()
            .eq('note_id', noteId)
            .eq('label_id', labelId);
      }
    });
  }

  Future<T> _run<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on LabelsFailure {
      rethrow;
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        throw const LabelsFailure('A label with this name already exists.');
      }
      throw LabelsFailure('Could not save or load labels: ${e.message}');
    } catch (_) {
      throw const LabelsFailure(
        'Unable to reach the server. Check your connection and try again.',
      );
    }
  }
}