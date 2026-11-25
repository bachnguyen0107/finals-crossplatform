import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../data/sharing_repository.dart';
import '../domain/share_models.dart';

final sharingRepositoryProvider = Provider<SharingRepository>((ref) {
  return SharingRepository(ref.watch(supabaseClientProvider));
});

final noteSharesProvider = AsyncNotifierProvider.family<
    NoteSharesController, List<ShareItem>, String>(
  NoteSharesController.new,
);

final sharedWithMeProvider = FutureProvider.autoDispose<List<SharedNoteItem>>(
  (ref) async {
    final userId = ref.watch(currentUserProvider.select((user) => user?.id));
    if (userId == null) return const <SharedNoteItem>[];
    return ref.watch(sharingRepositoryProvider).fetchSharedWithMe();
  },
);

class NoteSharesController extends AsyncNotifier<List<ShareItem>> {
  NoteSharesController(this.noteId);

  final String noteId;

  SharingRepository get _repo => ref.read(sharingRepositoryProvider);

  @override
  Future<List<ShareItem>> build() async {
    final userId = ref.watch(currentUserProvider.select((user) => user?.id));
    if (userId == null) return const <ShareItem>[];
    return _repo.listSharesForNote(noteId);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repo.listSharesForNote(noteId));
  }

  Future<void> addShareByEmail({
    required String email,
    required SharePermission permission,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final currentEmail = _repo.currentUserEmail?.trim().toLowerCase();
    if (currentEmail != null && normalizedEmail == currentEmail) {
      throw const SharingFailure('You cannot share a note with yourself.');
    }

    final existing = state.value ?? const <ShareItem>[];
    if (currentEmail != null &&
        existing.any(
          (item) => item.recipientEmail?.trim().toLowerCase() == normalizedEmail,
        )) {
      throw const SharingFailure(
        'This note is already shared with this user.',
      );
    }

    final recipientId = await _repo.findUserIdByEmail(normalizedEmail);
    if (recipientId == null) {
      throw const SharingFailure(
        'No registered account was found with that email.',
      );
    }

    if (existing.any((item) => item.recipientId == recipientId)) {
      throw const SharingFailure(
        'This note is already shared with this user.',
      );
    }

    final created = await _repo.addShare(
      noteId: noteId,
      recipientId: recipientId,
      permission: permission,
      recipientEmail: normalizedEmail,
    );

    state = AsyncData(<ShareItem>[created, ...existing]);
  }

  Future<void> changePermission({
    required String shareId,
    required SharePermission permission,
  }) async {
    final updated = await _repo.updatePermission(
      shareId: shareId,
      permission: permission,
    );
    final current = state.value ?? const <ShareItem>[];
    state = AsyncData(
      current
          .map(
            (item) => item.id == shareId
                ? updated.copyWith(recipientEmail: item.recipientEmail)
                : item,
          )
          .toList(),
    );
  }

  Future<void> revoke(String shareId) async {
    await _repo.revokeShare(shareId);
    final current = state.value ?? const <ShareItem>[];
    state = AsyncData(current.where((item) => item.id != shareId).toList());
  }
}