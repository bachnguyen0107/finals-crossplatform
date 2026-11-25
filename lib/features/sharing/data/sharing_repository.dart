import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/share_models.dart';

class SharingFailure implements Exception {
  const SharingFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

class SharingRepository {
  SharingRepository(this._client);

  final SupabaseClient _client;

  static const _sharesTable = 'shares';
  static const _shareColumns =
      'id, note_id, owner_id, recipient_id, permission, created_at';

  String get _currentUserId {
    final id = _client.auth.currentUser?.id;
    if (id == null || id.isEmpty) {
      throw const SharingFailure('You need to sign in to manage sharing.');
    }
    return id;
  }

  String? get currentUserEmail => _client.auth.currentUser?.email;

  Future<String?> findUserIdByEmail(String email) {
    return _run(() async {
      final normalized = email.trim().toLowerCase();
      if (normalized.isEmpty) return null;
      final res = await _client.rpc(
        'find_user_id_by_email',
        params: {'p_email': normalized},
      );
      if (res == null) return null;
      return res.toString();
    });
  }

  Future<List<ShareItem>> listSharesForNote(String noteId) {
    return _run(() async {
      final rows = await _client
          .from(_sharesTable)
          .select(_shareColumns)
          .eq('note_id', noteId)
          .order('created_at', ascending: false);
      return (rows as List<dynamic>)
          .map((e) => ShareItem.fromMap(e as Map<String, dynamic>))
          .toList();
    });
  }

  Future<ShareItem> addShare({
    required String noteId,
    required String recipientId,
    required SharePermission permission,
    String? recipientEmail,
  }) {
    return _run(() async {
      final ownerId = _currentUserId;
      if (ownerId == recipientId) {
        throw const SharingFailure('You cannot share a note with yourself.');
      }
      final row = await _client
          .from(_sharesTable)
          .insert({
            'note_id': noteId,
            'owner_id': ownerId,
            'recipient_id': recipientId,
            'permission': permission.value,
          })
          .select(_shareColumns)
          .single();
      return ShareItem.fromMap(row).copyWith(recipientEmail: recipientEmail);
    });
  }

  Future<ShareItem> updatePermission({
    required String shareId,
    required SharePermission permission,
  }) {
    return _run(() async {
      final row = await _client
          .from(_sharesTable)
          .update({'permission': permission.value})
          .eq('id', shareId)
          .select(_shareColumns)
          .single();
      return ShareItem.fromMap(row);
    });
  }

  Future<void> revokeShare(String shareId) {
    return _run(() async {
      await _client.from(_sharesTable).delete().eq('id', shareId);
    });
  }

  Future<List<SharedNoteItem>> fetchSharedWithMe() {
    return _run(() async {
      final rows = await _client.rpc('shared_with_me');
      if (rows == null) return const <SharedNoteItem>[];
      return (rows as List<dynamic>)
          .map((e) => SharedNoteItem.fromMap(e as Map<String, dynamic>))
          .toList();
    });
  }

  Future<T> _run<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on SharingFailure {
      rethrow;
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        throw const SharingFailure(
          'This note is already shared with this user.',
        );
      }
      if (e.code == '23514') {
        throw const SharingFailure(
          'Invalid share settings or you cannot share with yourself.',
        );
      }
      if (e.code == '42501') {
        throw const SharingFailure(
          'You do not have permission to perform this sharing action.',
        );
      }
      throw SharingFailure('Could not complete sharing request: ${e.message}');
    } catch (_) {
      throw const SharingFailure(
        'Unable to reach the server. Check your connection and try again.',
      );
    }
  }
}