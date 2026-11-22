import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../data/attachments_repository.dart';
import '../domain/attachment.dart';

final attachmentsRepositoryProvider = Provider<AttachmentsRepository>((ref) {
  return AttachmentsRepository(ref.watch(supabaseClientProvider));
});

final noteAttachmentsProvider = AsyncNotifierProvider.family<
    NoteAttachmentsController, List<NoteAttachment>, String>(
  NoteAttachmentsController.new,
);

final attachmentSignedUrlProvider =
    FutureProvider.autoDispose.family<String, String>((ref, storagePath) {
  return ref.watch(attachmentsRepositoryProvider).createSignedUrl(storagePath);
});

class NoteAttachmentsController
    extends AsyncNotifier<List<NoteAttachment>> {
  NoteAttachmentsController(this.noteId);

  final String noteId;

  AttachmentsRepository get _repository => ref.read(attachmentsRepositoryProvider);

  @override
  Future<List<NoteAttachment>> build() {
    final userId = ref.watch(currentUserProvider.select((user) => user?.id));
    if (userId == null) return Future.value(const []);
    return _repository.fetchAttachments(noteId);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repository.fetchAttachments(noteId));
  }

  Future<NoteAttachment> upload({
    required String fileName,
    required Uint8List bytes,
  }) async {
    final created = await _repository.uploadAttachment(
      noteId: noteId,
      fileName: fileName,
      bytes: bytes,
    );
    final current = state.value ?? const <NoteAttachment>[];
    state = AsyncData([created, ...current]);
    return created;
  }

  Future<void> remove(NoteAttachment attachment) async {
    await _repository.deleteAttachment(attachment);
    final current = state.value ?? const <NoteAttachment>[];
    state = AsyncData(
      current.where((item) => item.id != attachment.id).toList(),
    );
  }
}