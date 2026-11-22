import 'dart:math';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/attachment.dart';

class AttachmentsRepository {
  AttachmentsRepository(this._client);

  final SupabaseClient _client;
  static const String _bucketName = 'attachments';
  static final Random _random = Random.secure();

  String _generateShortUuid() {
    String hex(int length) {
      final buf = StringBuffer();
      for (var i = 0; i < length; i++) {
        buf.write(_random.nextInt(16).toRadixString(16));
      }
      return buf.toString();
    }

    return '${hex(8)}-${hex(4)}-4${hex(3)}-${(8 + _random.nextInt(4)).toRadixString(16)}${hex(3)}-${hex(12)}';
  }

  String _sanitizeFileName(String fileName) {
    final cleaned = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    return cleaned.isEmpty ? 'file' : cleaned;
  }

  Future<List<NoteAttachment>> fetchAttachments(String noteId) async {
    final rows = await _client
        .from('attachments')
        .select()
        .eq('note_id', noteId)
        .order('created_at', ascending: false);

    return (rows as List<dynamic>)
        .map((row) => NoteAttachment.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<NoteAttachment> uploadAttachment({
    required String noteId,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('You must be signed in to upload attachments.');
    }

    final mimeType = validateAttachmentFile(
      fileName: fileName,
      sizeBytes: bytes.length,
    );

    final uuid = _generateShortUuid();
    final safeName = _sanitizeFileName(fileName);
    final storagePath = '$userId/$noteId/$uuid-$safeName';

    await _client.storage.from(_bucketName).uploadBinary(
          storagePath,
          bytes,
          fileOptions: FileOptions(
            contentType: mimeType,
            upsert: false,
          ),
        );

    try {
      final inserted = await _client
          .from('attachments')
          .insert({
            'note_id': noteId,
            'owner_id': userId,
            'storage_path': storagePath,
            'file_name': fileName,
            'mime_type': mimeType,
            'size_bytes': bytes.length,
          })
          .select()
          .single();

      return NoteAttachment.fromMap(inserted);
    } catch (_) {
      // Roll back uploaded object if DB insert fails.
      try {
        await _client.storage.from(_bucketName).remove([storagePath]);
      } catch (_) {}
      rethrow;
    }
  }

  Future<void> deleteAttachment(NoteAttachment attachment) async {
    await _client.storage.from(_bucketName).remove([attachment.storagePath]);
    await _client.from('attachments').delete().eq('id', attachment.id);
  }

  Future<String> createSignedUrl(
    String storagePath, {
    int expiresInSeconds = 60,
  }) async {
    return _client.storage
        .from(_bucketName)
        .createSignedUrl(storagePath, expiresInSeconds);
  }
}